// ============================================================
// fn_buildSWBorderFort.sqf
//
// Builds the hard south-western border fortification on the
// road that leaves Chernarus past Kamenka. This is a SHOOT-TO-
// KILL zone — players approaching the gate are engaged with
// lethal fire (the group is tagged CO_lethalShooter so the
// non-lethal damage handler does NOT cap their bullets).
//
// Gameplay role: prevent the player from simply driving out
// of the map at the south-western coast. They must find
// another way through (boat, swimming around, or the eastern
// front via Russian lines).
// ============================================================

if (!isServer) exitWith {};
if (missionNamespace getVariable ["CO_swBorderFortBuilt", false]) exitWith {};
CO_swBorderFortBuilt = true;

// ---- 1. Gate position (south-west road, west of Kamenka) -----
// Kamenka sits at roughly [2360, 2470] on Chernarus. The road
// continues west to the map edge. We anchor the fort ~900 m
// west of town, blocking the only westbound road.
private _gatePos = [1450, 2460, 0];
private _gateDir = 270;  // facing west (toward map edge)

// Snap to nearest road if possible
private _rds = _gatePos nearRoads 80;
if (count _rds > 0) then {
    _gatePos = getPos (_rds select 0);
};

diag_log format ["[CO] SW border fort: building at %1.", mapGridPosition _gatePos];

// ---- 2. Stamp heavy fortifications across the road ----------
[_gatePos, _gateDir, "checkpoint_heavy"] call co_main_fnc_stampFortification;

// Flanking watchtowers (north and south of road) for overlapping fire
[_gatePos getPos [25, _gateDir + 90],  _gateDir, "border_tower"]   call co_main_fnc_stampFortification;
[_gatePos getPos [25, _gateDir - 90],  _gateDir, "border_tower"]   call co_main_fnc_stampFortification;
[_gatePos getPos [60, _gateDir + 90],  _gateDir, "border_outpost"] call co_main_fnc_stampFortification;
[_gatePos getPos [60, _gateDir - 90],  _gateDir, "border_outpost"] call co_main_fnc_stampFortification;

// Extra HESCOs forming a wedge funnel forcing approach down the road
private _wedgePieces = [
    [18,  18,  0], [18, -18,  0],
    [28,  14,  0], [28, -14,  0],
    [38,  10,  0], [38, -10,  0]
];
{
    private _fwd  = _x select 0;
    private _side = _x select 1;
    private _p = _gatePos getPos [_fwd, _gateDir];
    _p = _p getPos [abs _side, _gateDir + (if (_side >= 0) then {90} else {270})];
    private _o = "Land_HBarrier_Big_F" createVehicle _p;
    _o setDir (_gateDir + 90);
    _o setPos _p;
} forEach _wedgePieces;

// ---- 3. Spawn the lethal garrison ---------------------------
// Single big group so they coordinate fires. Tagged CO_lethalShooter
// so fn_installNonLethalDamage lets their bullets through full damage.
private _grp = createGroup [west, true];
_grp setVariable ["CO_faction", "CRN_ENF", true];
_grp setVariable ["CO_lethalShooter", true, true];
_grp setVariable ["CO_swBorderFort", true, true];
_grp setBehaviour "AWARE";
_grp setCombatMode "RED";
_grp setSpeedMode "FULL";
_grp setFormation "STAG COLUMN";

private _unitPool = ["B_Soldier_F", "B_Soldier_AR_F", "B_Soldier_TL_F", "B_Soldier_M_F"];
private _garrisonSpots = [
    [0,    0,  0], [4,   6,  0], [4,  -6,  0],
    [10,  10,  0], [10, -10, 0], [25,  14,  0], [25, -14, 0],
    [60,   0,  0], [-6,  8,  0], [-6, -8,  0]
];
{
    private _fwd  = _x select 0;
    private _side = _x select 1;
    private _p = _gatePos getPos [_fwd, _gateDir];
    _p = _p getPos [abs _side, _gateDir + (if (_side >= 0) then {90} else {270})];
    private _u = _grp createUnit [selectRandom _unitPool, _p, [], 0, "FORM"];
    [_u] call co_main_fnc_initHostileUnit;
    // Lethal posture
    _u setBehaviour "AWARE";
    _u setCombatMode "RED";
    _u setSkill ["aimingAccuracy", 0.5];
    _u setSkill ["aimingShake",    0.6];
    _u setSkill ["aimingSpeed",    0.7];
    _u setSkill ["spotDistance",   1.0];
    _u setSkill ["spotTime",       0.9];
    _u setSkill ["courage",        1.0];
    _u allowFleeing 0;
    _u setUnitPos "AUTO";
} forEach _garrisonSpots;

// Hold position waypoint at the gate
private _wpHold = _grp addWaypoint [_gatePos, 0];
_wpHold setWaypointType "SENTRY";
_wpHold setWaypointSpeed "LIMITED";

// ---- 4. Scripted lethal engagement loop ---------------------
// Engine relations make civilians friends-of-west, so even with
// COMBAT/RED the garrison won't autonomously engage civs/players.
// This loop scans 180 m, and once it spots a non-faction
// target it forces every unit to target+fire until the target
// is down or out of range.
private _engageRadius = 180;
[_grp, _gatePos, _engageRadius] spawn {
    params ["_grp", "_center", "_radius"];
    while { ({ alive _x } count units _grp) > 0 } do {
        sleep 2;

        private _hostiles = (_center nearEntities [["Man"], _radius]) select {
            private _t = _x;
            alive _t &&
            !(_t getVariable ["CO_knockedOut", false]) &&
            (isPlayer _t || side _t == civilian) &&
            { !((group _t) getVariable ["CO_faction", ""] in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) }
        };
        if (_hostiles isEqualTo []) then { continue };

        private _sorted = [_hostiles, [], { _x distance2D _center }, "ASCEND"] call BIS_fnc_sortBy;
        private _tgt = _sorted select 0;

        // Make every live unit reveal + target + fire
        {
            if (alive _x) then {
                _x reveal [_tgt, 4];
                _x doTarget _tgt;
                _x doFire _tgt;
                _x setCombatMode "RED";
                _x setBehaviour "AWARE";
            };
        } forEach (units _grp);

        // Engage until the target dies/leaves/captives
        private _engageUntil = time + 30;
        waitUntil {
            sleep 1.5;
            !alive _tgt ||
            captive _tgt ||
            (_center distance2D _tgt > _radius + 40) ||
            time > _engageUntil
        };

        // Return to sentry posture briefly between contacts
        { if (alive _x) then { _x doWatch objNull } } forEach units _grp;
    };
};

diag_log format ["[CO] SW border fort online: %1 lethal guards at %2.", count (units _grp), mapGridPosition _gatePos];
