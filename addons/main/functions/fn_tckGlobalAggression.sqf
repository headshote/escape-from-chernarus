// ============================================================
// fn_tckGlobalAggression.sqf
//
// Server-side global failsafe that guarantees TCK aggression
// regardless of which subsystem (buses, checkpoints, border
// posts, etc.) the unit belongs to.
//
// Engine relation note: `civilian setFriend [west, 1]` means the
// engine treats every civilian as an ally to BLUFOR — so a TCK
// soldier will *never* autonomously engage a civilian even when
// standing nose-to-nose with them. All hostile action toward
// civilians must therefore be scripted.
//
// What this loop does
// -------------------
// Every 4 s on the server, walk every group whose CO_faction is
// "CRN_ENF" or "POLICE". For each foot-mobile unit in that group:
//
//   1. If a non-female civilian or player is within 22 m AND in
//      line-of-sight ish (we use nearEntities which already does
//      basic visibility filtering), pick the closest one and
//      issue `doMove` to their position.
//
//   2. If within 3 m of that target, call applyMeleeHit. The
//      melee system accumulates 3 hits → applyKnockout → captive.
//
//   3. After knockout, attempt to flag a nearby bus to come pick
//      them up via fn_dispatchCaptureTransport. Failing that, the
//      target stays captive on the ground for the duration of the
//      knockout (90 s) which is enough for any nearby patrol to
//      reach them.
//
// Throttling
// ----------
// Each unit has CO_lastAggressionAt to prevent the loop from
// repeatedly stomping on an in-flight chase. Units that are
// currently in vehicles, knocked out, dead, or already chasing
// (CO_lastAggressionAt within 6 s) are skipped.
// ============================================================

if (!isServer) exitWith {};
if (missionNamespace getVariable ["CO_tckGlobalAggression_running", false]) exitWith {};
CO_tckGlobalAggression_running = true;

#define TCK_SCAN_RADIUS 35
#define TCK_MELEE_RANGE  3.0
#define TCK_TICK         4

diag_log "[CO] tckGlobalAggression: starting global failsafe loop.";

[] spawn {
    while { true } do {
        sleep TCK_TICK;

        private _groups = allGroups select {
            (_x getVariable ["CO_faction", ""]) in ["CRN_ENF", "POLICE"]
        };

        {
            private _grp = _x;
            // Skip groups that are clearly busy with their own scripted
            // engagement — checkpointAlert sets CO_grpEngaging while it
            // owns the group.
            if (_grp getVariable ["CO_grpEngaging", false]) then { continue };
            // Skip bus driver / escort groups ONLY while their bus is alive
            // and the unit is mounted. Once the bus is destroyed (or the
            // escort is on foot away from it), they become eligible for
            // global aggression — otherwise wreck-survivors stand around.
            private _isBusGrp = (_grp getVariable ["CO_isBusDriverGrp", false]) ||
                                (_grp getVariable ["CO_isBusEscortGrp", false]);
            private _busVeh = _grp getVariable ["CO_transportVehicle", objNull];
            if (_isBusGrp && !isNull _busVeh && alive _busVeh) then { continue };

            {
                private _u = _x;
                if (isNull _u || !alive _u) then { continue };
                if (vehicle _u != _u) then { continue };  // skip mounted
                if (_u getVariable ["CO_knockedOut", false]) then { continue };
                if (_u getVariable ["CO_vehicleChaseDriver", false]) then { continue };

                private _last = _u getVariable ["CO_lastAggressionAt", 0];
                if ((time - _last) < 4) then { continue };

                private _center = getPosATL _u;
                private _cands = (_center nearEntities [["Man"], TCK_SCAN_RADIUS]) select {
                    private _t = _x;
                    private _ok = alive _t && vehicle _t == _t;
                    if (_ok && _t == _u) then { _ok = false };
                    if (_ok && captive _t) then { _ok = false };
                    if (_ok && (_t getVariable ["CO_knockedOut", false])) then { _ok = false };
                    if (_ok && (_t getVariable ["CO_isFemale", false])) then { _ok = false };
                    if (_ok && (_t getVariable ["CO_captureInProgress", false])) then { _ok = false };
                    if (_ok) then {
                        private _f = group _t getVariable ["CO_faction", ""];
                        if (_f in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) then { _ok = false };
                    };
                    if (_ok) then {
                        _ok = (isPlayer _t || side _t == civilian);
                    };
                    _ok
                };
                if (count _cands == 0) then { continue };

                private _sorted = [_cands, [], { _x distance2D _u }, "ASCEND"] call BIS_fnc_sortBy;
                private _target = _sorted select 0;

                _u setVariable ["CO_lastAggressionAt", time, false];

                [_u, _target] spawn {
                    params ["_u", "_t"];
                    if (isNull _u || isNull _t) exitWith {};

                    // Switch the unit into an aware/aggressive posture so it
                    // actually moves and faces the target (CARELESS units
                    // will not pursue even with doMove).
                    _u setBehaviour "AWARE";
                    _u setCombatMode "YELLOW";
                    _u enableAI "MOVE";
                    _u enableAI "PATH";
                    _u setUnitPos "UP";

                    private _deadline = time + 25;
                    while {
                        alive _u && alive _t &&
                        !captive _t &&
                        !(_t getVariable ["CO_knockedOut", false]) &&
                        time < _deadline &&
                        (vehicle _u == _u) &&
                        (vehicle _t == _t)
                    } do {
                        _u doMove (getPosATL _t);
                        if ((_u distance _t) < TCK_MELEE_RANGE) then {
                            [_u, _t] call co_main_fnc_applyMeleeHit;
                            sleep 1.0;
                        } else {
                            sleep 1.5;
                        };
                    };

                    // After knockout: try to summon transport
                    if (alive _t && (_t getVariable ["CO_knockedOut", false])) then {
                        _t setCaptive true;
                        [_u, _t] spawn co_main_fnc_dispatchCaptureTransport;
                    };
                };
            } forEach (units _grp);
        } forEach _groups;
    };
};
