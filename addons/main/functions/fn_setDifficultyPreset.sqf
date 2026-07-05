// ============================================================
// fn_setDifficultyPreset.sqf
// Server-authoritative difficulty preset setter for the admin UI.
// params: [_preset]
// ============================================================
params [["_preset", "Standard"]];

if (!isServer) exitWith {
    [_preset] remoteExecCall ["co_main_fnc_setDifficultyPreset", 2];
};

private _remoteOwner = if (isNil "remoteExecutedOwner") then { 0 } else { remoteExecutedOwner };
private _authorized = true;
private _callerUID = "server";

if (_remoteOwner > 2) then {
    _authorized = false;
    private _adminUIDs = (missionNamespace getVariable ["CO_adminUIDs", []]) apply {
        if (_x isEqualType "") then { _x } else { format ["%1", _x] }
    };
    {
        if (owner _x == _remoteOwner) exitWith {
            _callerUID = getPlayerUID _x;
            _authorized = _callerUID in _adminUIDs;
        };
    } forEach allPlayers;
};

if (!_authorized) exitWith {
    diag_log format [
        "[CO][SECURITY] Rejected difficulty preset '%1' from non-admin owner=%2 uid=%3.",
        _preset, _remoteOwner, _callerUID
    ];
    false
};

private _valid = ["Quiet Occupation", "Standard", "Martial Law"];
if (!(_preset in _valid)) exitWith {
    diag_log format ["[CO] Ignored invalid difficulty preset: %1", _preset];
};

missionNamespace setVariable ["CO_difficultyPreset", _preset, true];
[] call co_main_fnc_applyDifficultyPreset;
diag_log format ["[CO] Admin selected difficulty preset: %1", _preset];
