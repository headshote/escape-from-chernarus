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
_grp setVariable ["CO_transportVehicle", _veh, false];
_grp deleteGroupWhenEmpty true;

// Driver
private _driver = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
_driver moveInDriver _veh;
[_driver] call co_main_fnc_initHostileUnit;
_grp selectLeader _driver;
_driver setRank "SERGEANT";

// Hostile cargo
for "_i" from 1 to _hostilesCount do {
    private _u = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
    _u moveInCargo _veh;
    [_u] call co_main_fnc_initHostileUnit;
};

// Assign waypoints from route
{
    private _wp = _grp addWaypoint [_x, 10];
    _wp setWaypointType "MOVE";
    _wp setWaypointBehaviour "AWARE";
    _wp setWaypointCombatMode "YELLOW";
    _wp setWaypointSpeed "NORMAL";
} forEach _routeWps;
private _cycleWp = _grp addWaypoint [_routeWps select 0, 0];
_cycleWp setWaypointType "CYCLE";

_grp setBehaviour "AWARE";
_grp setCombatMode "YELLOW";
_grp setSpeedMode "NORMAL";
_grp setFormation "FILE";

// Make sure the engine is on so the AI driver actually moves immediately
// (vans sometimes spawn with engine off and the driver waits for a fuel-up
// behaviour cycle before starting). Force the bus toward the first waypoint.
_veh engineOn true;
_veh forceSpeed -1;
{
    _x enableAI "MOVE";
    _x enableAI "PATH";
    _x enableAI "AUTOCOMBAT";
    _x setBehaviour "AWARE";
    _x setCombatMode "YELLOW";
    _x setSkill ["aimingAccuracy", 0.25];
    _x setSkill ["aimingShake", 0.4];
    _x setSkill ["spotDistance", 0.6];
    _x setSkill ["spotTime", 0.7];
    _x setSkill ["courage", 0.8];
} forEach (units _grp);

_veh setVariable ["CO_isBusPatrol", true, true];
_veh setVariable ["CO_busState", "patrol", true];
_veh setVariable ["CO_busRouteWps", _routeWps, false];
_veh setVariable ["CO_busCaptives", [], true];
_veh setVariable ["CO_busNextEngageAt", 0, false];
private _patrolStopInterval = missionNamespace getVariable ["CO_bus_patrolStopInterval", 75];
_veh setVariable ["CO_busLastPatrolStop", time - _patrolStopInterval + random 25, false];
_veh setVehicleLock "UNLOCKED";

// Attach aggro loop
[_veh, _grp] spawn co_main_fnc_busAgroLoop;