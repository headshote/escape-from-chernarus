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
private _seedPos = _routeWps select 0;
private _spawnPos = [];
private _radius = 60;
while { _spawnPos isEqualTo [] && _radius <= 600 } do {
    private _roads = _seedPos nearRoads _radius;
    // Prefer roads we can drive (not foot-paths, not road segments under
    // bridges where vehicles fall through).
    private _candidates = _roads select { !isNull _x && isOnRoad (getPos _x) };
    if (count _candidates > 0) then {
        // Try several candidates, pick the first one with empty surroundings
        private _tries = _candidates call BIS_fnc_arrayShuffle;
        if (count _tries > 12) then { _tries resize 12 };
        {
            private _p = getPos _x;
            private _empty = _p findEmptyPosition [0, 6, "C_Truck_02_transport_F"];
            if !(_empty isEqualTo []) exitWith { _spawnPos = _empty };
            // Fallback: accept road object position itself if findEmpty failed
            private _empty2 = _p findEmptyPosition [4, 18, "C_Truck_02_transport_F"];
            if !(_empty2 isEqualTo []) exitWith { _spawnPos = _empty2 };
        } forEach _tries;
    };
    if (_spawnPos isEqualTo []) then { _radius = _radius + 100 };
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
_veh setVectorUp [0, 0, 1];
_veh setPosATL [_spawnPos select 0, _spawnPos select 1, 0.1];

// Face toward the next route point so the first doMove doesn't make the
// truck pivot in place on top of nearby buildings.
private _aimAt = if (count _routeWps > 1) then { _routeWps select 1 } else { _spawnPos };
private _dx = (_aimAt select 0) - (_spawnPos select 0);
private _dy = (_aimAt select 1) - (_spawnPos select 1);
_veh setDir (_dx atan2 _dy);

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
