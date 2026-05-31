// ============================================================
// fn_unlockResistanceRespawn.sqf
// Runs on the escaping player's client so the respawn unlock persists in that
// player's profileNamespace, which is what description.ext checks.
// ============================================================
private _uid = getPlayerUID player;
if (_uid isEqualTo "") exitWith {};

private _profileKey = format ["CO_escaped_%1", _uid];
if !(profileNamespace getVariable [_profileKey, false]) then {
    profileNamespace setVariable [_profileKey, true];
    saveProfileNamespace;
};

private _refreshRespawnOptions = missionNamespace getVariable ["CO_fnc_refreshResistanceRespawn", {}];
[] call _refreshRespawnOptions;

[] call co_main_fnc_showEscapeUnlockScreen;