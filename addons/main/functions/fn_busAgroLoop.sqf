// ============================================================
// fn_busAgroLoop.sqf — server-side bus controller
//
// Why a script-driven controller?
//   The engine's "AWARE" behaviour combined with civilian-friend=1
//   relations makes AI drivers hesitate constantly: every civilian
//   in earshot registers as a "noise event" and the driver brakes
//   to look. Driver groups are therefore CARELESS/BLUE (see
//   fn_spawnBusOnRoute) and this loop owns ALL motion via doMove.
//
// State machine
// -------------
//   traveling   : drive route waypoints; scan for civilians
//   approaching : target spotted, drive toward them
//   dismounted  : bus stopped, escorts on foot hunting for civs
//   reboarding  : escorts ordered back, waiting up to 15s
//   delivering  : fn_transportToDetention owns the bus
//   abandoned   : no driver, controller exits
//
// Aggression model (the important bit)
// ------------------------------------
//   Civilians are setFriend 1 to west, so the engine will NEVER
//   make TCK shoot/punch them autonomously. Once dismounted, each
//   escort is given an individual scan: walk to nearest civ/player
//   within 25 m and melee them (3 punches = knockout, then load
//   into the bus). Long-range gunfire is intentionally avoided
//   for civilian targets — the gameplay spec calls for non-lethal
//   capture, and `fireAtTarget` on civilians caused player deaths
//   the moment the player picked up a weapon.
//
//   Targets become "hostile" only if they shoot back: when a TCK
//   unit's Killed/Hit handler trips, escorts switch to AWARE/RED
//   inside the engagement window — and even then their bullets
//   are filtered by fn_installNonLethalDamage so the player ends
//   up knocked out, not dead.
// ============================================================

params ["_veh", "_driverGrp", "_escortGrp"];

if (!isServer) exitWith {};
if (isNull _veh || isNull _driverGrp) exitWith {};

#define BUS_SCAN_RADIUS        260
#define BUS_DISMOUNT_RANGE      75
#define BUS_FOOT_SCAN_RADIUS    30
#define BUS_MELEE_RANGE          2.6
#define BUS_WP_REACHED_DIST     35
#define BUS_DOMOVE_INTERVAL      5
#define BUS_DISMOUNT_DURATION   60
#define BUS_REBOARD_TIMEOUT     15
#define BUS_STUCK_SPEED          1.8
#define BUS_STUCK_GRACE         10
#define BUS_IDLE_DISMOUNT_GRACE 20
#define BUS_APPROACH_TIMEOUT    90

private _aggroRadius = missionNamespace getVariable ["CO_bus_aggroRadius", BUS_SCAN_RADIUS];
private _maxCaptives = missionNamespace getVariable ["CO_bus_maxCaptives", 3];

private _routeWps = _veh getVariable ["CO_busRouteWps", []];
if (count _routeWps == 0) then { _routeWps = [getPosATL _veh] };

private _stuckSince     = -1;
private _lastDoMove     = 0;
private _huntTarget     = objNull;
private _huntUntil      = 0;
private _dismountUntil  = 0;
private _approachStarted = -1;
private _idleSince      = time;       // for forced-dismount-on-idle
private _lastIdlePos    = getPosATL _veh;

_veh setVariable ["CO_busState", "traveling", true];

// Make sure the engine is on and a couple of seconds of breathing room
// for the waypoint pathing to kick in before the controller starts
// observing motion. ARMA waypoints (added in fn_spawnBusOnRoute) drive
// the cruise; the controller only overrides via doMove during a hunt.
_veh engineOn true;
_veh forceSpeed -1;
sleep 2;

private _resumeRoute = {
    params ["_drvGrp", "_veh"];
    if (isNull _drvGrp) exitWith {};
    private _drv = driver _veh;
    if (isNull _drv || !alive _drv) exitWith {};
    _drv setBehaviour "SAFE";
    _drv setCombatMode "BLUE";
    _drv enableAI "MOVE";
    _drv enableAI "PATH";
    _drv enableAI "FSM";
    _drvGrp setBehaviour "SAFE";
    _drvGrp setCombatMode "BLUE";
    _drvGrp setSpeedMode "NORMAL";
    _veh engineOn true;
    _veh forceSpeed -1;
    // Snap focus back to the current waypoint so the engine resumes
    // routing after a doMove override.
    private _wpIdx = currentWaypoint _drvGrp;
    private _wpCount = count (waypoints _drvGrp);
    if (_wpCount > 0) then {
        _drvGrp setCurrentWaypoint [_drvGrp, _wpIdx min (_wpCount - 1)];
    };
};

diag_log format [
    "[CO] busAgroLoop online: veh=%1 route=%2wps wps=%3 spawnGrid=%4.",
    netId _veh, count _routeWps, count (waypoints _driverGrp), mapGridPosition _veh
];

// ---------------------------------------------------------------
// Helper: dismount one escort and have it actively hunt civilians
// in a small radius around the bus. Spawned as a sub-thread per
// escort so they hunt in parallel without blocking the main loop.
// ---------------------------------------------------------------
private _spawnEscortHunter = {
    params ["_u", "_bus", "_huntUntilTime"];
    [_u, _bus, _huntUntilTime] spawn {
        params ["_u", "_bus", "_huntUntilTime"];
        if (isNull _u || !alive _u) exitWith {};

        // Wait for the dismount to actually complete. If the previous
        // code path's GetOut animation is still in flight when this
        // sub-thread starts, vehicle _u != _u → the while loop below
        // immediately exits and the escort "stands around uselessly".
        // We block here up to 6 seconds, then bail if the unit really
        // never got out.
        private _dismountDeadline = time + 6;
        while {
            alive _u && (vehicle _u != _u) && time < _dismountDeadline
        } do { sleep 0.3 };
        if (alive _u && vehicle _u != _u) then {
            // Stubborn — force them out.
            moveOut _u;
            _u action ["Eject", vehicle _u];
            unassignVehicle _u;
            sleep 0.5;
        };
        if (vehicle _u != _u) exitWith {
            diag_log format ["[CO] busAgroLoop: escort %1 failed to dismount, abandoning hunt.", _u];
        };

        // Switch escort to hunting posture
        _u setBehaviour "AWARE";
        _u setCombatMode "YELLOW";
        _u enableAI "MOVE";
        _u enableAI "PATH";
        _u enableAI "AUTOTARGET";
        _u enableAI "TARGET";
        _u setUnitPos "UP";

        private _myTarget = objNull;
        private _myTargetUntil = 0;
        private _idleAt = -1;

        while {
            alive _u && alive _bus &&
            time < _huntUntilTime &&
            (vehicle _u == _u)
        } do {
            sleep 1.5;

            // Drop target if it died/got captured/knocked out
            if (!isNull _myTarget) then {
                if (!alive _myTarget ||
                    captive _myTarget ||
                    (_myTarget getVariable ["CO_knockedOut", false])) then {
                    _myTarget = objNull;
                };
            };

            // Acquire a target if we don't have one
            if (isNull _myTarget || time > _myTargetUntil) then {
                private _center = getPosATL _u;
                private _candidates = (_center nearEntities [["Man"], 28]) select {
                    private _t = _x;
                    private _ok = alive _t && vehicle _t == _t;
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
                if (count _candidates > 0) then {
                    _candidates = [_candidates, [], { _x distance2D _u }, "ASCEND"] call BIS_fnc_sortBy;
                    _myTarget = _candidates select 0;
                    _myTargetUntil = time + 30;
                    _idleAt = -1;
                };
            };

            if (!isNull _myTarget) then {
                // Chase: doMove every 3 s
                _u doMove (getPosATL _myTarget);
                private _d = _u distance _myTarget;

                if (_d < 3.5) then {
                    // Punch! applyMeleeHit handles cooldown, anim, dmg,
                    // and the third hit triggers applyKnockout.
                    [_u, _myTarget] call co_main_fnc_applyMeleeHit;

                    // If they got knocked out, mark them as a captive.
                    // For PLAYERS: dispatch a dedicated capture-transport
                    // truck (same as border patrol / SW fort / TCK aggro)
                    // — moveInCargo on a remote player's unit is fragile
                    // and dropping them into the bus also conflicts with
                    // the bus's continued patrol behaviour.
                    // For NPC civilians: load them into the bus and keep
                    // cruising until the bus is full → transport to detention.
                    if (_myTarget getVariable ["CO_knockedOut", false]) then {
                        _myTarget setCaptive true;
                        _myTarget setVariable ["CO_captureInProgress", false, true];
                        _myTarget setVariable ["CO_busLastCaptureTime", time, true];

                        if (isPlayer _myTarget) then {
                            // Wake them up — spawnCaptureTransport teleports
                            // them into the truck cab so they need to be
                            // conscious to ride.
                            _myTarget setUnconscious false;
                            _myTarget setVariable ["CO_knockedOut", false, true];
                            // Dispatch a dedicated capture truck with driver
                            // + jailer. The bus continues cruising and can
                            // capture more NPCs in the meantime.
                            [_myTarget, group _u] spawn co_main_fnc_spawnCaptureTransport;
                            diag_log format [
                                "[CO] Bus %1: player %2 knocked out → dedicated capture-transport dispatched.",
                                netId _bus, name _myTarget
                            ];
                            _myTarget = objNull;
                        } else {
                            // NPC: keep the bus-loading path
                            private _caps = _bus getVariable ["CO_busCaptives", []];
                            if !(_myTarget in _caps) then {
                                _caps pushBack _myTarget;
                                _bus setVariable ["CO_busCaptives", _caps, true];
                            };
                            if (alive _bus) then {
                                _myTarget setUnconscious false;
                                _myTarget setVariable ["CO_knockedOut", false, true];
                                _myTarget setPos (getPosATL _bus);
                                _myTarget assignAsCargo _bus;
                                _myTarget moveInCargo _bus;
                                private _loadOk = false;
                                for "_attempt" from 0 to 6 do {
                                    sleep 0.5;
                                    if (_myTarget in _bus) exitWith { _loadOk = true };
                                    _myTarget setUnconscious false;
                                    _myTarget setPos (getPosATL _bus);
                                    _myTarget assignAsCargo _bus;
                                    _myTarget moveInCargo _bus;
                                };
                                if (!_loadOk) then {
                                    diag_log format [
                                        "[CO] Bus %1: failed to load NPC captive %2 after retries.",
                                        netId _bus, name _myTarget
                                    ];
                                };
                                _bus lockCargo true;
                            };
                            _myTarget = objNull;
                        };
                    };
                };
            } else {
                // No target — wander a bit so escorts spread out instead
                // of clumping by the bus door.
                if (_idleAt < 0 || time > _idleAt) then {
                    private _wander = (getPosATL _bus) getPos [8 + random 22, random 360];
                    _u doMove _wander;
                    _idleAt = time + 8 + random 6;
                };
            };
        };
    };
};

// ---------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------
while { alive _veh } do {
    sleep 3;
    if (!alive _veh) exitWith {};

    private _state  = _veh getVariable ["CO_busState", "traveling"];
    if (_state in ["delivering","abandoned"]) then { continue };
    // Defensive: legacy code paths set state to "cruising" after a
    // delivery. Treat it as a synonym for "traveling" so this loop
    // doesn't drop the bus into a do-nothing state. (The proper post-
    // delivery handover in fn_transportToDetention now sets "traveling"
    // directly, but old saves / racing state changes can still leave
    // this value behind.)
    if (_state == "cruising") then {
        _veh setVariable ["CO_busState", "traveling", true];
        _state = "traveling";
    };

    // ---- Driver replacement / abandon detection -----------------------
    private _driver = driver _veh;
    if (isNull _driver || !alive _driver) then {
        private _alts = (units _driverGrp) + (units _escortGrp);
        _alts = _alts select { alive _x && _x != driver _veh };
        if (count _alts > 0) then {
            private _new = _alts select 0;
            _new moveInDriver _veh;
            _new setBehaviour "SAFE";
            _new setCombatMode "BLUE";
            _new disableAI "AUTOTARGET";
            _new disableAI "TARGET";
            _driver = driver _veh;
            _lastDoMove = 0;
            diag_log format ["[CO] Bus %1 driver swapped.", netId _veh];
        };
    };
    if (isNull driver _veh) then {
        diag_log format ["[CO] Bus %1 abandoned (no driver).", netId _veh];
        _veh setVariable ["CO_busState", "abandoned", true];
        // Release the escort group so fn_tckGlobalAggression takes them
        // over and they don't just stand around when the truck dies.
        _escortGrp setVariable ["CO_isBusEscortGrp", false, true];
        // Make sure surviving escorts can actually fight back: enable
        // their combat AI and put them into AWARE/YELLOW.
        {
            if (alive _x) then {
                _x enableAI "AUTOTARGET";
                _x enableAI "TARGET";
                _x enableAI "AUTOCOMBAT";
                _x enableAI "SUPPRESSION";
                _x enableAI "COVER";
                _x setBehaviour "AWARE";
                _x setCombatMode "YELLOW";
                if (vehicle _x == _veh) then { unassignVehicle _x; moveOut _x };
            };
        } forEach (units _escortGrp);
        continue;
    };
    _driver = driver _veh;

    // ---- Captive cap reached → idle (delivery scheduler picks up) -----
    private _aboard = (_veh getVariable ["CO_busCaptives", []]) select {
        !isNull _x && alive _x && captive _x
    };
    _veh setVariable ["CO_busCaptives", _aboard, true];
    if (count _aboard >= _maxCaptives) then { continue };

    // ====================================================================
    // GLOBAL IDLE-DISMOUNT TRIGGER
    // Per user spec (round 9): truck stationary for 20s → EVERY escort
    // dismounts and chases nearby civs/players on foot. Previous
    // position-delta detection reset on tiny AI drift (brake/restart
    // cycles) and the 2-escort cap left the truck doing nothing while
    // half-full. Now uses speed-based detection (bus actually below
    // walking pace) and dumps the whole escort squad.
    // ====================================================================
    if (_state in ["traveling", "approaching"]) then {
        if ((speed _veh) >= BUS_STUCK_SPEED) then {
            _idleSince = time;
            _lastIdlePos = getPosATL _veh;
        };
        if ((time - _idleSince) > BUS_IDLE_DISMOUNT_GRACE) then {
            diag_log format [
                "[CO] Bus %1 idle %2s in state '%3' (speed=%4) — FULL escort dismount.",
                netId _veh, round (time - _idleSince), _state, round (speed _veh)
            ];
            _veh setVariable ["CO_busState", "dismounted", true];
            _state = "dismounted";
            _dismountUntil = time + BUS_DISMOUNT_DURATION;
            _approachStarted = -1;
            if (!isNull _driver && alive _driver) then { doStop _driver };
            _veh forceSpeed 0;
            _escortGrp setBehaviour "AWARE";
            _escortGrp setCombatMode "YELLOW";
            _escortGrp setSpeedMode "FULL";

            private _dismountCount = 0;
            {
                // Dismount EVERY mounted escort — no cap.
                if (alive _x && vehicle _x == _veh) then {
                    _x allowGetIn false;
                    unassignVehicle _x;
                    _x action ["GetOut", _veh];
                    doGetOut _x;
                    [_x, _veh, _dismountUntil] spawn {
                        params ["_u", "_v", "_until"];
                        sleep 1.2;
                        if (alive _u && vehicle _u == _v) then {
                            moveOut _u;
                            if (vehicle _u == _v) then {
                                _u setPosATL ((getPosATL _v) vectorAdd [
                                    (random 6) - 3, (random 6) - 3, 0
                                ]);
                            };
                        };
                    };
                    [_x, _veh, _dismountUntil] call _spawnEscortHunter;
                    _dismountCount = _dismountCount + 1;
                };
            } forEach (units _escortGrp);
            diag_log format [
                "[CO] Bus %1 idle-dispatched %2 escort hunters (full dump).",
                netId _veh, _dismountCount
            ];
            _idleSince = time;
            _lastIdlePos = getPosATL _veh;
        };
    };

    // ====================================================================
    // STATE: dismounted — escort hunters do the work in sub-threads
    // ====================================================================
    if (_state == "dismounted") then {
        if (time >= _dismountUntil) then {
            // Reboard
            _veh setVariable ["CO_busState", "reboarding", true];
            // Calm the escort group so reboard doesn't get sidetracked
            _escortGrp setBehaviour "SAFE";
            _escortGrp setCombatMode "BLUE";
            {
                if (alive _x && vehicle _x == _x) then {
                    _x setBehaviour "SAFE";
                    _x setCombatMode "BLUE";
                    _x allowGetIn true;
                    _x assignAsCargo _veh;
                    [_x] orderGetIn true;
                    _x doMove (getPosATL _veh);
                };
            } forEach (units _escortGrp);

            private _reboardEnd = time + BUS_REBOARD_TIMEOUT;
            waitUntil {
                sleep 0.8;
                !alive _veh ||
                ({ alive _x && vehicle _x == _x } count (units _escortGrp)) == 0 ||
                time > _reboardEnd
            };

            // Force-board any stragglers
            {
                if (alive _x && vehicle _x == _x) then {
                    _x moveInCargo _veh;
                };
            } forEach (units _escortGrp);

            if (alive _veh) then {
                // If we picked up captives this stop, hand off to
                // fn_transportToDetention. The earlier complex driver-
                // group / leader-in-bus guard was too strict and
                // silently swallowed delivery whenever the dismount
                // captured the player but the bus driver had been
                // swapped or the escort leader was still walking back.
                private _threshold = missionNamespace getVariable ["CO_busDetentionThreshold", 1];
                private _liveCaps = (_veh getVariable ["CO_busCaptives", []]) select {
                    !isNull _x && alive _x && captive _x && (_x in _veh)
                };
                _veh setVariable ["CO_busCaptives", _liveCaps, true];

                if (count _liveCaps >= _threshold) then {
                    // Make sure a driver is in the seat before handoff.
                    private _driverNow = driver _veh;
                    if (isNull _driverNow || !alive _driverNow) then {
                        private _alts = (units _driverGrp) + (units _escortGrp);
                        _alts = _alts select { alive _x };
                        if (count _alts > 0) then {
                            (_alts select 0) moveInDriver _veh;
                        };
                    };
                    _veh setVariable ["CO_transportVehicle", _veh, true];
                    _escortGrp setVariable ["CO_transportVehicle", _veh, true];
                    [_liveCaps select 0, _escortGrp] spawn co_main_fnc_transportToDetention;
                };

                _veh setVariable ["CO_busState", "traveling", true];
                _huntTarget = objNull;
                _lastDoMove = 0;
                _idleSince = time;
                _lastIdlePos = getPosATL _veh;
                [_driverGrp, _veh] call _resumeRoute;
            };
        };
        continue;
    };

    if (_state == "reboarding") then { continue };

    // ====================================================================
    // SCAN for nearby civilians/players from the bus point
    // ====================================================================
    private _scanCenter = getPosATL _veh;
    private _scanFoot = (_scanCenter nearEntities [["Man"], _aggroRadius]) select {
        private _t = _x;
        private _ok = alive _t && vehicle _t == _t;
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

    // Also detect players inside civilian-driven vehicles (cars/bikes) so the
    // bus pulls them over instead of cruising past.
    private _scanVehDrivers = (_scanCenter nearEntities [["LandVehicle"], _aggroRadius]) select {
        private _v = _x;
        alive _v &&
        !(_v getVariable ["CO_isBusPatrol", false]) &&
        !(_v getVariable ["CO_isCaptureTransport", false]) && {
            private _d = driver _v;
            !isNull _d && alive _d &&
            (isPlayer _d || side _d == civilian) &&
            !captive _d &&
            !(_d getVariable ["CO_knockedOut", false]) &&
            !(_d getVariable ["CO_captureInProgress", false])
        }
    };
    private _scan = _scanFoot;
    if (count _scanVehDrivers > 0) then {
        _scan = _scan + (_scanVehDrivers apply { driver _x });
    };

    // Pick nearest target
    private _bestTarget = objNull;
    if (count _scan > 0) then {
        private _sorted = [_scan, [], { _x distance2D _veh }, "ASCEND"] call BIS_fnc_sortBy;
        _bestTarget = _sorted select 0;
    };

    // ====================================================================
    // STATE: approaching — drive toward target until close enough to dismount
    // ====================================================================
    if (_state == "approaching") then {
        if (isNull _huntTarget || !alive _huntTarget ||
            captive _huntTarget ||
            (_huntTarget getVariable ["CO_knockedOut", false]) ||
            time > _huntUntil) then {
            _huntTarget = objNull;
            _veh setVariable ["CO_busState", "traveling", true];
            _state = "traveling";
            _approachStarted = -1;
            _lastDoMove = 0;
            [_driverGrp, _veh] call _resumeRoute;
        } else {
            if (_approachStarted < 0) then { _approachStarted = time };

            // Force-keep the driver in a state that will actually drive.
            // disableAI on FSM/PATH would deadlock pursuit, so keep them ON.
            _driver setBehaviour "SAFE";
            _driver setCombatMode "BLUE";
            _driver enableAI "MOVE";
            _driver enableAI "PATH";
            _driver enableAI "FSM";
            _driver disableAI "AUTOTARGET";
            _driver disableAI "TARGET";
            _driverGrp setSpeedMode "FULL";

            if ((time - _lastDoMove) > 4) then {
                private _tgtPos = getPosATL _huntTarget;
                private _vel = velocity _huntTarget;
                if !(_vel isEqualTo [0,0,0]) then {
                    _tgtPos = _tgtPos vectorAdd (_vel vectorMultiply 3);
                };
                _veh engineOn true;
                // doMove on the vehicle itself is the engine-supported
                // path for AI-driven vehicles (more reliable than
                // doMove on the driver unit, which the engine routes
                // through the same logic but can swallow on first tick
                // after a state change).
                _veh doMove _tgtPos;
                _driver doMove _tgtPos;
                _veh forceSpeed -1;
                _lastDoMove = time;
            };

            private _approachStuckTooLong = (time - _approachStarted) > BUS_APPROACH_TIMEOUT;

            if ((_veh distance2D _huntTarget) < BUS_DISMOUNT_RANGE || _approachStuckTooLong) then {
                // Drop into dismounted state and spin up the escort hunters
                _veh setVariable ["CO_busState", "dismounted", true];
                _state = "dismounted";
                _dismountUntil = time + BUS_DISMOUNT_DURATION;
                _approachStarted = -1;
                doStop _driver;
                _veh forceSpeed 0;

                // Flip the escort group's behaviour for the hunt
                _escortGrp setBehaviour "AWARE";
                _escortGrp setCombatMode "YELLOW";
                _escortGrp setSpeedMode "FULL";

                diag_log format [
                    "[CO] Bus %1 DISMOUNTING at %2 (target %3m, forced=%4).",
                    netId _veh, mapGridPosition _veh,
                    round (_veh distance2D _huntTarget),
                    _approachStuckTooLong
                ];

                private _dismountCount = 0;
                {
                    if (alive _x && vehicle _x == _veh) then {
                        _x allowGetIn false;
                        unassignVehicle _x;
                        _x action ["GetOut", _veh];
                        doGetOut _x;
                        // Force teleport just outside the truck so the
                        // engine can't keep them strapped in if the
                        // GetOut animation gets cancelled.
                        [_x, _veh, _dismountUntil] spawn {
                            params ["_u", "_v", "_until"];
                            sleep 1.2;
                            if (alive _u && vehicle _u == _v) then {
                                moveOut _u;
                                if (vehicle _u == _v) then {
                                    _u setPosATL ((getPosATL _v) vectorAdd [
                                        (random 6) - 3, (random 6) - 3, 0
                                    ]);
                                };
                            };
                        };
                        [_x, _veh, _dismountUntil] call _spawnEscortHunter;
                        _dismountCount = _dismountCount + 1;
                    };
                } forEach (units _escortGrp);

                diag_log format [
                    "[CO] Bus %1 dispatched %2 escort hunters.",
                    netId _veh, _dismountCount
                ];
            };
        };
    };

    // ====================================================================
    // STATE: traveling — engine waypoints drive the cruise. We only watch
    // for targets to acquire and do stuck recovery as a safety net.
    // ====================================================================
    if (_state == "traveling") then {
        // Acquire target?
        if (!isNull _bestTarget) then {
            _huntTarget = _bestTarget;
            _huntUntil  = time + 90;
            _veh setVariable ["CO_busState", "approaching", true];
            _state = "approaching";
            _lastDoMove = 0;
            _approachStarted = time;
            diag_log format [
                "[CO] Bus %1 hunting %2 at %3m.",
                netId _veh,
                if (isPlayer _bestTarget) then { name _bestTarget } else { typeOf _bestTarget },
                round (_veh distance2D _bestTarget)
            ];
        } else {
            // Keep engine on + speed unforced so engine waypoints handle motion.
            if (!isEngineOn _veh) then { _veh engineOn true };

            // Cruise watchdog: even when not stuck "too long" yet, if
            // the truck has nothing currently happening and isn't
            // moving, re-issue a doMove to the next waypoint so the
            // engine can't sit on a stale path. Cheap and idempotent.
            if ((speed _veh) < BUS_STUCK_SPEED) then {
                private _wps = waypoints _driverGrp;
                if (count _wps > 0) then {
                    private _idx = currentWaypoint _driverGrp;
                    if (_idx >= count _wps) then { _idx = 0 };
                    private _wpPos = waypointPosition [_driverGrp, _idx];
                    if !(_wpPos isEqualTo [0,0,0]) then {
                        _driverGrp setCurrentWaypoint [_driverGrp, _idx];
                        _veh doMove _wpPos;
                    };
                };
            };

            // Stuck recovery: if the engine waypoints are failing to make
            // progress, snap to a nearby road and force a fresh waypoint
            // focus.
            if ((speed _veh) < BUS_STUCK_SPEED) then {
                if (_stuckSince < 0) then { _stuckSince = time };
                if ((time - _stuckSince) > BUS_STUCK_GRACE) then {
                    diag_log format [
                        "[CO] Bus %1 stuck %2s at %3 (wp=%4/%5) — relocating.",
                        netId _veh, round (time - _stuckSince), mapGridPosition _veh,
                        currentWaypoint _driverGrp, count (waypoints _driverGrp)
                    ];
                    private _rds = (getPosATL _veh) nearRoads 200;
                    if (count _rds > 0) then {
                        private _r = selectRandom _rds;
                        _veh setPos ((getPos _r) vectorAdd [0,0,0.3]);
                        _veh setVectorUp [0,0,1];
                    };
                    _veh engineOn true;
                    [_driverGrp, _veh] call _resumeRoute;
                    _stuckSince = time;
                };
            } else {
                _stuckSince = -1;
            };
        };
    };
};

diag_log format ["[CO] busAgroLoop exit veh=%1.", netId _veh];

// On exit (vehicle dead), release escort group so global aggression
// picks the surviving escorts up. Also re-enable their combat AI in case
// they were dismounted with reduced posture, and dump them out of the
// wreck so they can actually fight.
if (!isNull _escortGrp) then {
    _escortGrp setVariable ["CO_isBusEscortGrp", false, true];
    _escortGrp setBehaviour "AWARE";
    _escortGrp setCombatMode "YELLOW";
    {
        if (alive _x) then {
            _x enableAI "AUTOTARGET";
            _x enableAI "TARGET";
            _x enableAI "AUTOCOMBAT";
            _x enableAI "SUPPRESSION";
            _x enableAI "COVER";
            _x setBehaviour "AWARE";
            _x setCombatMode "YELLOW";
            if (!isNull _veh && vehicle _x == _veh) then {
                unassignVehicle _x;
                moveOut _x;
            };
        };
    } forEach (units _escortGrp);
};
if (!isNull _driverGrp) then {
    _driverGrp setVariable ["CO_isBusDriverGrp", false, true];
    {
        if (alive _x) then {
            _x enableAI "AUTOTARGET";
            _x enableAI "TARGET";
            _x enableAI "AUTOCOMBAT";
            _x enableAI "FSM";
            _x setBehaviour "AWARE";
            _x setCombatMode "YELLOW";
            if (!isNull _veh && vehicle _x == _veh) then {
                unassignVehicle _x;
                moveOut _x;
            };
        };
    } forEach (units _driverGrp);
};
