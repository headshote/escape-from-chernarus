// fn_trainingPhase.sqf
params ["_conscript"];
private _isPlayer = isPlayer _conscript;

_conscript setPos (CO_trainingFieldPos vectorAdd [random 60 - 30, random 60 - 30, 0]);
_conscript setVariable ["CO_detainPhase", "training", true];

// Heavily guarded — extra guards already placed at airfield by buildAirfieldCamp
// No need to re-spawn; just ensure the captive knows they're at training
if (_isPlayer) then {
    [_conscript] remoteExecCall ["co_main_fnc_showTrainingHUD", _conscript];
    // Training minigame: player must complete 3 movement drills to pass time
    // (or just wait — the drills are optional RP flavor)
    [_conscript] call co_main_fnc_trainingDrills;
};

// 10-minute window — if still captive, ship to front
_conscript setVariable ["CO_trainingStartTime", time, false];

[{
    params ["_c"];
    !(captive _c) || time > _c getVariable ["CO_trainingStartTime", 0] + 600
}, {
    params ["_c"];
    if (captive _c) then {
        [_c] call co_main_fnc_deployToFront;
    };
}, [_conscript]] call CBA_fnc_waitUntilAndExecute;