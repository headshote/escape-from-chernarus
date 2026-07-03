// ============================================================
// fn_policePatrols.sqf
// Spawns police car patrols. All behaviour (suspicion, ID checks,
// pursuits, alert response, town-alert scaling) lives in the
// shared fn_policeBrain so car and foot police act identically.
// ============================================================

CO_policeTownPosts = [
    // [town pos, patrol radius, car count]
    [[6400,  2400, 0], 600, 3],   // Chernogorsk
    [[10200, 2300, 0], 500, 3],   // Elektrozavodsk
    [[12300, 9700, 0], 550, 3],   // Berezino
    [[3900,  7200, 0], 400, 2],   // Zelenogorsk
    [[7300,  7900, 0], 350, 2]    // Stary Sobor
];
CO_policePatrolGroups = [];

private _spawnPolicePatrol = {
    params ["_center", "_radius"];

    private _spawnPos = _center getPos [30 + random 60, random 360];
    private _car = "C_Offroad_01_F" createVehicle _spawnPos;
    private _grp = createGroup west;
    _grp setVariable ["CO_faction", "POLICE", true];
    _grp setVariable ["CO_policeTownCenter", _center, false];
    _grp setVariable ["CO_policeTownRadius", _radius, false];
    CO_policePatrolGroups pushBack _grp;

    private _driver = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
    _driver moveInDriver _car;
    private _partner = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
    _partner moveInCargo _car;

    {
        [_x] call co_main_fnc_policeLoadout;
        _x setCombatMode "YELLOW";
        _x setBehaviour "SAFE";
        _x disableAI "AUTOTARGET";
        _x disableAI "TARGET";
    } forEach [_driver, _partner];

    _driver setVariable ["CO_isPoliceDriver", true, true];
    _partner setVariable ["CO_isPoliceDriver", false, true];

    _grp setBehaviour "SAFE";
    _grp setSpeedMode "LIMITED";
    for "_w" from 0 to 5 do {
        private _wPos = _center getPos [_radius * (0.4 + random 0.6), random 360];
        private _wp = _grp addWaypoint [_wPos, 30];
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCombatMode "BLUE";
        _wp setWaypointType "MOVE";
    };
    private _cycleWp = _grp addWaypoint [_center getPos [_radius * 0.3, random 360], 20];
    _cycleWp setWaypointType "CYCLE";

    _car setVariable ["CO_policePatrolCar", _grp, true];
    _grp setVariable ["CO_policePatrolCar", _car, true];

    [_grp, _car, _center, _radius] call co_main_fnc_policeBrain;
};

{
    private _center = _x select 0;
    private _radius = _x select 1;
    private _carCount = _x select 2;
    for "_c" from 0 to (_carCount - 1) do {
        [_center, _radius] call _spawnPolicePatrol;
    };
} forEach CO_policeTownPosts;
