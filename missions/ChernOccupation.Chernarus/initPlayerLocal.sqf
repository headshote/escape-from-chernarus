// ============================================================
// ChernOccupation — Player-local respawn setup
// ============================================================
waitUntil { !isNull player };

missionNamespace setVariable ["CO_fnc_refreshResistanceRespawn", {
    private _handles = missionNamespace getVariable ["CO_resistanceRespawnHandles", []];
    {
        _x call BIS_fnc_removeRespawnPosition;
    } forEach _handles;

    private _newHandles = [];
    private _uid = getPlayerUID player;
    private _profileKey = format ["CO_escaped_%1", _uid];
    private _isUnlocked = player getVariable ["CO_escapeUnlocked", false];

    if (!_isUnlocked && _uid != "") then {
        _isUnlocked = profileNamespace getVariable [_profileKey, false];
    };

    if (_isUnlocked) then {
        _newHandles pushBack ([player, [2100, 12800, 0], "Resistance Fighter"] call BIS_fnc_addRespawnPosition);
    };

    missionNamespace setVariable ["CO_resistanceRespawnHandles", _newHandles];
}];

missionNamespace setVariable ["CO_fnc_requestResistanceBike", {
    private _isResistanceSpawn = (player distance2D [2100, 12800, 0]) < 180;
    if (!_isResistanceSpawn && { side group player != resistance }) exitWith {};

    [player] remoteExecCall ["co_main_fnc_spawnResistanceBike", 2];
}];

[] call (missionNamespace getVariable ["CO_fnc_refreshResistanceRespawn", {}]);
[] spawn {
    sleep 1;
    [] call (missionNamespace getVariable ["CO_fnc_requestResistanceBike", {}]);
};

if ((missionNamespace getVariable ["CO_respawnMissionEhId", -1]) < 0) then {
    private _eventId = addMissionEventHandler ["Respawn", {
        [] call (missionNamespace getVariable ["CO_fnc_refreshResistanceRespawn", {}]);
        [] spawn {
            sleep 1;
            [] call (missionNamespace getVariable ["CO_fnc_requestResistanceBike", {}]);
        };
    }];
    missionNamespace setVariable ["CO_respawnMissionEhId", _eventId];
};