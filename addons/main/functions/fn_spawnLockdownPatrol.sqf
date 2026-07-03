// ============================================================
// fn_spawnLockdownPatrol.sqf
// Temporary extra police foot patrols for violent-crime lockdown.
// params: [_townIdx, _center, _radius, _duration, _count]
// ============================================================
params [
    ["_townIdx", -1],
    ["_center", [0,0,0]],
    ["_radius", 400],
    ["_duration", 600],
    ["_count", 2]
];

if (!isServer || _townIdx < 0) exitWith {};
if (isNil "CO_townLockdowns") then { CO_townLockdowns = createHashMap };

private _key = str _townIdx;
private _current = CO_townLockdowns getOrDefault [_key, [0, []]];
private _until = time + _duration;

if ((_current select 0) > time) exitWith {
    _current set [0, _until max (_current select 0)];
    CO_townLockdowns set [_key, _current];
    diag_log format ["[CO] Town lockdown extended: town=%1 until=%2.", _townIdx, round (_current select 0)];
};

private _groups = [];
for "_g" from 1 to _count do {
    private _spawn = _center getPos [40 + random (_radius * 0.35), random 360];
    private _grp = createGroup [west, true];
    _grp setVariable ["CO_faction", "POLICE", true];
    _grp setVariable ["CO_lockdownPatrol", true, true];
    _grp setBehaviour "SAFE";
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode "NORMAL";

    for "_i" from 1 to 2 do {
        private _u = _grp createUnit ["B_Soldier_F", _spawn, [], 0, "FORM"];
        [_u] call co_main_fnc_policeLoadout;
    };

    for "_w" from 0 to 4 do {
        private _wpPos = _center getPos [_radius * (0.2 + random 0.75), random 360];
        private _wp = _grp addWaypoint [_wpPos, 20];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCombatMode "YELLOW";
    };
    private _cycle = _grp addWaypoint [_center getPos [_radius * 0.2, random 360], 20];
    _cycle setWaypointType "CYCLE";

    [_grp, objNull, _center, _radius] call co_main_fnc_policeBrain;
    _groups pushBack _grp;
};

CO_townLockdowns set [_key, [_until, _groups]];
diag_log format ["[CO] Town lockdown started: town=%1 extraPatrols=%2 duration=%3s.", _townIdx, count _groups, _duration];

[_key, _duration] spawn {
    params ["_key", "_duration"];
    sleep (_duration + 10);
    if (isNil "CO_townLockdowns") exitWith {};
    private _rec = CO_townLockdowns getOrDefault [_key, [0, []]];
    if ((_rec select 0) > time) exitWith {};
    {
        private _grp = _x;
        if (
            !isNull _grp &&
            !(_grp getVariable ["CO_policeFootChaseActive", false]) &&
            !(_grp getVariable ["CO_vehiclePursuitActive", false]) &&
            !(_grp getVariable ["CO_policeInspectionActive", false])
        ) then {
            { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
            deleteGroup _grp;
        };
    } forEach (_rec select 1);
    CO_townLockdowns deleteAt _key;
    diag_log format ["[CO] Town lockdown ended: town=%1.", _key];
};
