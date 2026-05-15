// ============================================================
// fn_spawnBusOnRoute.sqf
// Spawns a single hostile press-gang vehicle on a route. The
// vehicle is driven entirely by fn_busAgroLoop via scripted
// doMove commands; we do NOT use engine waypoints here because
// they were unreliable (drivers hesitating, paths failing).
// ============================================================

params ["_routeWps", "_hostilesCount"];

if (count _routeWps == 0) exitWith { diag_log "[CO] spawnBusOnRoute called with empty route." };

private _spawnPos = _routeWps select 0;
private _nearRoads = _spawnPos nearRoads 60;
if (count _nearRoads > 0) then {
    _spawnPos = getPos (selectRandom _nearRoads);
};

// Ensure a clear empty spot
private _empty = _spawnPos findEmptyPosition [0, 25, "C_Van_01_transport_F"];
if !(_empty isEqualTo []) then { _spawnPos = _empty };

private _vehiclePool = missionNamespace getVariable [
    "CO_bus_vehiclePool",
    ["C_Van_01_transport_F","C_Truck_02_transport_F"]
];
private _vehClass = selectRandom _vehiclePool;
private _veh = createVehicle [_vehClass, _spawnPos, [], 0, "NONE"];
_veh setDir random 360;
_veh setVectorUp [0,0,1];

private _grp = createGroup west;
_grp setVariable ["CO_faction", "CRN_ENF", true];
_grp setVariable ["CO_transportVehicle", _veh, false];
_grp deleteGroupWhenEmpty true;

// --- Driver ---
private _driver = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "NONE"];
[_driver] call co_main_fnc_initHostileUnit;
_driver moveInDriver _veh;
_grp selectLeader _driver;
_driver setRank "SERGEANT";

// --- Cargo escorts ---
for "_i" from 1 to _hostilesCount do {
    private _u = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "NONE"];
    [_u] call co_main_fnc_initHostileUnit;
    _u moveInCargo _veh;
};

// Group posture — kept AWARE/YELLOW so escorts open fire when ordered
// during engage, but cruise behavior is fully scripted (doMove + forceSpeed).
_grp setBehaviour "AWARE";
_grp setCombatMode "YELLOW";
_grp setSpeedMode "NORMAL";

{
    _x enableAI "MOVE";
    _x enableAI "PATH";
    _x enableAI "AUTOCOMBAT";
    _x enableAI "FSM";
} forEach (units _grp);

// Mark the patrol so other scripts (aggro loops, dispatchers) can find it
_veh setVariable ["CO_isBusPatrol", true, true];
_veh setVariable ["CO_busState", "cruising", true];
_veh setVariable ["CO_busRouteWps", _routeWps, false];
_veh setVariable ["CO_busCaptives", [], true];
_veh setVariable ["CO_busNextEngageAt", 0, false];
_veh setVehicleLock "UNLOCKED";

_veh engineOn true;
_veh setFuel 1;

// Hand off to the active control loop
[_veh, _grp] spawn co_main_fnc_busAgroLoop;

diag_log format [
    "[CO] Spawned bus %1 on route '%2' (%3 wps) at %4.",
    _vehClass,
    (_routeWps select 0),
    count _routeWps,
    mapGridPosition _veh
];

_veh
