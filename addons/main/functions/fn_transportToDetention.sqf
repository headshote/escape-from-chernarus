// fn_transportToDetention.sqf
params ["_captive", "_capturingGrp"];

// Predefined detention centers
if (isNil "CO_detentionCenters") then {
    CO_detentionCenters = [
        [4800, 9600, 0],  // NW camp
        [12000, 5000, 0], // East facility
        [7400, 3100, 0]   // Central
    ];
};

// Find or create transport bus.
// Prefer an explicit CO_transportVehicle pinned by busAgroLoop when the
// escort leader has dismounted and `vehicle (leader _grp)` would no
// longer resolve to the bus.
private _bus = _capturingGrp getVariable ["CO_transportVehicle", objNull];
if (isNull _bus || !alive _bus) then {
    _bus = vehicle (leader _capturingGrp);
};
// Last-resort: walk the group looking for any unit currently inside a
// vehicle that belongs to the bus patrol.
if (isNull _bus || _bus isKindOf "Man") then {
    {
        private _v = vehicle _x;
        if (_v != _x && alive _v && (_v getVariable ["CO_isBusPatrol", false])) exitWith {
            _bus = _v;
        };
    } forEach (units _capturingGrp);
};
if (isNull _bus || _bus isKindOf "Man") exitWith {
    // No vehicle attached to the capturing group. Hand off entirely to
    // the dedicated capture-transport helper which spawns a van at the
    // NEAREST ROAD (NOT on top of the captive — that detonated against
    // the player hitbox and silently aborted the flow), drives it over,
    // loads the captive + a jailer guard, and delivers to detention or
    // the NW airfield training ground.
    [_captive, _capturingGrp] call co_main_fnc_spawnCaptureTransport;
};

private _busDriver = driver _bus;
if (isNull _busDriver) exitWith {
    diag_log "[CO] transportToDetention aborted: no bus driver available.";
};

_captive setCaptive true;

if (_bus getVariable ["CO_isBusPatrol", false]) exitWith {
    _captive moveInCargo _bus;
    [leader _capturingGrp, _captive, 60, true] call co_main_fnc_applyKnockout;

    private _busCaptives = (_bus getVariable ["CO_busCaptives", []]) select {
        !isNull _x && alive _x && captive _x
    };

    if !(_captive in _busCaptives) then {
        _busCaptives pushBack _captive;
    };

    _bus setVariable ["CO_busCaptives", _busCaptives, true];
    _bus setVariable ["CO_busLastCaptureTime", time, true];

    private _deliveryThreshold = missionNamespace getVariable ["CO_busDetentionThreshold", 2];
    private _cruiseAfterCapture = missionNamespace getVariable ["CO_busCruiseAfterCapture", 45];

    private _requestDelivery = {
        params ["_transportBus", "_transportGroup"];

        if (_transportBus getVariable ["CO_busState", "patrol"] == "delivering") exitWith {};

        _transportBus setVariable ["CO_busState", "delivering", true];
        _transportBus setVariable ["CO_busDeliveryScheduled", false, true];

        [_transportBus, _transportGroup] spawn {
            params ["_transportBus", "_transportGroup"];

            if (!alive _transportBus) exitWith {};

            private _routeWps = _transportBus getVariable ["CO_busRouteWps", []];
            private _escortUnits = units _transportGroup select { alive _x && _x != driver _transportBus };

            _transportBus lockCargo false;
            {
                _x allowGetIn true;
                _x assignAsCargo _transportBus;
                [_x] orderGetIn true;
                _x doMove (getPosATL _transportBus);
            } forEach _escortUnits;

            private _reboardDeadline = time + 12;
            waitUntil {
                sleep 0.5;
                ({ vehicle _x == _transportBus } count _escortUnits) >= ((count _escortUnits) max 1) ||
                time > _reboardDeadline ||
                !alive _transportBus
            };

            if (!alive _transportBus) exitWith {};

            // TCK conscription buses ship captives to the TRAINING ground
            // (NWAF airfield). Other factions (police, etc.) ship to the
            // nearest standard detention center.
            private _grpFac = _transportGroup getVariable ["CO_faction", ""];
            private _dest = if (_grpFac == "CRN_ENF") then {
                if (isNil "CO_trainingFieldPos") then { CO_trainingFieldPos = [2160, 12800, 0] };
                +CO_trainingFieldPos
            } else {
                private _destinations = [CO_detentionCenters, [], { _x distance2D _transportBus }, "ASCEND"] call BIS_fnc_sortBy;
                _destinations select 0
            };

            {
                deleteWaypoint _x;
            } forEach +waypoints _transportGroup;

            private _deliveryWp = _transportGroup addWaypoint [_dest, 15];
            _deliveryWp setWaypointType "MOVE";
            _deliveryWp setWaypointSpeed "NORMAL";

            private _arrivalDeadline = time + 240;
            waitUntil {
                sleep 2;
                !alive _transportBus ||
                isNull (driver _transportBus) ||
                (_transportBus distance2D _dest < 35) ||
                time > _arrivalDeadline
            };

            if (!alive _transportBus) exitWith {};

            private _grpFacUnload = _transportGroup getVariable ["CO_faction", ""];
            if (_grpFacUnload != "CRN_ENF") then {
                [_dest] call co_main_fnc_spawnDetentionGuards;
            };

            private _captivesToUnload = (_transportBus getVariable ["CO_busCaptives", []]) select {
                !isNull _x && alive _x && captive _x
            };

            {
                unassignVehicle _x;
                _x leaveVehicle _transportBus;
                _x setPosATL (_dest vectorAdd [4 + random 5, random 8 - 4, 0]);
                // TCK buses hand off to trainingPhase (boot camp); other
                // buses hand off to the prison sequence at detention.
                if (_grpFacUnload == "CRN_ENF") then {
                    _x setCaptive true;
                    _x setVariable ["CO_knockedOut", false, true];
                    _x setUnconscious false;
                    [_x] call co_main_fnc_trainingPhase;
                } else {
                    [_x] call co_main_fnc_prisonSequence;
                };
            } forEach _captivesToUnload;

            _transportBus setVariable ["CO_busCaptives", [], true];

            // ----- Hand the bus back to the cruise controller --------
            // The bus is driven by fn_busAgroLoop, which expects state
            // "traveling" + an active engine waypoint list to resume
            // patrolling. The original implementation deleted ALL
            // waypoints here and set state to "cruising" — a value
            // that fn_busAgroLoop does not handle, so the bus sat
            // idle forever after a single delivery (the root cause of
            // "TCK trucks just stand uselessly" reports). We now re-
            // install the original cruise waypoints from CO_busRouteWps
            // and reset state to "traveling".
            {
                deleteWaypoint _x;
            } forEach +waypoints _transportGroup;

            private _cruiseRoute = _transportBus getVariable ["CO_busRouteWps", []];
            if (count _cruiseRoute > 0) then {
                {
                    private _wp = _transportGroup addWaypoint [_x, 0];
                    _wp setWaypointType "MOVE";
                    _wp setWaypointSpeed "NORMAL";
                    _wp setWaypointBehaviour "SAFE";
                    _wp setWaypointCombatMode "BLUE";
                    _wp setWaypointFormation "FILE";
                    _wp setWaypointCompletionRadius 30;
                } forEach _cruiseRoute;
                private _cycleWp = _transportGroup addWaypoint [_cruiseRoute select 0, 0];
                _cycleWp setWaypointType "CYCLE";
                _cycleWp setWaypointSpeed "NORMAL";
                _cycleWp setWaypointBehaviour "SAFE";
                _cycleWp setWaypointCombatMode "BLUE";
                _transportGroup setCurrentWaypoint [_transportGroup, 0];
            };

            // Kick the engine on the driver so the cruise begins
            // immediately instead of waiting for the next loop tick.
            if (alive _transportBus) then {
                _transportBus engineOn true;
                _transportBus forceSpeed -1;
                private _drv = driver _transportBus;
                if (!isNull _drv) then {
                    _drv setBehaviour "SAFE";
                    _drv setCombatMode "BLUE";
                    _drv enableAI "MOVE";
                    _drv enableAI "PATH";
                    _drv enableAI "FSM";
                    if (count _cruiseRoute > 0) then {
                        _drv doMove (_cruiseRoute select 0);
                    };
                };
            };

            _transportBus setVariable ["CO_busState", "traveling", true];
            _transportBus setVariable ["CO_busNextEngageAt", time + 20, false];
            _transportBus setVariable ["CO_busLastIdleReset", time, true];
        };
    };

    if (count _busCaptives >= _deliveryThreshold) then {
        [_bus, _capturingGrp] call _requestDelivery;
    } else {
        if !(_bus getVariable ["CO_busDeliveryScheduled", false]) then {
            _bus setVariable ["CO_busDeliveryScheduled", true, true];
            [_bus, _capturingGrp, _cruiseAfterCapture, _requestDelivery] spawn {
                params ["_transportBus", "_transportGroup", "_cruiseAfterCapture", "_requestDelivery"];

                sleep _cruiseAfterCapture;

                private _captivesStillAboard = (_transportBus getVariable ["CO_busCaptives", []]) select {
                    !isNull _x && alive _x && captive _x
                };

                if (_captivesStillAboard isEqualTo []) then {
                    _transportBus setVariable ["CO_busDeliveryScheduled", false, true];
                    if ((_transportBus getVariable ["CO_busState", "cruising"]) != "delivering") then {
                        _transportBus setVariable ["CO_busState", "cruising", true];
                    };
                } else {
                    [_transportBus, _transportGroup] call _requestDelivery;
                };
            };
        };

        if ((_bus getVariable ["CO_busState", "cruising"]) == "engaging") then {
            _bus setVariable ["CO_busState", "cruising", true];
        };
    };
};

// Load captive into bus
_captive moveInCargo _bus;

// Optionally cruise for other players (30s) then drive to detention
[_bus, _captive] spawn {
    params ["_bus", "_captive"];

    // Cruise for co-op targets briefly
    sleep 30;

    // Pick nearest detention center
    private _dest = [CO_detentionCenters, [], { _x distance _bus }, "ASCEND"] call BIS_fnc_sortBy;
    _dest = _dest select 0;

    private _driver = driver _bus;
    if (isNull _driver) exitWith {
        diag_log "[CO] transportToDetention aborted: bus lost its driver during transit.";
    };

    _driver doMove _dest;
    waitUntil { sleep 1; _driver distance _dest < 20 || !alive _bus };

    if (!alive _bus) exitWith {};

    // Unload at detention
    _captive leaveVehicle _bus;
    _captive setPosATL (_dest vectorAdd [5,0,0]);

    // Spawn detention guards
    [_dest] call co_main_fnc_spawnDetentionGuards;
    [_captive] call co_main_fnc_prisonSequence;
};