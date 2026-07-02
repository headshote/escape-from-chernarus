// ============================================================
// fn_setDifficultyPreset.sqf
// Server-authoritative difficulty preset setter for the admin UI.
// params: [_preset]
// ============================================================
params [["_preset", "Standard"]];

if (!isServer) exitWith {
    [_preset] remoteExecCall ["co_main_fnc_setDifficultyPreset", 2];
};

private _valid = ["Quiet Occupation", "Standard", "Martial Law"];
if (!(_preset in _valid)) exitWith {
    diag_log format ["[CO] Ignored invalid difficulty preset: %1", _preset];
};

missionNamespace setVariable ["CO_difficultyPreset", _preset, true];
[] call co_main_fnc_applyDifficultyPreset;
diag_log format ["[CO] Admin selected difficulty preset: %1", _preset];
