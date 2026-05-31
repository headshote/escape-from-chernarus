// fn_minigame_lockpick.sqf
// Called when player interacts with a locked door in detention.
// Minigame: a 4-key sequence shown briefly, then the player has 2 s per key
// to press the right one. Uses an actual displayAddEventHandler KeyDown
// listener so quick taps are reliably caught (the previous inputAction
// approach only saw held keys and was unreliable).

params ["_player", "_door"];

private _keyMap = [
    ["W", 0x11], ["A", 0x1E], ["S", 0x1F], ["D", 0x20],
    ["F", 0x21], ["G", 0x22], ["R", 0x13]
];
private _sequence = [];
for "_i" from 1 to 4 do {
    _sequence pushBack (selectRandom _keyMap);
};

if (!createDialog "CO_LockpickDialog") exitWith { hint "Lockpick interface failed to open."; };
private _dlg = uiNamespace getVariable ["CO_LockpickDlg", displayNull];
if (isNull _dlg) exitWith { hint "Lockpick interface unavailable."; };

// Show the sequence briefly
private _seqLetters = (_sequence apply { _x select 0 }) joinString " - ";
(_dlg displayCtrl 401) ctrlSetText _seqLetters;
(_dlg displayCtrl 402) ctrlSetText "Memorise the sequence...";
sleep 1.6;
(_dlg displayCtrl 401) ctrlSetText "?  ?  ?  ?";
(_dlg displayCtrl 402) ctrlSetText "Press the keys in order. 2s each.";

private _stepIndex = 0;
missionNamespace setVariable ["CO_lockpickStep", 0];
missionNamespace setVariable ["CO_lockpickFailed", false];
missionNamespace setVariable ["CO_lockpickSequence", _sequence];

private _ehId = _dlg displayAddEventHandler ["KeyDown", {
    params ["_display", "_key"];
    private _seq = missionNamespace getVariable ["CO_lockpickSequence", []];
    private _step = missionNamespace getVariable ["CO_lockpickStep", 0];
    if (_step >= count _seq) exitWith { false };

    private _expected = (_seq select _step) select 1;
    if (_key == _expected) then {
        _step = _step + 1;
        missionNamespace setVariable ["CO_lockpickStep", _step];
        private _disp = (missionNamespace getVariable ["CO_lockpickSequence", []]) apply {
            _x select 0
        };
        private _shown = "";
        for "_i" from 0 to (count _disp - 1) do {
            _shown = _shown + (if (_i < _step) then { _disp select _i } else { "?" }) + " ";
        };
        ((findDisplay 9202) displayCtrl 401) ctrlSetText _shown;
    } else {
        // Any key that isn't the expected one fails the step
        if (_key != 0 && _key in (_seq apply { _x select 1 })) then {
            // wrong sequenced key — fail
            missionNamespace setVariable ["CO_lockpickFailed", true];
        };
    };
    false
}];

private _stepDeadline = time;
while {
    _stepIndex = missionNamespace getVariable ["CO_lockpickStep", 0];
    private _failed = missionNamespace getVariable ["CO_lockpickFailed", false];
    !_failed && _stepIndex < count _sequence
} do {
    _stepDeadline = time + 2;
    waitUntil {
        sleep 0.05;
        private _now = missionNamespace getVariable ["CO_lockpickStep", _stepIndex];
        _now > _stepIndex || time > _stepDeadline ||
        (missionNamespace getVariable ["CO_lockpickFailed", false]) ||
        isNull (uiNamespace getVariable ["CO_LockpickDlg", displayNull])
    };
    if (time > _stepDeadline) exitWith {
        missionNamespace setVariable ["CO_lockpickFailed", true];
    };
};

_dlg displayRemoveEventHandler ["KeyDown", _ehId];
private _failed = missionNamespace getVariable ["CO_lockpickFailed", false];
private _completed = (missionNamespace getVariable ["CO_lockpickStep", 0]) >= count _sequence;

closeDialog 0;
missionNamespace setVariable ["CO_lockpickStep", nil];
missionNamespace setVariable ["CO_lockpickFailed", nil];
missionNamespace setVariable ["CO_lockpickSequence", nil];

if (!_failed && _completed) then {
    hint "Lock picked!";
    if (!isNull _door) then {
        _door animate ["Door_1_rot", 1];
    };
    [_player] remoteExec ["co_main_fnc_prisonEscape", 2];
} else {
    hint "Guard alerted!";
    [getPos _player] remoteExec ["co_main_fnc_alertNearbyGuards", 2];
};