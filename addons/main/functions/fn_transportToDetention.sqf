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

// Find or create transport bus
private _bus = vehicle (leader _capturingGrp);
if (_bus isKindOf "Man") exitWith {
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

            private _destinations = [CO_detentionCenters, [], { _x distance2D _transportBus }, "ASCEND"] call BIS_fnc_sortBy;
            private _dest = _destinations select 0;

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

            [_dest] call co_main_fnc_spawnDetentionGuards;

            private _captivesToUnload = (_transportBus getVariable ["CO_busCaptives", []]) select {
                !isNull _x && alive _x && captive _x
            };

            {
                unassignVehicle _x;
                _x leaveVehicle _transportBus;
                _x setPosATL (_dest vectorAdd [4 + random 5, random 8 - 4, 0]);
                [_x] call co_main_fnc_prisonSequence;
            } forEach _captivesToUnload;

            _transportBus setVariable ["CO_busCaptives", [], true];

            // The bus is driven by fn_busAgroLoop via doMove; flush any
            // stale engine waypoints from earlier revisions so they don't
            // fight the scripted driving.
            {
                deleteWaypoint _x;
            } forEach +waypoints _transportGroup;

            _transportBus setVariable ["CO_busState", "cruising", true];
            _transportBus setVariable ["CO_busNextEngageAt", time + 20, false];
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