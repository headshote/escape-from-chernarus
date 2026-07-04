// ============================================================
// fn_spawnCaptureTransport.sqf
//
// On-demand transport that picks up a captive and ships them to
// the NWAF training camp. Used by police, checkpoints, TCK, the
// border, and the AWOL detain flow.
//
// Rebuilt after the "truck refuses to drive / teleports all over
// Chernogorsk with me inside" playtest. Root causes fixed:
//
//   1. DEDICATED CREW. The old version borrowed the driver from
//      the CAPTURING group — whose own controller (bus agro loop,
//      chase claims) kept issuing it orders, up to and including
//      moveInCargo'ing the "driver" back into its TCK truck mid-
//      route, and the transport waypoint was written onto the
//      donor group, corrupting its patrol. The crew is now spawned
//      fresh in its own group and claimed at priority 90 so no
//      other controller can touch it.
//
//   2. NO TELEPORT RECOVERY. The old stuck-watchdog setPos'd the
//      van (with the player inside) to a nearby road every 20 s.
//      New ladder: re-issue route → reverse out → after the third
//      failure, ONE clean fallback: deliver the captive directly
//      to training (the same accepted behavior as a flipped or
//      destroyed van) and despawn the vehicle.
//
//   3. EXPLICIT OUTCOMES. The drive loop resolves to exactly one
//      of: arrived / escaped (breakout minigame or any other way
//      out of the vehicle) / rescued (crew killed) / failsafe
//      (dead, flipped, stuck, timeout) / dead. Escaping clears
//      the transport state (no more permanent "DETAINED — IN
//      TRANSPORT"), adds wanted, and the crew gives chase.
//
//   4. LOCKED CARGO + BREAKOUT. The captive rides in the locked
//      cargo compartment; the only intended way out mid-route is
//      the "Force the cargo latch" self-action (lockpick-style
//      minigame, fn_breakoutMinigame → CO_breakoutAt).
//
// Params:
//   _captive       - the man to transport
//   _capturingGrp  - kept for API compatibility (logging only —
//                    the crew is no longer taken from it)
// ============================================================

params [
    ["_captive", objNull, [objNull]],
    ["_capturingGrp", grpNull, [grpNull]]
];

if (!isServer) exitWith {
    [_captive, _capturingGrp] remoteExec ["co_main_fnc_spawnCaptureTransport", 2];
};

if (isNull _captive || !alive _captive) exitWith {};
if (_captive getVariable ["CO_transportInProgress", false]) exitWith {};

_captive setVariable ["CO_transportInProgress", true, true];
_captive setCaptive true;

[_captive, _capturingGrp] spawn {
    params ["_captive", "_capturingGrp"];

    // ---- 1. Destination = NWAF training field -----------------
    if (isNil "CO_trainingFieldPos") then {
        CO_trainingFieldPos = [2160, 12800, 0];
    };
    private _dest = +CO_trainingFieldPos;

    // Shared: hand the captive to the training camp directly. This is
    // the ACCEPTED fallback (same as the long-standing flipped-truck
    // behavior): dismount + teleport + trainingPhase.
    private _deliverDirect = {
        if (alive _captive) then {
            if (!isNull (objectParent _captive)) then { moveOut _captive };
            _captive setPosATL (_dest vectorAdd [4 + random 4, random 8 - 4, 0]);
            _captive setUnconscious false;
            _captive setVariable ["CO_knockedOut", false, true];
            _captive setVariable ["CO_captureInProgress", false, true];
            _captive setVariable ["CO_transportInProgress", false, true];
            _captive setCaptive true;   // stays a conscript
            [_captive] call co_main_fnc_trainingPhase;
        } else {
            _captive setVariable ["CO_transportInProgress", false, true];
        };
    };

    // ---- 2. Find a road spawn position near the captive -------
    private _captivePos = getPosATL _captive;
    private _spawnPos   = [];
    private _radius     = 100;
    while { _spawnPos isEqualTo [] && _radius <= 600 } do {
        private _roads = _captivePos nearRoads _radius;
        private _candidates = _roads select {
            !isNull _x &&
            isOnRoad (getPos _x) &&
            (getPos _x) distance2D _captive > 18 &&
            (count ((getPos _x) nearEntities [["Car","Truck","Tank"], 14])) == 0
        };
        if (count _candidates > 0) then {
            private _tries = _candidates call BIS_fnc_arrayShuffle;
            if (count _tries > 14) then { _tries resize 14 };
            {
                private _p = getPos _x;
                private _empty = _p findEmptyPosition [0, 6, "C_Van_01_transport_F"];
                if (!(_empty isEqualTo []) && (_empty distance2D _captive) > 18) exitWith {
                    _spawnPos = _empty;
                };
            } forEach _tries;
        };
        if (_spawnPos isEqualTo []) then { _radius = _radius + 80 };
    };

    if (_spawnPos isEqualTo []) exitWith {
        diag_log format [
            "[CO] spawnCaptureTransport: no road near captive at %1 — direct delivery.",
            mapGridPosition _captive
        ];
        call _deliverDirect;
    };

    // ---- 3. Create the transport ------------------------------
    private _vehClass = "C_Van_01_transport_F";
    private _veh = createVehicle [_vehClass, _spawnPos, [], 0, "NONE"];
    _veh allowDamage false;
    _veh setPosATL [_spawnPos select 0, _spawnPos select 1, 0.15];
    _veh setVectorUp [0, 0, 1];
    _veh setVelocity [0, 0, 0];
    private _dx = (_dest select 0) - (_spawnPos select 0);
    private _dy = (_dest select 1) - (_spawnPos select 1);
    _veh setDir (_dx atan2 _dy);
    _veh setVariable ["CO_isCaptureTransport", true, true];
    [_veh] spawn { params ["_v"]; sleep 8; if (!isNull _v && alive _v) then { _v allowDamage true } };

    // ---- 4. DEDICATED crew: fresh group, claimed at 90 --------
    private _crewGrp = createGroup [west, true];
    _crewGrp setVariable ["CO_faction", "CRN_ENF", true];
    _crewGrp setVariable ["CO_isTransportCrew", true, true];

    private _token = format ["transport_%1", netId _veh];
    private _mkCrew = {
        params ["_pos", "_grp", "_token"];
        private _u = _grp createUnit ["B_Soldier_F", _pos, [], 0, "NONE"];
        if (isNull _u) exitWith { objNull };
        [_u] call co_main_fnc_initHostileUnit;
        // CARELESS so the driver actually cruises to NWAF at road speed
        // instead of the SAFE crawl (SAFE brakes for every civilian noise
        // and caps the van at walking pace). AUTOTARGET/TARGET stay off so
        // he never stops to fight — this is a prisoner run, not a patrol.
        _u setBehaviour "CARELESS";
        _u setCombatMode "BLUE";
        _u disableAI "AUTOTARGET";
        _u disableAI "TARGET";
        _u allowFleeing 0;
        [_u, _token, 90, 120] call co_main_fnc_claimUnit;
        _u
    };

    // CRITICAL: never let a CREWLESS van drive off. createGroup returns
    // grpNull once the engine's per-side group cap is reached (which is
    // why later captures — not just the first — produced an empty van
    // that instantly resolved to "rescued: your escort is dead, you're
    // free"). Scrap the van and fall back to the accepted direct delivery
    // whenever the driver can't be created/seated.
    private _bailCrewFail = {
        diag_log format [
            "[CO] Capture transport: crew spawn FAILED (grp=%1) — direct delivery.", _crewGrp
        ];
        { if (!isNull _x) then { deleteVehicle _x } } forEach (units _crewGrp);
        if (!isNull _veh) then { deleteVehicle _veh };
        if (!isNull _crewGrp) then { deleteGroup _crewGrp };
        call _deliverDirect;
    };

    private _driverUnit = [_spawnPos, _crewGrp, _token] call _mkCrew;
    if (isNull _crewGrp || isNull _driverUnit || !alive _driverUnit) exitWith { call _bailCrewFail };
    _driverUnit setVariable ["CO_vehicleChaseDriver", true, true];
    _driverUnit moveInDriver _veh;
    _crewGrp selectLeader _driverUnit;
    if (driver _veh != _driverUnit) exitWith { call _bailCrewFail };

    private _jailerUnit = [_spawnPos, _crewGrp, _token] call _mkCrew;
    if (!isNull _jailerUnit) then {
        _jailerUnit setVariable ["CO_isJailer", true, true];
        _jailerUnit assignAsCargo _veh;
        _jailerUnit moveInCargo _veh;
    };

    // Drive the whole crew as a fast, non-hesitant convoy.
    _crewGrp setBehaviour "CARELESS";
    _crewGrp setCombatMode "BLUE";
    _crewGrp setSpeedMode "FULL";

    diag_log format [
        "[CO] Capture transport %1 spawned at %2 for %3 (dedicated crew, dest NWAF).",
        _vehClass, mapGridPosition _veh, name _captive
    ];

    // ---- 5. FORCE-LOAD the captive into the locked cargo ------
    if (_captive getVariable ["CO_knockedOut", false]) then {
        _captive setUnconscious false;
        _captive setVariable ["CO_knockedOut", false, true];
        _captive setVariable ["CO_knockedOutUntil", time, true];
    };
    _captive setCaptive true;
    _captive setPos (getPosATL _veh);
    _captive assignAsCargo _veh;
    _captive moveInCargo _veh;
    if (isPlayer _captive) then {
        [_captive, _veh] remoteExec ["moveInCargo", _captive];
    };

    private _loadOk = false;
    for "_attempt" from 0 to 6 do {
        sleep 0.5;
        if (_captive in _veh) exitWith { _loadOk = true };
        _captive setUnconscious false;
        _captive setVariable ["CO_knockedOut", false, true];
        _captive setPos (getPosATL _veh);
        _captive assignAsCargo _veh;
        _captive moveInCargo _veh;
        if (isPlayer _captive) then {
            [_captive, _veh] remoteExec ["moveInCargo", _captive];
        };
    };
    if (!_loadOk && !(_captive in _veh)) exitWith {
        diag_log format [
            "[CO] Capture transport: could not seat %1 — direct delivery.",
            name _captive
        ];
        { deleteVehicle _x } forEach (units _crewGrp);
        deleteVehicle _veh;
        deleteGroup _crewGrp;
        call _deliverDirect;
    };

    _captive setCaptive true;
    _captive setVariable ["CO_detainPhase", "transport", true];
    _captive setVariable ["CO_breakoutAt", -1, true];
    _veh lockCargo true;
    _veh setVariable ["CO_busCaptives", [_captive], true];

    if (isPlayer _captive) then {
        [_captive] remoteExecCall ["co_main_fnc_showDetentionHUD", _captive];
        ["You are locked in the cargo hold. There may be a way to force the latch..."] remoteExecCall ["systemChat", _captive];
    };

    // ---- 6. Drive to training camp ------------------------------
    { deleteWaypoint _x } forEach +waypoints _crewGrp;
    private _wp = _crewGrp addWaypoint [_dest, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";
    _wp setWaypointBehaviour "CARELESS";
    _wp setWaypointCombatMode "BLUE";
    _wp setWaypointCompletionRadius 30;
    _crewGrp setCurrentWaypoint _wp;

    _veh engineOn true;
    _veh setFuel 1;
    _veh forceSpeed -1;
    _veh limitSpeed 200;
    sleep 0.5;
    _driverUnit doMove _dest;

    // ---- 7. Drive loop with explicit outcomes -------------------
    private _tripStart = time;
    private _result = "";
    private _lastPos = getPosATL _veh;
    private _lastCheck = time;
    private _stuckFails = 0;
    private _flipSince = -1;
    private _ejectFails = 0;

    while { _result == "" } do {
        sleep 2;

        // Keep the crew claimed so no controller steals them.
        {
            if (alive _x) then { [_x, _token, 90, 120] call co_main_fnc_claimUnit };
        } forEach (units _crewGrp);

        if (!alive _captive) then { _result = "dead" };

        if (_result == "" && !alive _veh) then { _result = "failsafe" };

        // Crew casualties: promote the jailer; all dead = the captive
        // was rescued by force.
        if (_result == "") then {
            private _drvNow = driver _veh;
            if (isNull _drvNow || !alive _drvNow) then {
                private _crewAlive = (units _crewGrp) select { alive _x };
                if (_crewAlive isEqualTo []) then {
                    _result = "rescued";
                } else {
                    private _promote = _crewAlive select 0;
                    if (vehicle _promote != _promote && vehicle _promote != _veh) then { moveOut _promote };
                    _promote moveInDriver _veh;
                    _promote setVariable ["CO_vehicleChaseDriver", true, true];
                    _crewGrp setCurrentWaypoint _wp;
                    _promote doMove _dest;
                    diag_log format ["[CO] Capture transport %1: driver replaced.", netId _veh];
                };
            };
        };

        // Flipped for > 5 s → accepted dismount-and-teleport flow.
        if (_result == "") then {
            if (((vectorUp _veh) select 2) < 0.35) then {
                if (_flipSince < 0) then { _flipSince = time };
                if ((time - _flipSince) > 5) then {
                    diag_log format ["[CO] Capture transport %1 flipped — direct delivery.", netId _veh];
                    _result = "failsafe";
                };
            } else {
                _flipSince = -1;
            };
        };

        // The breakout minigame is the ONLY sanctioned mid-route exit.
        if (_result == "" && (_captive getVariable ["CO_breakoutAt", -1]) > _tripStart) then {
            _result = "escaped";
        };
        // Cargo is locked, so an UNEXPLAINED exit (physics ejection from a
        // stalled/jerking van, a knockout state clearing, or a server-side
        // locality desync of `in`) is NOT an escape — the pre-rewrite flow
        // always still delivered the conscript to training. Treating it as
        // an escape freed the player on the road and never teleported them
        // to the camp. Re-seat them; if that keeps failing, fall back to
        // direct delivery rather than dead-ending the pipeline.
        if (_result == "" && alive _captive && !(_captive in _veh)) then {
            _ejectFails = _ejectFails + 1;
            if (_ejectFails >= 3) then {
                diag_log format [
                    "[CO] Capture transport %1: captive out of van without breakout — direct delivery.",
                    netId _veh
                ];
                _result = "failsafe";
            } else {
                _captive setUnconscious false;
                _captive setVariable ["CO_knockedOut", false, true];
                _captive setPos (getPosATL _veh);
                _captive assignAsCargo _veh;
                _captive moveInCargo _veh;
                if (isPlayer _captive) then {
                    [_captive, _veh] remoteExec ["moveInCargo", _captive];
                };
            };
        } else {
            if (_captive in _veh) then { _ejectFails = 0 };
        };

        if (_result == "" && (_veh distance2D _dest) < 45) then { _result = "arrived" };
        if (_result == "" && time > (_tripStart + 600)) then {
            diag_log format ["[CO] Capture transport %1 trip timeout — direct delivery.", netId _veh];
            _result = "failsafe";
        };

        // Stuck ladder — NEVER teleports the vehicle.
        if (_result == "" && (time - _lastCheck) > 20) then {
            if ((getPosATL _veh) distance _lastPos < 6) then {
                _stuckFails = _stuckFails + 1;
                switch (_stuckFails) do {
                    case 1: {
                        diag_log format ["[CO] Capture transport %1 stuck (1) — re-issuing route.", netId _veh];
                        _veh engineOn true;
                        _veh forceSpeed -1;
                        _crewGrp setCurrentWaypoint _wp;
                        (driver _veh) doMove _dest;
                    };
                    case 2: {
                        diag_log format ["[CO] Capture transport %1 stuck (2) — reversing out.", netId _veh];
                        private _back = (getPosATL _veh) getPos [25, (getDir _veh) + 180];
                        _veh doMove _back;
                        (driver _veh) doMove _back;
                    };
                    default {
                        diag_log format ["[CO] Capture transport %1 stuck (3) — direct delivery fallback.", netId _veh];
                        _result = "failsafe";
                    };
                };
            } else {
                _stuckFails = 0;
            };
            _lastPos = getPosATL _veh;
            _lastCheck = time;
        };
    };

    // ---- 8. Resolve the outcome ---------------------------------
    private _releaseCrew = {
        {
            [_x, _token] call co_main_fnc_releaseUnit;
        } forEach (units _crewGrp);
    };
    private _despawnCrewAndVan = {
        // Delete once no player is close enough to watch it pop
        // (3 attempts, then delete regardless).
        [_veh, _crewGrp] spawn {
            params ["_v", "_g"];
            for "_i" from 1 to 3 do {
                sleep 40;
                private _watched = allPlayers findIf { alive _x && _x distance2D _v < 160 } >= 0;
                if (!_watched) exitWith {};
            };
            { if (!isNull _x) then { deleteVehicle _x } } forEach (units _g);
            if (!isNull _v) then { deleteVehicle _v };
            if (!isNull _g) then { deleteGroup _g };
        };
    };

    switch (_result) do {

        case "arrived": {
            _veh forceSpeed 0;
            if (!isNull (driver _veh)) then { doStop (driver _veh) };
            sleep 1;
            _veh lockCargo false;

            if (alive _captive) then {
                if (_captive in _veh) then {
                    unassignVehicle _captive;
                    _captive action ["GetOut", _veh];
                    sleep 0.5;
                    if (_captive in _veh) then { moveOut _captive };
                };
                _captive setPosATL (_dest vectorAdd [4 + random 4, random 8 - 4, 0]);
                _captive setUnconscious false;
                _captive setVariable ["CO_knockedOut", false, true];
                _captive setVariable ["CO_captureInProgress", false, true];
                _captive setCaptive true;
                _captive setVariable ["CO_transportInProgress", false, true];
                [_captive] call co_main_fnc_trainingPhase;
            } else {
                _captive setVariable ["CO_transportInProgress", false, true];
            };

            // Crew dismount at the camp, then the van AND the crew group
            // are cleaned up once unobserved. Leaving the crew alive as a
            // permanent "garrison" leaked one west-side group per delivery,
            // and the engine's per-side group cap is exactly what starves
            // later transports into spawning crewless (the empty-van bug).
            {
                if (alive _x && vehicle _x == _veh) then {
                    unassignVehicle _x;
                    moveOut _x;
                };
                _x setVariable ["CO_vehicleChaseDriver", false, true];
                _x setVariable ["CO_isJailer", false, true];
            } forEach (units _crewGrp);
            call _releaseCrew;
            // Gentle cleanup: wait until nobody is watching (the conscript
            // trains here for minutes, then deploys far north — the van
            // goes unobserved when they leave), with a long hard backstop
            // so the group is always reclaimed even if they never wander.
            [_veh, _crewGrp] spawn {
                params ["_v", "_g"];
                private _hardCap = time + 1200;
                waitUntil {
                    sleep 15;
                    (isNull _v) ||
                    (allPlayers findIf { alive _x && _x distance2D _v < 150 } < 0) ||
                    (time > _hardCap)
                };
                { if (!isNull _x) then { deleteVehicle _x } } forEach (units _g);
                if (!isNull _v) then { deleteVehicle _v };
                if (!isNull _g) then { deleteGroup _g };
            };
            diag_log format ["[CO] Capture transport delivery complete at NWAF (%1).", name _captive];
        };

        case "escaped": {
            _veh forceSpeed 0;
            _veh lockCargo false;
            if (_captive in _veh) then {
                unassignVehicle _captive;
                moveOut _captive;
                if (isPlayer _captive) then {
                    [_captive] remoteExec ["moveOut", _captive];
                };
            };

            // Back to a free (hunted) civilian — no more phantom
            // "DETAINED — IN TRANSPORT".
            _captive setCaptive false;
            _captive setVariable ["CO_detainPhase", "", true];
            _captive setVariable ["CO_captureInProgress", false, true];
            _captive setVariable ["CO_transportInProgress", false, true];
            _captive setVariable ["CO_knockedOut", false, true];
            _captive setVariable ["CO_tackleImmuneUntil", time + 8, true];
            private _wl = ((_captive getVariable ["CO_wantedLevel", 0]) + 20) min 100;
            _captive setVariable ["CO_wantedLevel", _wl, true];
            [_captive, "SEARCH", "transport_escape", 60, _crewGrp] call co_main_fnc_setEscalationState;
            [_captive, getPosATL _captive, "transport_escape", 60] call co_main_fnc_alertPublish;
            ["transport_breakout"] call co_main_fnc_kpi;
            if (isPlayer _captive) then {
                ["You broke out of the transport — RUN."] remoteExecCall ["systemChat", _captive];
            };
            diag_log format ["[CO] Capture transport: %1 escaped at %2.", name _captive, mapGridPosition _captive];

            // The crew gives chase for 45 s; a tackle re-detains.
            {
                if (alive _x && vehicle _x != _x) then {
                    unassignVehicle _x;
                    moveOut _x;
                };
            } forEach (units _crewGrp);
            private _chaseEnd = time + 45;
            private _recaptured = false;
            while {
                time < _chaseEnd && alive _captive && !captive _captive && !_recaptured &&
                (({ alive _x && vehicle _x == _x } count units _crewGrp) > 0)
            } do {
                private _live = (units _crewGrp) select { alive _x && vehicle _x == _x };
                [_live, _captive] call co_main_fnc_chaseMove;
                if ([_live, _captive] call co_main_fnc_proximityTackle) then {
                    private _res = [_captive, 20] call co_main_fnc_runWrangle;
                    if (!isPlayer _captive || _res == "captured") then {
                        _recaptured = true;
                    };
                    if (_res == "escaped") then {
                        _captive setVariable ["CO_tackleImmuneUntil", time + 6, true];
                    };
                };
                sleep 0.8;
            };
            { [_x, _token] call co_main_fnc_releaseUnit } forEach (units _crewGrp);
            if (_recaptured && alive _captive) then {
                _captive setCaptive true;
                // Re-tackled at reach → kneel beat, then a fresh transport.
                [_captive, _crewGrp] call co_main_fnc_detainSequence;
            };
            call _despawnCrewAndVan;
        };

        case "rescued": {
            _veh lockCargo false;
            if (alive _captive && _captive in _veh) then {
                unassignVehicle _captive;
                moveOut _captive;
                if (isPlayer _captive) then {
                    [_captive] remoteExec ["moveOut", _captive];
                };
            };
            _captive setCaptive false;
            _captive setVariable ["CO_detainPhase", "", true];
            _captive setVariable ["CO_captureInProgress", false, true];
            _captive setVariable ["CO_transportInProgress", false, true];
            if (isPlayer _captive) then {
                ["The escort is dead. You're free — for now."] remoteExecCall ["systemChat", _captive];
            };
            call _releaseCrew;
            call _despawnCrewAndVan;
        };

        case "dead": {
            call _releaseCrew;
            call _despawnCrewAndVan;
            _captive setVariable ["CO_transportInProgress", false, true];
        };

        default {  // "failsafe": destroyed / flipped / stuck / timeout
            {
                if (alive _x && vehicle _x != _x) then {
                    unassignVehicle _x;
                    moveOut _x;
                };
            } forEach (units _crewGrp);
            call _releaseCrew;
            call _deliverDirect;
            call _despawnCrewAndVan;
        };
    };
};
