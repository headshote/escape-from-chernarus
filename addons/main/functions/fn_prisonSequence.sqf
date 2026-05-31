// fn_prisonSequence.sqf — extended version
params ["_captive"];
private _isPlayer = isPlayer _captive;
private _detainTime = missionNamespace getVariable ["CO_conscript_detainTime", 300];

// Phase 1: Detention (5 min window)
_captive setVariable ["CO_detainPhase", "detention", true];
_captive setVariable ["CO_detainStartTime", time, false];
if (_isPlayer) then {
    // Simple detention notification
    [_captive] remoteExecCall ["co_main_fnc_showDetentionHUD", _captive];
};

[{ // wait 5 minutes or until escaped
    params ["_c", "_detainTime"];
    !(captive _c) || time > (_c getVariable ["CO_detainStartTime", 0]) + _detainTime
}, {
    params ["_c"];
    if (captive _c) then {
        // Not escaped — transfer to training
        [_c] call co_main_fnc_transportToTraining;
    };
}, [_captive, _detainTime]] call CBA_fnc_waitUntilAndExecute;