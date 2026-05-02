// ============================================================
// fn_spawnBusOnRoute.sqf
// Spawns a single bus on a given waypoint route.
// ============================================================

params ["_routeWps", "_hostilesCount"];

private _spawnPos  = _routeWps select 0;
private _nearRoad  = _spawnPos nearRoads 20;
if (count _nearRoad > 0) then { _spawnPos = getPos (_nearRoad select 0); };

private _vehiclePool = missionNamespace getVariable ["CO_bus_vehiclePool", ["C_Van_01_transport_F", "C_Truck_02_transport_F"]];
private _veh = selectRandom _vehiclePool createVehicle _spawnPos;
private _grp = createGroup west;
_grp setVariable ["CO_faction", "CRN_ENF"];

// Driver
private _driver = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
_driver moveInDriver _veh;

// Hostile cargo
for "_i" from 1 to _hostilesCount do {
    private _u = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
    _u moveInCargo _veh;
    [_u] call co_main_fnc_initHostileUnit;
};

// Assign waypoints from route
{ private _wp = _grp addWaypoint [_x, 10]; _wp setWaypointSpeed "NORMAL"; } forEach _routeWps;
private _cycleWp = _grp addWaypoint [_routeWps select 0, 0];
_cycleWp setWaypointType "CYCLE";

// Attach aggro loop
[_veh, _grp] spawn co_main_fnc_busAgroLoop;