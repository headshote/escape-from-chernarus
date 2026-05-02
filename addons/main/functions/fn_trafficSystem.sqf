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
    [[4400,5600,0],[7300,7900,0],[9000,6100,0]],
];

private _spawnTrafficVehicle = {
    params ["_route"];
    private _spawnPos = _route select 0;
    private _nearRd   = _spawnPos nearRoads 30;
    if (count _nearRd > 0) then { _spawnPos = getPos (_nearRd select 0); };

    private _veh = (selectRandom CO_trafficVehiclePool) createVehicle _spawnPos;
    private _grp = createGroup civilian;
    private _driver = _grp createUnit ["C_man_polo_1_F", _spawnPos, [], 0, "CARGO"];
    _driver moveInDriver _veh;
    _driver setVariable ["CO_trafficDriver", true];

    // Add random civilian passengers
    private _paxCount = floor (random 3);
    for "_p" from 1 to _paxCount do {
        private _pax = _grp createUnit [selectRandom ["C_man_polo_1_F","C_man_polo_2_F","C_Woman_casual_F"], _spawnPos, [], 0, "CARGO"];
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

// Initial spawn: 1 vehicle per route
{ [_x] call _spawnTrafficVehicle; } forEach CO_trafficRoutes;

// Respawn loop: maintain roughly 2 vehicles per route
[] spawn {
    while { true } do {
        sleep 120;
        {
            private _route = _x;
            private _nearVehicles = (_route select 0) nearEntities [["Car"], 500];
            if (count _nearVehicles < 2) then {
                [_route] call _spawnTrafficVehicle;
            };
        } forEach CO_trafficRoutes;
    };
};