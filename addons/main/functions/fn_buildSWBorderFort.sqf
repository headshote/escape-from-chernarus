// ============================================================
// fn_buildSWBorderFort.sqf
//
// Builds a chain of hard south-western border fortifications
// along the road that leaves Chernarus past Kamenka, ALL the
// way to the map-edge terminus (grid 000,016 — world ~[200,
// 1700]). These are SHOOT-TO-KILL zones — players approaching
// are engaged with lethal fire (every group is tagged
// CO_lethalShooter so the non-lethal damage handler does NOT
// cap their bullets).
//
// Gameplay role: prevent the player from simply driving out
// of the map at the south-western coast. They must find
// another way through (boat, swimming around, or the eastern
// front via Russian lines).
// ============================================================

if (!isServer) exitWith {};
if (missionNamespace getVariable ["CO_swBorderFortBuilt", false]) exitWith {};
CO_swBorderFortBuilt = true;

// Each entry: [center, facingDir, role]
//   role "main"     : checkpoint_heavy + flanks + wedge + 12 lethal guards
//   role "support"  : border_outpost + 6 lethal guards
// Positions trace the SW coastal road from west of Kamenka all
// the way to the map-edge cliff. "main" goes at the actual road
// terminus the user identified (grid 000,016).
private _fortChain = [
    [[ 220, 1720, 0], 270, "main"],     // grid 002,017 — map-edge road end
    [[ 700, 1850, 0], 250, "support"],  // mid SW coastal road
    [[1250, 2080, 0], 240, "support"],  // west of coastal bend
    [[1750, 2350, 0], 230, "support"],  // just west of Kamenka
    [[2120, 2500, 0], 220, "support"]   // Kamenka western approach
];

// ---- Helpers -------------------------------------------------
private _stampMain = {
    params ["_pos", "_dir"];
    [_pos, _dir, "checkpoint_heavy"] call co_main_fnc_stampFortification;
    [_pos getPos [25, _dir + 90],  _dir, "border_tower"]   call co_main_fnc_stampFortification;
    [_pos getPos [25, _dir - 90],  _dir, "border_tower"]   call co_main_fnc_stampFortification;
    [_pos getPos [60, _dir + 90],  _dir, "border_outpost"] call co_main_fnc_stampFortification;
    [_pos getPos [60, _dir - 90],  _dir, "border_outpost"] call co_main_fnc_stampFortification;

    private _wedge = [
        [18,  18], [18, -18], [28,  14], [28, -14], [38,  10], [38, -10]
    ];
    {
        _x params ["_fwd", "_side"];
        private _p = _pos getPos [_fwd, _dir];
        _p = _p getPos [abs _side, _dir + (if (_side >= 0) then {90} else {270})];
        private _o = "Land_HBarrier_Big_F" createVehicle _p;
        _o setDir (_dir + 90);
        _o setPos _p;
    } forEach _wedge;
};

private _stampSupport = {
    params ["_pos", "_dir"];
    [_pos, _dir, "border_outpost"] call co_main_fnc_stampFortification;
    [_pos getPos [18, _dir + 90], _dir, "border_tower"] call co_main_fnc_stampFortification;
};

private _spawnLethalGarrison = {
    params ["_pos", "_dir", "_count", "_engageRadius"];

    private _grp = createGroup [west, true];
    _grp setVariable ["CO_faction", "CRN_ENF", true];
    _grp setVariable ["CO_lethalShooter", true, true];
    _grp setVariable ["CO_swBorderFort", true, true];
    _grp setBehaviour "AWARE";
    _grp setCombatMode "RED";
    _grp setSpeedMode "FULL";
    _grp setFormation "STAG COLUMN";

    private _unitPool = ["B_Soldier_F", "B_Soldier_AR_F", "B_Soldier_TL_F", "B_Soldier_M_F"];
    for "_i" from 0 to (_count - 1) do {
        // Spread the garrison around the gate
        private _ang  = (_i * (360 / _count)) + (random 30 - 15);
        private _dist = 4 + random 14;
        private _p = _pos getPos [_dist, _ang];
        private _u = _grp createUnit [selectRandom _unitPool, _p, [], 0, "FORM"];
        [_u] call co_main_fnc_initHostileUnit;
        _u setBehaviour "AWARE";
        _u setCombatMode "RED";
        _u setSkill ["aimingAccuracy", 0.55];
        _u setSkill ["aimingShake",    0.65];
        _u setSkill ["aimingSpeed",    0.75];
        _u setSkill ["spotDistance",   1.0];
        _u setSkill ["spotTime",       0.9];
        _u setSkill ["courage",        1.0];
        _u allowFleeing 0;
        _u setUnitPos "AUTO";
    };

    // Hold position waypoint at the gate
    private _wpHold = _grp addWaypoint [_pos, 0];
    _wpHold setWaypointType "SENTRY";
    _wpHold setWaypointSpeed "LIMITED";

    // Scripted lethal engagement loop (civilians are setFriend west=1, so
    // the engine won't auto-fire on them — we force it).
    [_grp, _pos, _engageRadius] spawn {
        params ["_grp", "_center", "_radius"];
        while { ({ alive _x } count units _grp) > 0 } do {
            sleep 2;
            private _hostiles = (_center nearEntities [["Man"], _radius]) select {
                private _t = _x;
                alive _t &&
                vehicle _t == _t &&
                !(_t getVariable ["CO_knockedOut", false]) &&
                (isPlayer _t || side _t == civilian) &&
                { !((group _t) getVariable ["CO_faction", ""] in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) }
            };
            // Also engage hostile vehicles (cars driven by players)
            private _vTargets = (_center nearEntities [["Car","Truck"], _radius]) select {
                private _v = _x;
                alive _v && !(_v getVariable ["CO_isBusPatrol", false]) && {
                    private _d = driver _v;
                    !isNull _d && alive _d && (isPlayer _d || side _d == civilian)
                }
            };

            private _allTargets = _hostiles;
            if (count _vTargets > 0) then {
                _allTargets = _allTargets + (_vTargets apply { driver _x });
            };
            if (_allTargets isEqualTo []) then { continue };

            private _sorted = [_allTargets, [], { _x distance2D _center }, "ASCEND"] call BIS_fnc_sortBy;
            private _tgt = _sorted select 0;

            {
                if (alive _x) then {
                    _x reveal [_tgt, 4];
                    _x doTarget _tgt;
                    _x doFire _tgt;
                    _x setCombatMode "RED";
                    _x setBehaviour "AWARE";
                };
            } forEach (units _grp);

            private _engageUntil = time + 35;
            waitUntil {
                sleep 1.5;
                !alive _tgt ||
                captive _tgt ||
                (_center distance2D _tgt > _radius + 60) ||
                time > _engageUntil
            };

            { if (alive _x) then { _x doWatch objNull } } forEach units _grp;
        };
    };

    _grp
};

// ---- Build each fort in the chain ----------------------------
{
    _x params ["_pos", "_dir", "_role"];

    // Snap to nearest road if one is close (cleaner placement)
    private _rds = _pos nearRoads 100;
    if (count _rds > 0) then {
        _pos = getPos (_rds select 0);
    };

    if (_role == "main") then {
        [_pos, _dir] call _stampMain;
        [_pos, _dir, 12, 200] call _spawnLethalGarrison;
        diag_log format ["[CO] SW border fort MAIN built at %1 (grid %2).", _pos, mapGridPosition _pos];
    } else {
        [_pos, _dir] call _stampSupport;
        [_pos, _dir,  6, 140] call _spawnLethalGarrison;
        diag_log format ["[CO] SW border fort SUPPORT built at %1 (grid %2).", _pos, mapGridPosition _pos];
    };

    sleep 0.3;
} forEach _fortChain;

diag_log "[CO] SW border fortification chain online.";

