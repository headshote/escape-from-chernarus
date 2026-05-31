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
    _grp setVariable ["CO_swBorderFort", true, true];
    // NOTE: CO_lethalShooter is NOT set on spawn anymore. It is toggled
    // ON dynamically by the hit-reactive / pursuit-escalation logic
    // below. Detain-first is the primary behaviour; lethal fire is the
    // fallback when a target has been shooting at the post or has been
    // evading the wrangle pipeline for too long.
    _grp setBehaviour "AWARE";
    _grp setCombatMode "YELLOW";
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
        _u setCombatMode "YELLOW";
        _u setSkill ["aimingAccuracy", 0.55];
        _u setSkill ["aimingShake",    0.65];
        _u setSkill ["aimingSpeed",    0.75];
        _u setSkill ["spotDistance",   1.0];
        _u setSkill ["spotTime",       0.9];
        _u setSkill ["courage",        1.0];
        _u allowFleeing 0;
        _u setUnitPos "AUTO";

        // Hit-reactive: if a guard is shot by a civilian/player, that
        // shooter becomes a "hot hostile" and the lethal escalation loop
        // below will fire on them.
        _u addEventHandler ["HandleDamage", {
            params ["_unit", "", "_dmg", "_src"];
            if (!isNull _src && _src != _unit) then {
                private _atk = if (_src isKindOf "Man") then { _src } else {
                    private _d = driver _src;
                    if (!isNull _d) then { _d } else { _src }
                };
                if (_atk isKindOf "Man" && (isPlayer _atk || side _atk == civilian)) then {
                    _atk setVariable ["CO_hotHostile", time + 45, true];
                    private _g = group _unit;
                    _g setVariable ["CO_lethalShooter", true, true];
                    _g setVariable ["CO_lethalUntil", time + 60, true];
                };
            };
            _dmg
        }];
    };

    // Hold position waypoint at the gate
    private _wpHold = _grp addWaypoint [_pos, 0];
    _wpHold setWaypointType "SENTRY";
    _wpHold setWaypointSpeed "LIMITED";

    // ---- Primary behaviour: DETAIN ---------------------------
    // Standard guard aggro loop (wrangle → knockout → transport).
    // This is the only scan running by default. Lethal fire only
    // activates if (a) someone shot a guard, or (b) the guards have
    // been chasing the same evading target for >60s without capture.
    [_grp, _pos, _engageRadius min 150, "CRN_ENF"] call co_main_fnc_guardAggroLoop;

    // ---- Fallback: LETHAL ESCALATION -------------------------
    // Only fires when the group has been flagged CO_lethalShooter
    // (via hit reaction or stale-pursuit escalation). When the timer
    // expires with no further trigger, the group falls back to
    // detain-first behaviour.
    [_grp, _pos, _engageRadius] spawn {
        params ["_grp", "_center", "_radius"];
        private _pursuitTrack = createHashMap;  // target -> first-seen time

        while { ({ alive _x } count units _grp) > 0 } do {
            sleep 3;

            // ---- (1) Stale-pursuit escalation -----------------
            // If guardAggroLoop has been pursuing a target for more
            // than 60s without capture (target alive, not captive,
            // not knocked out, still in range), flag lethal mode.
            private _scan = (_center nearEntities [["Man"], _radius]) select {
                private _t = _x;
                alive _t && vehicle _t == _t &&
                !captive _t &&
                !(_t getVariable ["CO_knockedOut", false]) &&
                (isPlayer _t || side _t == civilian) &&
                { !((group _t) getVariable ["CO_faction", ""] in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) }
            };
            {
                private _t = _x;
                private _first = _pursuitTrack getOrDefault [netId _t, time];
                if !(netId _t in _pursuitTrack) then {
                    _pursuitTrack set [netId _t, time];
                };
                if ((time - _first) > 60) then {
                    _t setVariable ["CO_hotHostile", time + 45, true];
                    _grp setVariable ["CO_lethalShooter", true, true];
                    _grp setVariable ["CO_lethalUntil", time + 60, true];
                };
            } forEach _scan;
            // Drop tracker entries for targets that left the area
            {
                private _id = _x;
                if (({ netId _x == _id } count _scan) == 0) then {
                    _pursuitTrack deleteAt _id;
                };
            } forEach (keys _pursuitTrack);

            // ---- (2) Lethal expiry --------------------------
            private _lethalUntil = _grp getVariable ["CO_lethalUntil", 0];
            if (time > _lethalUntil) then {
                if (_grp getVariable ["CO_lethalShooter", false]) then {
                    _grp setVariable ["CO_lethalShooter", false, true];
                    { if (alive _x) then { _x doWatch objNull } } forEach units _grp;
                };
                // No active engagement; loop continues, just scans
            } else {
                // ---- (3) Active lethal engagement ----------
                // Pick nearest tagged hot hostile in range and fire.
                private _hot = (_center nearEntities [["Man"], _radius]) select {
                    private _t = _x;
                    alive _t && vehicle _t == _t &&
                    ((_t getVariable ["CO_hotHostile", 0]) > time) &&
                    (isPlayer _t || side _t == civilian)
                };
                private _vTargets = (_center nearEntities [["Car","Truck"], _radius]) select {
                    private _v = _x;
                    alive _v && !(_v getVariable ["CO_isBusPatrol", false]) &&
                    !(_v getVariable ["CO_isCaptureTransport", false]) && {
                        private _d = driver _v;
                        !isNull _d && alive _d &&
                        ((_d getVariable ["CO_hotHostile", 0]) > time)
                    }
                };
                private _all = _hot;
                if (count _vTargets > 0) then {
                    _all = _all + (_vTargets apply { driver _x });
                };

                if (count _all > 0) then {
                    private _sorted = [_all, [], { _x distance2D _center }, "ASCEND"] call BIS_fnc_sortBy;
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
                };
            };
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

