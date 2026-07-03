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
// Every 3 s on the server, walk every group whose CO_faction is
// "CRN_ENF". Police have their own controller and are intentionally
// excluded so this failsafe cannot distract an officer mid-chase.
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

#define TCK_SCAN_RADIUS 60
#define TCK_MELEE_RANGE  3.0
#define TCK_TICK         3

diag_log "[CO] tckGlobalAggression: starting global failsafe loop (radius=60m, tick=3s).";

[] spawn {
    private _heartbeat = 0;
    while { true } do {
        sleep TCK_TICK;
        _heartbeat = _heartbeat + 1;
        if (_heartbeat % 20 == 0) then {
            private _grpCount = count (allGroups select {
                (_x getVariable ["CO_faction", ""]) == "CRN_ENF"
            });
            diag_log format ["[CO] tckGlobalAggression heartbeat: %1 eligible groups.", _grpCount];
        };

        private _groups = allGroups select {
            (_x getVariable ["CO_faction", ""]) == "CRN_ENF"
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
                if (_u getVariable ["CO_knockedOut", false]) then { continue };
                if (_u getVariable ["CO_vehicleChaseDriver", false]) then { continue };

                // Respect high-priority claims (capture-transport crews,
                // AWOL detain squads): those units belong to another
                // controller and must never be yanked — even by
                // retaliation, which bypasses the normal claim attempt.
                private _claim = _u getVariable ["CO_claim", []];
                if (
                    !(_claim isEqualTo []) &&
                    { (_claim select 2) > time && (_claim select 1) >= 60 }
                ) then { continue };

                // Retaliation FIRST, before the mounted skip (audit R2-7):
                // units shot at while sitting in a vehicle dismount and
                // return fire instead of staring through the windshield.
                // (Bus escort groups are skipped above — fn_busAgroLoop's
                // emergency dismount owns their under-fire response.)
                private _retUntil = _grp getVariable ["CO_retaliateUntil", 0];
                private _retTarget = _grp getVariable ["CO_retaliateTarget", objNull];
                if (
                    _retUntil > time &&
                    !isNull _retTarget &&
                    alive _retTarget &&
                    !captive _retTarget &&
                    (_u distance2D _retTarget) < 140
                ) then {
                    [_retTarget] call co_main_fnc_installNonLethalDamage;
                    if (vehicle _u != _u) then {
                        private _v = vehicle _u;
                        unassignVehicle _u;
                        _u action ["GetOut", _v];
                        doGetOut _u;
                        moveOut _u;
                    };
                    _u setBehaviour "COMBAT";
                    _u setCombatMode "RED";
                    _u enableAI "AUTOTARGET";
                    _u enableAI "TARGET";
                    _u reveal [_retTarget, 4];
                    _u doTarget _retTarget;
                    _u doFire _retTarget;
                    _u fireAtTarget [_retTarget, currentWeapon _u];
                    continue;
                };

                if (vehicle _u != _u) then { continue };  // skip mounted

                // TRAINING SAFE ZONE: units physically standing inside the
                // NWAF airfield (= training staff: drill instructor, minders,
                // gate guards, roving interior guards) MUST NOT auto-detain
                // anyone. The boot-camp script + perimeter sentinel own
                // engagement decisions in that area.
                if (!isNil "CO_airfieldCenter" &&
                    {(getPosATL _u) distance2D CO_airfieldCenter < (CO_airfieldRadius + 50)}) then {
                    continue
                };

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
                    // Cleared conscripts (deployed military) are off-limits
                    // unless they go AWOL.
                    if (_ok && (_t getVariable ["CO_isCleared", false]) &&
                        !(_t getVariable ["CO_isAWOL", false])) then { _ok = false };
                    // Targets inside the airfield safe zone are off-limits
                    // (training recruits).
                    if (_ok && !isNil "CO_airfieldCenter" &&
                        {(getPosATL _t) distance2D CO_airfieldCenter < (CO_airfieldRadius + 20)} &&
                        !(_t getVariable ["CO_isAWOL", false])) then { _ok = false };
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

                // Weighted pick (R1-g): players, hot suspects, and armed men
                // out-rank the nearest random NPC civilian, so patrols stop
                // being statistically blind to players in crowded towns.
                private _sorted = [_cands, [], {
                    private _score = _x distance2D _u;
                    if (isPlayer _x) then { _score = _score - 40 };
                    _score = _score - (((_x getVariable ["CO_heatLevel", 0]) * 0.5) min 40);
                    if (primaryWeapon _x != "" || handgunWeapon _x != "") then { _score = _score - 25 };
                    _score
                }, "ASCEND"] call BIS_fnc_sortBy;
                private _target = _sorted select 0;
                private _token = format ["tck_global_%1_%2", netId _u, floor (time * 10)];
                private _priority = 40;
                if (!([_u, _token, _priority, 45] call co_main_fnc_claimUnit)) then { continue };

                _u setVariable ["CO_lastAggressionAt", time, false];
                [_target, getPosATL _target, "tck_global", _priority] call co_main_fnc_alertPublish;

                [_u, _target, _token, _priority] spawn {
                    params ["_u", "_t", "_token", "_priority"];
                    if (isNull _u || isNull _t) exitWith {};

                    // Switch the unit into an aware/aggressive posture so it
                    // actually moves and faces the target (CARELESS units
                    // will not pursue even with doMove).
                    _u setBehaviour "AWARE";
                    _u setCombatMode "YELLOW";
                    _u enableAI "MOVE";
                    _u enableAI "PATH";
                    _u setUnitPos "UP";

                    private _deadline = time + 60;
                    private _captured = false;
                    while {
                        alive _u && alive _t &&
                        !captive _t &&
                        !(_t getVariable ["CO_knockedOut", false]) &&
                        time < _deadline &&
                        !_captured &&
                        (vehicle _u == _u) &&
                        (vehicle _t == _t) &&
                        { [_u, _token, _priority, 25] call co_main_fnc_claimUnit }
                    } do {
                        [[_u], _t] call co_main_fnc_chaseMove;
                        if ([[_u], _t] call co_main_fnc_proximityTackle) then {
                            if (isPlayer _t) then {
                                private _result = [_t, 20] call co_main_fnc_runWrangle;
                                if (_result == "captured") then {
                                    _t setCaptive true;
                                    // Kneel-and-load beat (this unit is at
                                    // tackle range).
                                    [_t, group _u] call co_main_fnc_detainSequence;
                                    _captured = true;
                                };
                                if (_result == "escaped") then {
                                    _t setVariable ["CO_tackleImmuneUntil", time + 6, true];
                                    sleep 2;
                                };
                            } else {
                                [_u, _t, 60, true] call co_main_fnc_applyKnockout;
                                if (_t getVariable ["CO_knockedOut", false]) then {
                                    _t setCaptive true;
                                    [_u, _t] spawn co_main_fnc_dispatchCaptureTransport;
                                    _captured = true;
                                };
                            };
                        };
                        sleep 0.7;
                    };

                    // After knockout: try to summon transport
                    if (alive _t && (_t getVariable ["CO_knockedOut", false])) then {
                        _t setCaptive true;
                        [_u, _t] spawn co_main_fnc_dispatchCaptureTransport;
                    };

                    [_u, _token] call co_main_fnc_releaseUnit;
                };
            } forEach (units _grp);
        } forEach _groups;
    };
};
