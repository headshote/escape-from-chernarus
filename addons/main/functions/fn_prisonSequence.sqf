// fn_prisonSequence.sqf — extended version
params ["_captive"];
private _isPlayer = isPlayer _captive;

// Phase 1: Detention (5 min window)
_captive setVariable ["CO_detainPhase", "detention", true];
if (_isPlayer) then {
    [_captive] remoteExecCall ["co_main_fnc_showDetentionHUD", _captive];
};

[{ // wait 5 minutes or until escaped
    params ["_c"];
    !(captive _c) || time > _c getVariable ["CO_detainStartTime", 0] + 300
}, {
    params ["_c"];
    if (captive _c) then {
        // Not escaped — transfer to training
        [_c] call co_main_fnc_transportToTraining;
    };
}, [_captive]] call CBA_fnc_waitUntilAndExecute;