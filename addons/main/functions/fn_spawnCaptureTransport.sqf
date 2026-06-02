// ============================================================
// fn_spawnCaptureTransport.sqf
//
// Robust on-demand transport that picks up a captive and ships
// them to the NWAF training camp. Used by the SW border fort,
// checkpoint guards, and the global TCK aggression failsafe.
//
// Design notes
// ------------
//   The previous version drove the van TO the captive, then
//   tried to load. That was fragile: SAFE + disableAI TARGET
//   drivers silently ignored doMove on long-distance route
//   points, and even when the van arrived, moveInCargo on a
//   knocked-out player could fail without retry.
//
//   This version is deliberately direct:
//     1. Spawn the van at the nearest road > 12 m from the
//        captive (so the van's hitbox doesn't telefrag them).
//     2. Force-load the captive + a jailer IMMEDIATELY via
//        moveInCargo + verification + setPos fallback.
//     3. Wake the captive from knockout so they can ride
//        upright in the cargo (still captive — they can't
//        leave the seat while doors are locked).
//     4. Drive to the NWAF training field via an engine MOVE
//        waypoint (proven pattern from fn_policePatrols).
//     5. On arrival: unlock, force the captive out, clear
//        knockout state, and hand off to fn_trainingPhase.
//
// Params:
//   _captive       - the man to transport
//   _capturingGrp  - the group whose unit will be the driver
//
// Returns: nothing. Spawns its own thread.
// ============================================================

params [
    ["_captive", objNull, [objNull]],
    ["_capturingGrp", grpNull, [grpNull]]
];

if (!isServer) exitWith {
    [_captive, _capturingGrp] remoteExec ["co_main_fnc_spawnCaptureTransport", 2];
};

if (isNull _captive || !alive _captive) exitWith {};
if (isNull _capturingGrp) exitWith {};
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
            "[CO] spawnCaptureTransport: no road within %1 m of captive at %2.",
            _radius, mapGridPosition _captive
        ];
        _captive setVariable ["CO_transportInProgress", false, true];
    };

    // ---- 3. Create the transport ------------------------------
    private _vehClass = "C_Van_01_transport_F";
    private _veh = createVehicle [_vehClass, _spawnPos, [], 0, "NONE"];
    _veh allowDamage false;
    _veh setPosATL [_spawnPos select 0, _spawnPos select 1, 0.15];
    _veh setVectorUp [0, 0, 1];
    _veh setVelocity [0, 0, 0];
    // Face roughly toward the destination
    private _dx = (_dest select 0) - (_spawnPos select 0);
    private _dy = (_dest select 1) - (_spawnPos select 1);
    _veh setDir (_dx atan2 _dy);
    _veh setVariable ["CO_isCaptureTransport", true, true];
    _veh lockCargo false;
    _veh lockDriver false;
    [_veh] spawn { params ["_v"]; sleep 8; if (!isNull _v) then { _v allowDamage true } };

    diag_log format [
        "[CO] Capture transport %1 spawned at %2 for captive %3 (dest NWAF training %4).",
        _vehClass, mapGridPosition _veh, name _captive, _dest
    ];

    // ---- 4. Pick a driver + a jailer from the capturing group --
    private _alive = (units _capturingGrp) select { alive _x && vehicle _x == _x };
    if (count _alive == 0) then {
        diag_log "[CO] Capture transport: no live guards left to drive — using fallback NPC driver.";
        // Fallback driver so the captive still arrives at training
        private _fallbackGrp = createGroup west;
        _fallbackGrp setVariable ["CO_faction", "CRN_ENF", true];
        private _drv = _fallbackGrp createUnit ["B_Soldier_F", _spawnPos, [], 0, "FORM"];
        [_drv] call co_main_fnc_initHostileUnit;
        _alive = [_drv];
    };

    // Driver = closest guard (so they're already nearby); jailer = next closest.
    private _sortedByDist = [_alive, [], { _x distance _captive }, "ASCEND"] call BIS_fnc_sortBy;
    private _driverUnit = _sortedByDist select 0;
    private _jailerUnit = if (count _sortedByDist >= 2) then {
        _sortedByDist select 1
    } else { objNull };

    // Teleport driver into the van
    _driverUnit assignAsDriver _veh;
    _driverUnit moveInDriver _veh;
    _driverUnit setBehaviour "AWARE";
    _driverUnit setCombatMode "BLUE";
    _driverUnit enableAI "MOVE";
    _driverUnit enableAI "PATH";
    _driverUnit enableAI "FSM";
    _driverUnit setVariable ["CO_vehicleChaseDriver", true, true];

    // ---- 5. FORCE-LOAD the captive immediately ----------------
    // The bus is now stationary at a road. We need the captive in
    // cargo before we kick off the drive. moveInCargo is global
    // BUT, for player units, the queued teleport can silently fail
    // when the server is not the owner of the player (every MP
    // case). The reliable pattern is:
    //   1. Wake them so no special anim state blocks the move.
    //   2. Snap them onto the vehicle's position.
    //   3. Issue moveInCargo on the server (handles AI captives).
    //   4. For players: also remoteExec moveInCargo to the player's
    //      owner so the engine runs the seat assignment locally.
    //   5. Verify in-vehicle for up to ~3 s, retrying every 0.5 s.
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
        // Make sure they're not stuck unconscious from any other
        // damage handler that ran in parallel.
        _captive setUnconscious false;
        _captive setVariable ["CO_knockedOut", false, true];
        // Hard teleport onto the vehicle then re-issue moveInCargo.
        _captive setPos (getPosATL _veh);
        _captive assignAsCargo _veh;
        _captive moveInCargo _veh;
        if (isPlayer _captive) then {
            [_captive, _veh] remoteExec ["moveInCargo", _captive];
        };
    };

    if (!_loadOk) then {
        diag_log format [
            "[CO] Capture transport: FAILED to load captive %1 after retries (in: %2). Hard teleport.",
            name _captive, _captive in _veh
        ];
        // Last resort: setPos into vehicle and hope
        _captive setPos (getPosATL _veh);
    };

    // Wake the captive so they ride in the seat properly (still
    // captive — can't exit until the van unlocks doors).
    if (_captive getVariable ["CO_knockedOut", false]) then {
        _captive setUnconscious false;
        _captive setVariable ["CO_knockedOut", false, true];
        _captive setVariable ["CO_knockedOutUntil", time, true];
    };
    _captive setCaptive true;
    _captive setVariable ["CO_detainPhase", "transport", true];

    // Notify player so they understand what's happening
    if (isPlayer _captive) then {
        [_captive] remoteExecCall ["co_main_fnc_showDetentionHUD", _captive];
    };

    // Lock cargo so the captive can't bail mid-route
    _veh lockCargo true;

    // Load the jailer
    if (!isNull _jailerUnit && alive _jailerUnit) then {
        _jailerUnit setVariable ["CO_isJailer", true, true];
        _jailerUnit assignAsCargo _veh;
        _jailerUnit moveInCargo _veh;
    };

    // ---- 6. Drive to training camp via engine waypoint --------
    // Use a real waypoint (proven pattern from fn_policePatrols)
    // rather than fighting the engine with doMove on a freshly
    // seated driver.
    private _drvGrp = group _driverUnit;
    // Clear any pre-existing waypoints
    { deleteWaypoint _x } forEach +waypoints _drvGrp;
    private _wp = _drvGrp addWaypoint [_dest, 0];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointBehaviour "SAFE";
    _wp setWaypointCombatMode "BLUE";
    _wp setWaypointFormation "FILE";
    _wp setWaypointCompletionRadius 30;
    _drvGrp setCurrentWaypoint _wp;

    _veh engineOn true;
    _veh setFuel 1;
    _veh forceSpeed -1;
    _veh setVariable ["CO_busCaptives", [_captive], true];

    // Belt-and-braces: also issue a doMove so the driver kicks off
    // motion on the first tick even if the waypoint hasn't ticked
    // yet.
    sleep 0.5;
    _driverUnit doMove _dest;

    // Watchdog: if the van is stuck (no progress for 30 s) snap
    // it to a road and re-issue the waypoint.
    private _arrivalDeadline = time + 600;
    private _lastPos = getPosATL _veh;
    private _lastMoveCheck = time;

    waitUntil {
        sleep 3;
        if (!alive _veh) exitWith { true };
        if (isNull (driver _veh)) exitWith { true };
        if ((_veh distance2D _dest) < 35) exitWith { true };
        if (time > _arrivalDeadline) exitWith { true };

        // Stuck recovery
        if (time - _lastMoveCheck > 20) then {
            if ((getPosATL _veh) distance _lastPos < 4) then {
                diag_log format [
                    "[CO] Capture transport stuck at %1 — snapping to road.",
                    mapGridPosition _veh
                ];
                private _roads = (getPosATL _veh) nearRoads 80;
                if (count _roads > 0) then {
                    private _rp = getPos (_roads select 0);
                    _veh setPos [_rp select 0, _rp select 1, 0.2];
                    _veh setVectorUp [0,0,1];
                };
                _drvGrp setCurrentWaypoint _wp;
                _driverUnit doMove _dest;
            };
            _lastPos = getPosATL _veh;
            _lastMoveCheck = time;
        };
        false
    };

    if (!alive _veh) exitWith {
        diag_log "[CO] Capture transport destroyed en route.";
        _captive setVariable ["CO_transportInProgress", false, true];
        if (alive _captive) then {
            // Fail-safe: still deliver the player to training so
            // gameplay doesn't dead-end.
            _captive setPos (CO_trainingFieldPos vectorAdd [random 20 - 10, random 20 - 10, 0]);
            [_captive] call co_main_fnc_trainingPhase;
        };
    };

    // ---- 7. Unload at training camp ---------------------------
    _veh forceSpeed 0;
    if (!isNull (driver _veh)) then { doStop (driver _veh) };
    sleep 1;

    _veh lockCargo false;
    _veh lockDriver false;

    if (alive _captive) then {
        // Force out — try the polite path then the hard teleport.
        if (_captive in _veh) then {
            unassignVehicle _captive;
            _captive action ["GetOut", _veh];
            sleep 0.5;
            if (_captive in _veh) then { moveOut _captive };
        };
        _captive setPosATL (_dest vectorAdd [4 + random 4, random 8 - 4, 0]);

        // Clear any lingering knockout state
        _captive setUnconscious false;
        _captive setVariable ["CO_knockedOut", false, true];
        _captive setVariable ["CO_knockedOutUntil", time, true];
        _captive setVariable ["CO_captureInProgress", false, true];
        _captive setCaptive true;  // stay flagged conscript

        // Hand off to training phase (handles HUD, drills,
        // 10-min window, deployment to front).
        [_captive] call co_main_fnc_trainingPhase;
    };

    // Release the driver and jailer back into the world
    private _drv2 = driver _veh;
    if (!isNull _drv2 && alive _drv2) then {
        _drv2 setVariable ["CO_vehicleChaseDriver", false, true];
        unassignVehicle _drv2;
        moveOut _drv2;
    };
    if (!isNull _jailerUnit && alive _jailerUnit && (_jailerUnit in crew _veh)) then {
        unassignVehicle _jailerUnit;
        moveOut _jailerUnit;
        _jailerUnit setVariable ["CO_isJailer", false, true];
    };

    _captive setVariable ["CO_transportInProgress", false, true];

    diag_log format ["[CO] Capture transport delivery complete at NWAF training %1.", _dest];
};
