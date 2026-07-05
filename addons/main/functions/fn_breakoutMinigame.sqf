// ============================================================
// fn_breakoutMinigame.sqf — client-side cargo-latch minigame
//
// Available as a self-action while locked in a capture transport
// (CO_detainPhase == "transport"). Same key-sequence mechanic as
// the detention lockpick but with 5 keys — forcing a latch from
// inside a moving van is harder than a cell door.
//
// Success: sets CO_breakoutAt (broadcast); the transport's drive
// loop in fn_spawnCaptureTransport unlocks, dumps the player out,
// and flips them to escaped-fugitive state (wanted +20, SEARCH).
// Failure: 8 s cooldown before the latch can be tried again.
// ============================================================

if (!hasInterface) exitWith {};
if (isNull player || !alive player) exitWith {};
if ((player getVariable ["CO_detainPhase", ""]) != "transport") exitWith {};
if (vehicle player == player) exitWith {};
if (!((vehicle player) getVariable ["CO_isCaptureTransport", false])) exitWith {};
if (time < (player getVariable ["CO_nextBreakoutAt", 0])) exitWith {};

private _keyMap = [
    ["W", 0x11], ["A", 0x1E], ["S", 0x1F], ["D", 0x20],
    ["F", 0x21], ["G", 0x22], ["R", 0x13]
];
private _sequence = [];
for "_i" from 1 to 5 do {
    _sequence pushBack (selectRandom _keyMap);
};

if (!createDialog "CO_LockpickDialog") exitWith { hint "You can't get a grip on the latch."; };
private _dlg = uiNamespace getVariable ["CO_LockpickDlg", displayNull];
if (isNull _dlg) exitWith {};

private _seqLetters = (_sequence apply { _x select 0 }) joinString " - ";
(_dlg displayCtrl 401) ctrlSetText _seqLetters;
(_dlg displayCtrl 402) ctrlSetText "Work the latch: memorise the movements...";
sleep 1.6;
(_dlg displayCtrl 401) ctrlSetText "?  ?  ?  ?  ?";
(_dlg displayCtrl 402) ctrlSetText "Press the keys in order. 2s each.";

missionNamespace setVariable ["CO_breakoutStep", 0];
missionNamespace setVariable ["CO_breakoutFailed", false];
missionNamespace setVariable ["CO_breakoutSequence", _sequence];

private _ehId = _dlg displayAddEventHandler ["KeyDown", {
    params ["_display", "_key"];
    private _seq = missionNamespace getVariable ["CO_breakoutSequence", []];
    private _step = missionNamespace getVariable ["CO_breakoutStep", 0];
    if (_step >= count _seq) exitWith { false };

    private _expected = (_seq select _step) select 1;
    if (_key == _expected) then {
        _step = _step + 1;
        missionNamespace setVariable ["CO_breakoutStep", _step];
        private _disp = _seq apply { _x select 0 };
        private _shown = "";
        for "_i" from 0 to (count _disp - 1) do {
            _shown = _shown + (if (_i < _step) then { _disp select _i } else { "?" }) + " ";
        };
        (_display displayCtrl 401) ctrlSetText _shown;
    } else {
        if (_key != 0 && _key in (_seq apply { _x select 1 })) then {
            missionNamespace setVariable ["CO_breakoutFailed", true];
        };
    };
    false
}];

private _stepIndex = 0;
while {
    _stepIndex = missionNamespace getVariable ["CO_breakoutStep", 0];
    private _failed = missionNamespace getVariable ["CO_breakoutFailed", false];
    !_failed && _stepIndex < count _sequence
} do {
    private _stepDeadline = time + 2;
    waitUntil {
        sleep 0.05;
        private _now = missionNamespace getVariable ["CO_breakoutStep", _stepIndex];
        _now > _stepIndex || time > _stepDeadline ||
        (missionNamespace getVariable ["CO_breakoutFailed", false]) ||
        isNull (uiNamespace getVariable ["CO_LockpickDlg", displayNull])
    };
    if (time > _stepDeadline) exitWith {
        missionNamespace setVariable ["CO_breakoutFailed", true];
    };
};

_dlg displayRemoveEventHandler ["KeyDown", _ehId];
private _failed = missionNamespace getVariable ["CO_breakoutFailed", false];
private _completed = (missionNamespace getVariable ["CO_breakoutStep", 0]) >= count _sequence;

closeDialog 0;
missionNamespace setVariable ["CO_breakoutStep", nil];
missionNamespace setVariable ["CO_breakoutFailed", nil];
missionNamespace setVariable ["CO_breakoutSequence", nil];

// Still actually in the transport? (It may have arrived mid-minigame.)
if ((player getVariable ["CO_detainPhase", ""]) != "transport") exitWith {};

if (!_failed && _completed) then {
    hint "The latch gives way!";
    player setVariable ["CO_breakoutAt", time, true];
} else {
    hint "The lock resists. The jailer glances back at you...";
    player setVariable ["CO_nextBreakoutAt", time + 8, false];
};
