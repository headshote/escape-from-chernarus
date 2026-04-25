// fn_checkEscapeUnlock.sqf — called when player crosses border
params ["_player"];

private _uid = getPlayerUID _player;
private _escaped = profileNamespace getVariable [format ["CO_escaped_%1", _uid], false];

if (!_escaped) then {
    profileNamespace setVariable [format ["CO_escaped_%1", _uid], true];
    publicVariable format ["CO_escaped_%1", _uid];

    // Notify player
    [_player] remoteExecCall ["co_main_fnc_showEscapeUnlockScreen", _player];

    // Unlock resistance spawn marker
    private _resistSpawn = "resist_spawn_1"; // predefined marker name
    setMarkerAlpha [_resistSpawn, 1];
};