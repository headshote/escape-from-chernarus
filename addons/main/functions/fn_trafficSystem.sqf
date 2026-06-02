// ============================================================
// fn_trafficSystem.sqf
// Spawns civilian car traffic on major roads, police cars
// occasionally stop vehicles (car stop check).
// Runs on server.
// ============================================================

CO_trafficVehiclePool = [
    "C_Hatchback_01_F", "C_SUV_01_F", "C_Offroad_01_F",
    "C_Van_01_transport_F", "C_Truck_02_transport_F"
];
CO_trafficVehiclePool = CO_trafficVehiclePool select { isClass (configFile >> "CfgVehicles" >> _x) };
if (CO_trafficVehiclePool isEqualTo []) then { CO_trafficVehiclePool = ["C_Offroad_01_F"] };

private _trafficCivilianClasses = [
    "C_man_polo_1_F",
    "C_man_polo_2_F",
    "C_man_1"
] select { isClass (configFile >> "CfgVehicles" >> _x) };
if (_trafficCivilianClasses isEqualTo []) then { _trafficCivilianClasses = ["C_man_1"] };
private _trafficPassengerClasses = _trafficCivilianClasses + ([
    "C_Woman_casual_F"
] select { isClass (configFile >> "CfgVehicles" >> _x) });

// Road-following waypoint pairs for civilian traffic arteries
CO_trafficRoutes = [
    // South coastal road West→East
    [[3500,2200,0],[6400,2400,0],[10200,2300,0],[11600,7800,0]],
    // East→West
    [[11600,7800,0],[10200,2300,0],[6400,2400,0],[3500,2200,0]],
    // North loop
    [[5100,10100,0],[6000,9100,0],[7600,9200,0],[9700,9800,0]],
    [[9700,9800,0],[7600,9200,0],[6000,9100,0],[5100,10100,0]],
    // Center corridor
    [[4400,5600,0],[7300,7900,0],[9000,6100,0]]
];

private _spawnTrafficVehicle = {
    params ["_route", ["_spawnWaypointIndex", 0]];

    private _routeCount = count _route;
    if (_routeCount == 0) exitWith { objNull };

    _spawnWaypointIndex = _spawnWaypointIndex max 0;
    if (_spawnWaypointIndex >= _routeCount) then {
        _spawnWaypointIndex = _routeCount - 1;
    };

    private _spawnPos = _route select _spawnWaypointIndex;
    private _nearRd = _spawnPos nearRoads 30;
    if !(_nearRd isEqualTo []) then {
        private _roadIndex = _spawnWaypointIndex min ((count _nearRd) - 1);
        _spawnPos = getPosATL (_nearRd select _roadIndex);
    };

    private _vehClass = selectRandom CO_trafficVehiclePool;
    private _emptyPos = _spawnPos findEmptyPosition [0, 15, _vehClass];
    if !(_emptyPos isEqualTo []) then {
        _spawnPos = _emptyPos;
    };

    private _veh = _vehClass createVehicle _spawnPos;
    _veh allowDamage false;
    [_veh] spawn {
        params ["_veh"];
        sleep 8;
        if (!isNull _veh) then {
            _veh allowDamage true;
        };
    };

    private _nextWaypointIndex = (_spawnWaypointIndex + 1) mod _routeCount;
    _veh setDir (_spawnPos getDir (_route select _nextWaypointIndex));
    _veh setPosATL _spawnPos;
    _veh setVectorUp (surfaceNormal _spawnPos);

    private _grp = createGroup civilian;
    private _driver = _grp createUnit [selectRandom _trafficCivilianClasses, _spawnPos, [], 0, "CARGO"];
    _driver moveInDriver _veh;
    _driver setVariable ["CO_trafficDriver", true];

    // Add random civilian passengers
    private _paxCount = 1 + floor (random 3);
    for "_p" from 1 to _paxCount do {
        private _pax = _grp createUnit [selectRandom _trafficPassengerClasses, _spawnPos, [], 0, "CARGO"];
        _pax moveInCargo _veh;
    };

    // Waypoints
    { private _wp = _grp addWaypoint [_x, 15]; _wp setWaypointSpeed "LIMITED"; } forEach _route;
    private _cycleWp = _grp addWaypoint [_route select 0, 0];
    _cycleWp setWaypointType "CYCLE";

    // Police stop check loop
    [_veh, _grp] spawn {
        params ["_v", "_g"];
        while { alive _v } do {
            sleep (60 + random 120);
            if (!CO_police_active) then { continue };
            if (random 1 < CO_police_carStopChance) then {
                // Find a nearby police unit
                private _cops = allGroups select {
                    _x getVariable ["CO_faction",""] == "POLICE" && count units _x > 0
                };
                if (count _cops > 0) then {
                    private _cop = leader (_cops select 0);
                    if (_cop distance _v < 400) then {
                        // Halt vehicle briefly
                        _v engineOn false;
                        sleep 10;
                        _v engineOn true;
                        // Check passengers for wanted level
                        { 
                            private _u = _x;
                            if (isPlayer _u) then {
                                if ([_cop, _u] call co_main_fnc_policeRecognise) then {
                                    [[_u], group _cop] remoteExec ["co_main_fnc_checkpointAlert", 2];
                                };
                            };
                        } forEach crew _v;
                    };
                };
            };
        };
    };

    _veh
};

// Initial spawn: 2 vehicles per route, but at separated route points to avoid pileups.
{
    private _secondarySpawnIndex = if ((count _x) > 2) then { floor ((count _x) / 2) } else { 1 min ((count _x) - 1) };
    [_x, 0] call _spawnTrafficVehicle;
    if (_secondarySpawnIndex > 0) then {
        [_x, _secondarySpawnIndex] call _spawnTrafficVehicle;
    };
} forEach CO_trafficRoutes;

diag_log format ["[CO] Traffic system started on %1 routes.", count CO_trafficRoutes];

// Respawn loop: maintain roughly 2 vehicles per route without stacking them at one point.
[] spawn {
    while { true } do {
        sleep 120;
        {
            private _route = _x;
            private _nearVehicles = (_route select 0) nearEntities [["Car"], 500];
            if (count _nearVehicles < 2) then {
                private _spawnIndex = floor (random (count _route));
                [_route, _spawnIndex] call _spawnTrafficVehicle;
            };
        } forEach CO_trafficRoutes;
    };
};
