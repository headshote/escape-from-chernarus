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

missionNamespace setVariable ["CO_fnc_requestSupportBike", {
    private _resistanceSpawnPos = [2100, 12800, 0];
    private _civilianSpawnPos = markerPos "respawn_civilian";
    private _isResistanceSpawn = (player distance2D _resistanceSpawnPos) < 180;
    private _hasCivilianMarker = !(_civilianSpawnPos isEqualTo [0, 0, 0]);
    private _isCivilianSpawn = _hasCivilianMarker && { (player distance2D _civilianSpawnPos) < 180 };

    if (!_isResistanceSpawn && !_isCivilianSpawn && { side group player != resistance }) exitWith {};

    private _anchorPos = if (_isResistanceSpawn || { side group player == resistance }) then {
        _resistanceSpawnPos
    } else {
        _civilianSpawnPos
    };

    [player, _anchorPos] remoteExecCall ["co_main_fnc_spawnResistanceBike", 2];
}];

missionNamespace setVariable ["CO_fnc_setupUnarmedKnockout", {
    private _existingAction = player getVariable ["CO_unarmedKnockoutActionId", -1];
    if (_existingAction >= 0) then {
        player removeAction _existingAction;
    };

    private _actionId = player addAction [
        "Punch Nearby Target",
        {
            private _target = cursorObject;
            [player, _target] remoteExecCall ["co_main_fnc_applyMeleeHit", 2];
        },
        nil,
        1.5,
        false,
        true,
        "",
        "vehicle player == player && currentWeapon player == '' && { alive cursorObject } && { cursorObject isKindOf 'CAManBase' } && { cursorObject != player } && { player distance cursorObject < 2.4 } && { vehicle cursorObject == cursorObject } && { !(cursorObject getVariable ['CO_knockedOut', false]) }"
    ];

    player setVariable ["CO_unarmedKnockoutActionId", _actionId];
}];

missionNamespace setVariable ["CO_fnc_setupUnarmedMousePunch", {
    disableSerialization;

    private _display = findDisplay 46;
    if (isNull _display) exitWith {};

    private _existingMouseEh = uiNamespace getVariable ["CO_unarmedPunchMouseEh", -1];
    if (_existingMouseEh >= 0) then {
        _display displayRemoveEventHandler ["MouseButtonDown", _existingMouseEh];
        uiNamespace setVariable ["CO_unarmedPunchMouseEh", -1];
    };

    private _mouseEh = _display displayAddEventHandler ["MouseButtonDown", {
        params ["_display", "_button"];

        if (_button != 0) exitWith { false };
        if (isNull player || !alive player) exitWith { false };
        if (vehicle player != player) exitWith { false };
        if (currentWeapon player != "") exitWith { false };

        private _target = cursorObject;
        if (isNull _target || !alive _target) exitWith { false };
        if !(_target isKindOf "CAManBase") exitWith { false };
        if (_target == player) exitWith { false };
        if (player distance _target > 2.6) exitWith { false };

        [player, _target] remoteExecCall ["co_main_fnc_applyMeleeHit", 2];
        true
    }];

    uiNamespace setVariable ["CO_unarmedPunchMouseEh", _mouseEh];
}];

missionNamespace setVariable ["CO_fnc_setupAdminPanelAction", {
    private _existingAction = player getVariable ["CO_adminPanelActionId", -1];
    if (_existingAction >= 0) then {
        player removeAction _existingAction;
        player setVariable ["CO_adminPanelActionId", -1];
    };

    private _adminUIDs = missionNamespace getVariable ["CO_adminUIDs", []];
    if !((getPlayerUID player) in _adminUIDs) exitWith {};

    private _actionId = player addAction [
        "Open Admin Panel",
        {
            [] call co_main_fnc_adminPanel;
        },
        nil,
        1.6,
        false,
        true,
        "",
        "alive player"
    ];

    player setVariable ["CO_adminPanelActionId", _actionId];
}];

[] call (missionNamespace getVariable ["CO_fnc_refreshResistanceRespawn", {}]);
[] spawn {
    sleep 1;
    [] call (missionNamespace getVariable ["CO_fnc_requestSupportBike", {}]);
};
[] call (missionNamespace getVariable ["CO_fnc_setupUnarmedKnockout", {}]);
[] call (missionNamespace getVariable ["CO_fnc_setupAdminPanelAction", {}]);
[] spawn {
    waitUntil { !isNull findDisplay 46 };
    [] call (missionNamespace getVariable ["CO_fnc_setupUnarmedMousePunch", {}]);
};

if ((missionNamespace getVariable ["CO_respawnMissionEhId", -1]) < 0) then {
    private _eventId = addMissionEventHandler ["Respawn", {
        [] call (missionNamespace getVariable ["CO_fnc_refreshResistanceRespawn", {}]);
        [] spawn {
            sleep 1;
            [] call (missionNamespace getVariable ["CO_fnc_requestSupportBike", {}]);
        };
        [] spawn {
            sleep 0.2;
            [] call (missionNamespace getVariable ["CO_fnc_setupUnarmedKnockout", {}]);
        };
        [] spawn {
            sleep 0.2;
            [] call (missionNamespace getVariable ["CO_fnc_setupAdminPanelAction", {}]);
        };
        [] spawn {
            waitUntil { !isNull findDisplay 46 };
            [] call (missionNamespace getVariable ["CO_fnc_setupUnarmedMousePunch", {}]);
        };
    }];
    missionNamespace setVariable ["CO_respawnMissionEhId", _eventId];
};