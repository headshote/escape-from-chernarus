// ============================================================
// fn_runWrangle.sqf — serialized wrangle-minigame runner
// (server-side, BLOCKING — call from a scheduled thread)
//
// Repair plan R1-h. Multiple chase controllers (police, bus
// hunters, checkpoints) could previously remoteExec the wrangle
// dialog at the same player simultaneously; the second
// createDialog fails and the result defaulted to "captured" —
// the player lost to a dialog bug, not to the AI.
//
// This helper owns the mutex: only one grab may run the dialog
// at a time. Callers receiving "busy" should keep the cordon and
// try again next tick.
//
// params: [_target, _timeout]
// returns: "captured" | "escaped" | "busy" | "dead"
// ============================================================
params [
    ["_target", objNull],
    ["_timeout", 20]
];

if (!isServer) exitWith { "busy" };
if (isNull _target || !alive _target) exitWith { "dead" };
if (!isPlayer _target) exitWith { "busy" };

private _lockAt = _target getVariable ["CO_wrangleActive", 0];
if (_lockAt > 0 && (time - _lockAt) < 25) exitWith { "busy" };
_target setVariable ["CO_wrangleActive", time, false];
_target setVariable ["CO_wrangleResult", nil, true];
// We own the grab now — flag the target "capture in progress" so every
// other controller (TCK escorts, foot patrols) disengages instead of
// piling onto someone who is already being taken. Cleared below unless
// the grab succeeds (then the detain/transport chain owns the flag).
_target setVariable ["CO_captureInProgress", true, true];

[_target] remoteExecCall ["co_main_fnc_wrangleMinigame", _target];

private _deadline = time + _timeout;
waitUntil {
    sleep 0.3;
    !alive _target ||
    !isNil { _target getVariable "CO_wrangleResult" } ||
    time > _deadline
};

private _result = if (!alive _target) then {
    "dead"
} else {
    _target getVariable ["CO_wrangleResult", "captured"]
};
_target setVariable ["CO_wrangleResult", nil, true];
_target setVariable ["CO_wrangleActive", 0, false];
// Release the "hands off" flag unless the grab landed — on a capture the
// detain sequence / transport keeps it set until the victim is seated.
if (_result != "captured") then {
    _target setVariable ["CO_captureInProgress", false, true];
};

_result
