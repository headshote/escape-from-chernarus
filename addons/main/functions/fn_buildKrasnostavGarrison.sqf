// ============================================================
// fn_buildKrasnostavGarrison.sqf
//
// Creates a small BLUFOR (CRN_FRONT) garrison around Krasnostav,
// the jump-off point where freshly-cleared conscripts deploy. The
// garrison provides:
//   - A visible "friendly side" presence (not just empty streets).
//   - Static MGs and AT to soak the Russian armor wave.
//   - Sandbag positions and a couple of squads patrolling in HOLD
//     /SAD waypoints so contact happens quickly.
//
// IMPORTANT: CRN_FRONT garrison is NOT hooked into the TCK / police
// aggression loops. They never chase civilians, never set up
// checkpoints, never knock anyone out. They engage RUS_ADV only.
// Server-only.
// ============================================================
if (!isServer) exitWith {};

private _center = [11200, 12300, 0];

// ----- Statics: MGs (2) + AT (2) at compass points -----
private _staticPlan = [
    // [pos offset, dir, vehicle class]
    [[ 120,  60, 0],  90, "B_HMG_01_high_F"],   // east-facing HMG sandbag emplacement
    [[ 110, -50, 0],  80, "B_HMG_01_high_F"],   // east-facing HMG (south)
    [[ 140,  10, 0], 100, "B_static_AT_F"],     // forward AT
    [[ -30, 140, 0],  10, "B_static_AT_F"]      // rear AT covering northeast
];

private _staticGrp = createGroup west;
_staticGrp setVariable ["CO_faction", "CRN_FRONT", true];

{
    _x params ["_off", "_dir", "_cls"];
    private _p = _center vectorAdd _off;
    private _veh = createVehicle [_cls, _p, [], 0, "CAN_COLLIDE"];
    _veh setDir _dir;
    _veh setPos _p;

    // Sandbag wedge in front of each emplacement for visual cover.
    private _sb = createVehicle ["Land_BagFence_Long_F", _p vectorAdd [(sin _dir) * 2.2, (cos _dir) * 2.2, 0], [], 0, "CAN_COLLIDE"];
    _sb setDir _dir;

    private _gunner = _staticGrp createUnit ["B_Soldier_F", _p, [], 0, "NONE"];
    _gunner setVariable ["CO_faction", "CRN_FRONT", true];
    _gunner moveInGunner _veh;
    _gunner setBehaviour "AWARE";
    _gunner setCombatMode "YELLOW";
    _gunner setSkill 0.7;
    _gunner allowFleeing 0;
} forEach _staticPlan;

// ----- Infantry: ~12 soldiers in two squads patrolling the town -----
private _squadAnchors = [
    _center vectorAdd [  80,   80, 0],
    _center vectorAdd [ -60, -100, 0]
];

{
    private _anchor = _x;
    private _grp = createGroup west;
    _grp setVariable ["CO_faction", "CRN_FRONT", true];
    for "_i" from 1 to 6 do {
        private _u = _grp createUnit ["B_Soldier_F", _anchor, [], 4, "FORM"];
        _u setVariable ["CO_faction", "CRN_FRONT", true];
        _u setSkill 0.55;
        _u setBehaviour "AWARE";
        _u setCombatMode "YELLOW";
        _u allowFleeing 0;
    };

    // Local patrol ring + one SAD east lane so they meet incoming Russians.
    private _wpH = _grp addWaypoint [_anchor, 0];
    _wpH setWaypointType "HOLD";
    _wpH setWaypointBehaviour "AWARE";

    private _wpSAD = _grp addWaypoint [_anchor vectorAdd [300, 0, 0], 70];
    _wpSAD setWaypointType "SAD";
    _wpSAD setWaypointBehaviour "COMBAT";
    _wpSAD setWaypointCombatMode "RED";
    _wpSAD setWaypointSpeed "LIMITED";

    private _wpC = _grp addWaypoint [_anchor, 0];
    _wpC setWaypointType "CYCLE";
} forEach _squadAnchors;

// Marker so admins can see the garrison on the map.
private _mk = createMarker ["mk_krasnostav_garrison", _center];
_mk setMarkerType "b_inf";
_mk setMarkerColor "ColorBLUFOR";
_mk setMarkerText "CRN Garrison";
_mk setMarkerSize [0.7, 0.7];

diag_log "[CO] Krasnostav BLUFOR garrison spawned.";
