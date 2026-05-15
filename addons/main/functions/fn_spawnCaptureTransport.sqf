// ============================================================
// fn_spawnCaptureTransport.sqf
//
// Robust on-demand transport that picks up a captive whenever
// no patrol bus is close enough to do the job. Used by the SW
// border fort, checkpoint guards, and the global TCK aggression
// failsafe.
//
// Behavior
// --------
//   1. Pick the closest detention center OR NW airfield training
//      ground as the destination (50/50).
//   2. Spawn a transport van/truck at the nearest road within
//      ~180 m of the captive (NEVER on top of the captive — that
//      was the cause of the silent-fail bug where vans detonated
//      against the player's hitbox on the same frame).
//   3. Assign one of the capturing guards as the driver
//      (teleported into the seat) and a second guard as the
//      "jailer" who stays next to the captive until the van
//      pulls up.
//   4. Drive the van to the captive's position, force-load the
//      captive + the jailer into cargo, then route to the
//      destination via doMove.
//   5. On arrival: unload, run prisonSequence on the captive.
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

// Make sure the captive is in a sticky knockout so they can't bolt
if !(_captive getVariable ["CO_knockedOut", false]) then {
    private _attacker = leader _capturingGrp;
    [_attacker, _captive, 75, true] call co_main_fnc_applyKnockout;
};

[_captive, _capturingGrp] spawn {
    params ["_captive", "_capturingGrp"];

    // ---- 1. Pick destination ----------------------------------
    if (isNil "CO_detentionCenters") then {
        CO_detentionCenters = [
            [4800, 9600, 0],   // NW camp
            [12000, 5000, 0],  // East facility
            [7400, 3100, 0]    // Central
        ];
    };
    private _nwAirfield = missionNamespace getVariable [
        "CO_airfieldCenter", [4720, 9985, 0]
    ];

    private _destChoices = (+CO_detentionCenters) + [_nwAirfield];
    // 60% nearest detention, 40% NW airfield (variety of outcomes)
    private _dest = if (random 1 < 0.6) then {
        ([CO_detentionCenters, [], { _x distance2D _captive }, "ASCEND"] call BIS_fnc_sortBy) select 0
    } else {
        _nwAirfield
    };

    // ---- 2. Find a road spawn position near the captive -------
    private _captivePos = getPosATL _captive;
    private _spawnPos   = [];
    private _radius     = 100;
    while { _spawnPos isEqualTo [] && _radius <= 600 } do {
        private _roads = _captivePos nearRoads _radius;
        private _candidates = _roads select { !isNull _x && isOnRoad (getPos _x) };
        if (count _candidates > 0) then {
            private _tries = _candidates call BIS_fnc_arrayShuffle;
            if (count _tries > 14) then { _tries resize 14 };
            {
                private _p = getPos _x;
                // Reject if another vehicle within 14 m
                if ((count (_p nearEntities [["Car","Truck","Tank"], 14])) > 0) then {
                    continue
                };
                private _empty = _p findEmptyPosition [0, 6, "C_Van_01_transport_F"];
                if !(_empty isEqualTo []) exitWith { _spawnPos = _empty };
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
    // Face roughly toward the captive
    private _dx = (_captivePos select 0) - (_spawnPos select 0);
    private _dy = (_captivePos select 1) - (_spawnPos select 1);
    _veh setDir (_dx atan2 _dy);
    _veh setVariable ["CO_isCaptureTransport", true, true];
    [_veh] spawn { params ["_v"]; sleep 5; if (!isNull _v) then { _v allowDamage true } };

    diag_log format [
        "[CO] Capture transport %1 spawned at %2 for captive %3 (dest %4).",
        _vehClass, mapGridPosition _veh, name _captive, _dest
    ];

    // ---- 4. Pick a driver + a jailer from the capturing group --
    private _alive = (units _capturingGrp) select { alive _x && vehicle _x == _x };
    if (count _alive == 0) exitWith {
        diag_log "[CO] Capture transport: no live guards left to drive.";
        deleteVehicle _veh;
        _captive setVariable ["CO_transportInProgress", false, true];
    };

    // Driver: the guard furthest from the captive (so the closest stays as jailer)
    private _sortedByDist = [_alive, [], { _x distance _captive }, "DESCEND"] call BIS_fnc_sortBy;
    private _driverUnit = _sortedByDist select 0;
    private _jailerUnit = if (count _sortedByDist >= 2) then {
        // The closest guard is the jailer
        (_sortedByDist select ((count _sortedByDist) - 1))
    } else { objNull };

    // Teleport driver into the van
    _driverUnit assignAsDriver _veh;
    _driverUnit moveInDriver _veh;
    _driverUnit setBehaviour "SAFE";
    _driverUnit setCombatMode "BLUE";
    _driverUnit disableAI "AUTOTARGET";
    _driverUnit disableAI "TARGET";
    _driverUnit enableAI "MOVE";
    _driverUnit enableAI "PATH";
    _driverUnit enableAI "FSM";
    _driverUnit setVariable ["CO_vehicleChaseDriver", true, true];

    // Jailer behaviour — stand right next to the captive until pickup
    private _jailerStaysThread = scriptNull;
    if (!isNull _jailerUnit) then {
        _jailerUnit setVariable ["CO_isJailer", true, true];
        _jailerUnit setBehaviour "AWARE";
        _jailerUnit setCombatMode "YELLOW";
        _jailerUnit setUnitPos "UP";
        _jailerStaysThread = [_jailerUnit, _captive, _veh] spawn {
            params ["_j", "_c", "_v"];
            while {
                alive _j && alive _c &&
                vehicle _j == _j &&
                !(_c in (crew _v))
            } do {
                if ((_j distance _c) > 4) then {
                    _j doMove (getPosATL _c);
                };
                _j doWatch _c;
                sleep 2;
            };
        };
    };

    // ---- 5. Drive the van to the captive ----------------------
    _veh engineOn true;
    _veh forceSpeed -1;
    _driverUnit doMove (getPosATL _captive);

    private _approachDeadline = time + 90;
    waitUntil {
        sleep 1;
        !alive _veh ||
        !alive _captive ||
        isNull (driver _veh) ||
        (_veh distance2D _captive) < 14 ||
        time > _approachDeadline
    };

    if (!alive _veh || !alive _captive) exitWith {
        diag_log "[CO] Capture transport aborted (van or captive dead during approach).";
        _captive setVariable ["CO_transportInProgress", false, true];
    };

    // Stop the van
    private _drv = driver _veh;
    if (!isNull _drv) then { doStop _drv };
    _veh forceSpeed 0;

    // ---- 6. Load the captive + jailer -------------------------
    sleep 0.5;
    _captive setCaptive true;
    if (!isNull _captive && alive _captive) then {
        _captive moveInCargo _veh;
    };
    if (!isNull _jailerUnit && alive _jailerUnit) then {
        _jailerUnit assignAsCargo _veh;
        _jailerUnit moveInCargo _veh;
    };

    sleep 1;
    // ---- 7. Drive to destination ------------------------------
    _veh setVariable ["CO_busCaptives", [_captive], true];
    _veh forceSpeed -1;
    if (!isNull _drv) then {
        _drv doMove _dest;
    };

    private _arrivalDeadline = time + 600;
    waitUntil {
        sleep 3;
        !alive _veh ||
        isNull (driver _veh) ||
        (_veh distance2D _dest) < 30 ||
        time > _arrivalDeadline
    };

    if (!alive _veh) exitWith {
        diag_log "[CO] Capture transport destroyed en route.";
        _captive setVariable ["CO_transportInProgress", false, true];
    };

    // ---- 8. Unload at destination -----------------------------
    if (!isNull _drv) then { doStop _drv; _veh forceSpeed 0 };
    sleep 1;

    if (alive _captive && (_captive in crew _veh)) then {
        unassignVehicle _captive;
        _captive leaveVehicle _veh;
        _captive setPosATL (_dest vectorAdd [4 + random 4, random 8 - 4, 0]);
        // Hand off to the existing prison sequence (covers training transfer)
        [_dest] call co_main_fnc_spawnDetentionGuards;
        [_captive] call co_main_fnc_prisonSequence;
    };

    // Release the driver and jailer back into the world
    if (!isNull _drv && alive _drv) then {
        _drv setVariable ["CO_vehicleChaseDriver", false, true];
        unassignVehicle _drv;
        moveOut _drv;
    };
    if (!isNull _jailerUnit && alive _jailerUnit && (_jailerUnit in crew _veh)) then {
        unassignVehicle _jailerUnit;
        moveOut _jailerUnit;
        _jailerUnit setVariable ["CO_isJailer", false, true];
    };

    _captive setVariable ["CO_transportInProgress", false, true];

    diag_log format ["[CO] Capture transport delivery complete at %1.", _dest];
};
