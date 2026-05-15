// ============================================================
// fn_spawnBusOnRoute.sqf
//
// Spawns a single hostile press-gang patrol vehicle on a route.
//
// Design rules (learned the hard way):
//
// 1. **Spawn must be on a real road** with no overlapping
//    geometry, otherwise the engine despawns or detonates the
//    vehicle on creation. We expand the road-search radius up
//    to 600 m and validate with findEmptyPosition before
//    falling back to a defensive in-air spawn.
//
// 2. **The driver group must be CARELESS / BLUE**. Anything
//    above that makes the AI driver hesitate every time it
//    perceives a noise/civilian (and `civilian setFriend west,1`
//    means the engine treats every civilian as an ally — i.e.
//    every civilian becomes a "noise" event). With CARELESS the
//    driver just goes where doMove tells it.
//
// 3. **Escorts live in a SEPARATE group** (also CARELESS BLUE
//    while seated) so the driver's behaviour doesn't propagate
//    into them. When fn_busAgroLoop dismounts them it switches
//    *their* group to AWARE/YELLOW for the hunt.
//
// 4. **Vehicle starts unlocked, fuelled, engine on**, so the
//    very first doMove starts moving immediately. We also call
//    `_veh forceFollowRoad true` to keep the truck on roads
//    rather than cross-country.
//
// All aggression is scripted from fn_busAgroLoop — engine
// waypoints are intentionally NOT used.
// ============================================================

params ["_routeWps", "_hostilesCount"];

if (count _routeWps == 0) exitWith {
    diag_log "[CO] spawnBusOnRoute: empty route — abort.";
    objNull
};

// ---- 1. Find a safe road position to spawn on -------------------------
// Per-spawn seed jitter so multiple buses on the same route don't all
// converge onto the same road object on the first try.
private _seedPos = (_routeWps select 0) vectorAdd [(random 60) - 30, (random 60) - 30, 0];
private _spawnPos = [];
private _radius = 80;
while { _spawnPos isEqualTo [] && _radius <= 700 } do {
    private _roads = _seedPos nearRoads _radius;
    // Prefer roads we can drive (not foot-paths, not road segments under
    // bridges where vehicles fall through).
    private _candidates = _roads select { !isNull _x && isOnRoad (getPos _x) };
    if (count _candidates > 0) then {
        // Try several candidates; reject any with another vehicle within 14 m
        // (catches the case of multiple buses spawning back-to-back).
        private _tries = _candidates call BIS_fnc_arrayShuffle;
        if (count _tries > 18) then { _tries resize 18 };
        {
            private _p = getPos _x;
            // Already a vehicle here? skip.
            private _nearVehs = _p nearEntities [["Car","Truck","Tank","Ship"], 14];
            if (count _nearVehs > 0) then { continue };

            private _empty = _p findEmptyPosition [0, 6, "C_Truck_02_transport_F"];
            if !(_empty isEqualTo []) exitWith { _spawnPos = _empty };
            private _empty2 = _p findEmptyPosition [4, 22, "C_Truck_02_transport_F"];
            if !(_empty2 isEqualTo []) exitWith { _spawnPos = _empty2 };
        } forEach _tries;
    };
    if (_spawnPos isEqualTo []) then { _radius = _radius + 120 };
};

if (_spawnPos isEqualTo []) exitWith {
    diag_log format ["[CO] spawnBusOnRoute: no safe road within %1 m of %2.", _radius, _seedPos];
    objNull
};

// ---- 2. Create the vehicle (NONE = exact spot, no engine offset) ------
private _vehiclePool = missionNamespace getVariable [
    "CO_bus_vehiclePool",
    ["C_Van_01_transport_F","C_Truck_02_transport_F"]
];
private _vehClass = selectRandom _vehiclePool;
private _veh = createVehicle [_vehClass, _spawnPos, [], 0, "NONE"];
// Immediate damage immunity — some Chernarus road tiles have invisible
// geometry that registers a collision on the same frame the vehicle is
// placed, which is what was blowing trucks up on spawn. We re-enable
// damage a few seconds later when the truck is settled.
_veh allowDamage false;
// Order matters: setPosATL CAN re-snap vector up, so position FIRST then
// straighten the truck.
_veh setPosATL [_spawnPos select 0, _spawnPos select 1, 0.15];
_veh setVectorUp [0, 0, 1];
_veh setVelocity [0, 0, 0];

// Face toward the next route point so the first doMove doesn't make the
// truck pivot in place on top of nearby buildings.
private _aimAt = if (count _routeWps > 1) then { _routeWps select 1 } else { _spawnPos };
private _dx = (_aimAt select 0) - (_spawnPos select 0);
private _dy = (_aimAt select 1) - (_spawnPos select 1);
_veh setDir (_dx atan2 _dy);

// Re-enable damage after a short settle window
[_veh] spawn {
    params ["_v"];
    sleep 5;
    if (!isNull _v && alive _v) then { _v allowDamage true };
};

// ---- 3. Create separate driver group (SAFE BLUE) ----------------------
// SAFE is the proven pattern for AI vehicle drivers (see fn_policePatrols).
// CARELESS combined with disableAI FSM/PATH/COVER deadlocks pathfinding —
// the truck just sits idling. SAFE drivers won't engage allies (civs are
// setFriend=1 to west) and will execute doMove reliably.
private _driverGrp = createGroup [west, true];
_driverGrp setVariable ["CO_faction", "CRN_ENF", true];
_driverGrp setVariable ["CO_isBusDriverGrp", true, true];
_driverGrp setVariable ["CO_transportVehicle", _veh, true];
_driverGrp setBehaviour "SAFE";
_driverGrp setCombatMode "BLUE";
_driverGrp setSpeedMode "NORMAL";
_driverGrp setFormation "FILE";

private _driver = _driverGrp createUnit ["B_Soldier_F", _spawnPos, [], 0, "NONE"];
[_driver] call co_main_fnc_initHostileUnit;
// Override the AWARE/YELLOW set by initHostileUnit — driver stays SAFE so
// it never breaks off route to engage. AUTOTARGET/TARGET disabled so it
// won't ever stop to acquire targets; FSM/PATH stay enabled so pathfinding
// actually works.
_driver setBehaviour "SAFE";
_driver setCombatMode "BLUE";
_driver disableAI "AUTOTARGET";
_driver disableAI "TARGET";
_driver setUnitPos "UP";
_driver setSkill ["courage", 1];
_driver allowFleeing 0;
_driverGrp selectLeader _driver;
_driver moveInDriver _veh;

// ---- 4. Create escort group (SAFE BLUE while seated) ------------------
// Escorts stay SAFE until the bus loop dismounts them, then it flips the
// group to AWARE/YELLOW for the hunt.
private _escortGrp = createGroup [west, true];
_escortGrp setVariable ["CO_faction", "CRN_ENF", true];
_escortGrp setVariable ["CO_isBusEscortGrp", true, true];
_escortGrp setVariable ["CO_transportVehicle", _veh, true];
_escortGrp setBehaviour "SAFE";
_escortGrp setCombatMode "BLUE";
_escortGrp setSpeedMode "FULL";
_escortGrp setFormation "WEDGE";

private _escorts = [];
for "_i" from 1 to _hostilesCount do {
    private _u = _escortGrp createUnit ["B_Soldier_F", _spawnPos, [], 0, "NONE"];
    [_u] call co_main_fnc_initHostileUnit;
    _u setBehaviour "SAFE";
    _u setCombatMode "BLUE";
    _u disableAI "AUTOTARGET";
    _u disableAI "TARGET";
    _u allowFleeing 0;
    _u moveInCargo _veh;
    _escorts pushBack _u;
};
if (count _escorts > 0) then { _escortGrp selectLeader (_escorts select 0) };

// ---- 5. Vehicle state + bus runtime variables -------------------------
_veh setVehicleLock "UNLOCKED";
_veh setFuel 1;
_veh engineOn true;
// NOTE: don't `forceFollowRoad true` here — it deadlocks when the truck
// spawns even slightly off-road. Routes are road-graph based, so the AI
// will use roads naturally.
_veh allowDamage true;

_veh setVariable ["CO_isBusPatrol", true, true];
_veh setVariable ["CO_busState", "traveling", true];
_veh setVariable ["CO_busRouteWps", _routeWps, true];
_veh setVariable ["CO_busCaptives", [], true];
_veh setVariable ["CO_busDriverGrp", _driverGrp, true];
_veh setVariable ["CO_busEscortGrp", _escortGrp, true];

// ---- 6. Engine waypoints for the cruise route -------------------------
// SCRIPTED doMove turned out to be unreliable for long-haul routes:
// SAFE-behaviour drivers with disableAI "TARGET" frequently swallow the
// command on first tick (vehicle just placed, driver just seated, route
// point >1 km away) and the truck never moves. ARMA waypoints with a
// CYCLE close-out are the proven pattern (see fn_policePatrols) — the
// engine handles long-haul pathing, road preference, and stuck recovery
// for us. The controller loop in fn_busAgroLoop now only OVERRIDES this
// via doMove when actively hunting a target.
{
    private _wp = _driverGrp addWaypoint [_x, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointCombatMode "BLUE";
    _wp setWaypointFormation "FILE";
    _wp setWaypointCompletionRadius 30;
} forEach _routeWps;
private _cycleWp = _driverGrp addWaypoint [_routeWps select 0, 0];
_cycleWp setWaypointType "CYCLE";
_cycleWp setWaypointSpeed "NORMAL";
_cycleWp setWaypointBehaviour "SAFE";
_cycleWp setWaypointCombatMode "BLUE";

// Hand off to the controller
[_veh, _driverGrp, _escortGrp] spawn co_main_fnc_busAgroLoop;

diag_log format [
    "[CO] Bus spawned: %1 at %2 (route '%3', %4 wps, %5 escorts).",
    _vehClass,
    mapGridPosition _veh,
    _routeWps select 0,
    count _routeWps,
    _hostilesCount
];

_veh
