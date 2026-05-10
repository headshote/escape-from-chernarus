// fn_busAgroLoop.sqf — server-side, monitors bus for nearby targets
params ["_veh", "_grp"];

private _aggroRadius = missionNamespace getVariable ["CO_bus_aggroRadius", 180];
private _maxCaptives = missionNamespace getVariable ["CO_bus_maxCaptives", 3];
private _patrolStopInterval = missionNamespace getVariable ["CO_bus_patrolStopInterval", 150];

private _isValidTarget = {
    params ["_unit"];
    if (isNull _unit || {!alive _unit} || {captive _unit}) exitWith { false };
    if (_unit getVariable ["CO_isFemale", false]) exitWith { false };
    if (_unit getVariable ["CO_captureInProgress", false]) exitWith { false };
    if (_unit getVariable ["CO_knockedOut", false]) exitWith { false };

    private _faction = group _unit getVariable ["CO_faction", ""];
    if (_faction in ["CRN_ENF", "POLICE", "CRN_FRONT", "RUS_ADV"]) exitWith { false };

    if (isPlayer _unit) exitWith {
        !((side (group _unit)) in [west, east])
    };

    side _unit == civilian
};

private _dismountEscort = {
    params ["_escortUnits", "_bus", "_target"];

    {
        if (alive _x) then {
            _x enableAI "MOVE";
            _x enableAI "PATH";
            _x enableAI "AUTOCOMBAT";
            _x allowGetIn false;
            unassignVehicle _x;
            if (vehicle _x == _bus) then {
                doGetOut _x;
                moveOut _x;
            };
            _x setBehaviour "COMBAT";
            _x setCombatMode "RED";
            _x doTarget _target;
            _x doMove (getPosATL _target);
        };
    } forEach _escortUnits;

    private _dismountDeadline = time + 8;
    waitUntil {
        sleep 0.25;
        ({ alive _x && { vehicle _x == _bus } } count _escortUnits) == 0 ||
        time > _dismountDeadline ||
        !alive _bus
    };
};

while { alive _veh } do {
    if ((_veh getVariable ["CO_busState", "patrol"]) == "delivering") then {
        sleep 2;
        continue;
    };

    // If we've hit the cargo cap, stop hunting; existing delivery scheduler
    // (set up in fn_transportToDetention after the first capture) will drive
    // the bus to a detention center on its own.
    private _aboard = (_veh getVariable ["CO_busCaptives", []]) select {
        !isNull _x && alive _x && captive _x
    };
    if (count _aboard >= _maxCaptives) then {
        _veh setVariable ["CO_busCaptives", _aboard, true];
        sleep 3;
        continue;
    };

    if (time < (_veh getVariable ["CO_busNextEngageAt", 0])) then {
        sleep 1;
        continue;
    };

    private _nearTargets = (_veh nearEntities [["Man"], _aggroRadius]) select {
        [_x] call _isValidTarget
    };

    {
        private _vehicle = _x;
        private _crewTargets = (crew _vehicle) select { [_x] call _isValidTarget };
        {
            _nearTargets pushBackUnique _x;
        } forEach _crewTargets;
    } forEach ((_veh nearEntities [["LandVehicle"], _aggroRadius + 120]) select { _x != _veh && alive _x });

    // --- Proactive patrol stop ---
    // If the bus is in/near a populated settlement and hasn't paused recently,
    // pull over and have the escort dismount briefly to "patrol" the area
    // looking for targets. Models the spec: bus crews periodically halt and
    // hunt foot civilians. Only triggers when no immediate target found.
    if (count _nearTargets == 0) then {
        private _lastStop = _veh getVariable ["CO_busLastPatrolStop", 0];
        private _shouldStop = (time - _lastStop) > _patrolStopInterval;
        if (_shouldStop) then {
            private _nearSettlement = (CO_settlements findIf {
                (_veh distance2D (_x select 1)) < 350
            }) >= 0;
            if (_nearSettlement && (speed _veh) > 5) then {
                _veh setVariable ["CO_busLastPatrolStop", time, false];
                [_veh, _grp] spawn {
                    params ["_bus", "_grp"];
                    private _driver = driver _bus;
                    if (isNull _driver) exitWith {};

                    _bus setVariable ["CO_busState", "patrolStop", true];
                    _bus forceSpeed 0;
                    doStop _driver;

                    private _escort = units _grp select { alive _x && _x != _driver };
                    {
                        _x enableAI "MOVE";
                        _x enableAI "PATH";
                        _x enableAI "AUTOCOMBAT";
                        _x allowGetIn false;
                        unassignVehicle _x;
                        if (vehicle _x == _bus) then {
                            doGetOut _x;
                            moveOut _x;
                        };
                    } forEach _escort;

                    private _scanCenter = getPosATL _bus;
                    {
                        if (alive _x && vehicle _x != _bus) then {
                            private _patrolPoint = _scanCenter getPos [10 + random 30, random 360];
                            _x doMove _patrolPoint;
                            _x setBehaviour "AWARE";
                            _x setCombatMode "YELLOW";
                        };
                    } forEach _escort;

                    sleep 30;

                    // Reboard if no engagement was triggered during the stop
                    if (alive _bus && (_bus getVariable ["CO_busState", "patrolStop"]) == "patrolStop") then {
                        {
                            if (alive _x) then {
                                _x allowGetIn true;
                                _x assignAsCargo _bus;
                                [_x] orderGetIn true;
                                _x doMove (getPosATL _bus);
                            };
                        } forEach _escort;

                        private _reboardDeadline = time + 12;
                        waitUntil {
                            sleep 0.5;
                            ({ vehicle _x == _bus } count _escort) >= ((count _escort) max 1) ||
                            time > _reboardDeadline ||
                            !alive _bus
                        };

                        _bus forceSpeed -1;
                        _bus setVariable ["CO_busState", "patrol", true];
                    };
                };
                sleep 2;
                continue;
            };
        };
    };

    if (count _nearTargets > 0) then {
        private _sortedTargets = [_nearTargets, [], { (vehicle _x) distance _veh }, "ASCEND"] call BIS_fnc_sortBy;
        private _target = _sortedTargets select 0;
        private _targetObject = vehicle _target;
        private _targetInVehicle = _targetObject != _target;
        private _driver = driver _veh;
        private _escortUnits = units _grp select { alive _x && _x != _driver };

        _veh setVariable ["CO_busState", "engaging", true];
        _veh setVariable ["CO_busNextEngageAt", time + 12, false];
        _veh lockCargo false;

        if (!isNull _driver) then {
            _driver setVariable ["CO_vehicleChaseDriver", true, false];
            _driver enableAI "MOVE";
            _driver enableAI "PATH";
            _driver enableAI "AUTOCOMBAT";
            _driver setBehaviour "COMBAT";
            _driver setCombatMode "RED";
        };

        if (_targetInVehicle) then {
            diag_log format ["[CO] Bus patrol pursuing vehicle target %1 near %2.", name _target, mapGridPosition _targetObject];
            _veh forceSpeed -1;
            private _pursuitDeadline = time + 45;
            waitUntil {
                sleep 1;
                _targetObject = vehicle _target;
                if (!alive _veh || !alive _target || captive _target) exitWith { true };
                if (!isNull _driver && alive _driver) then {
                    _grp reveal [_targetObject, 4];
                    _driver doTarget _targetObject;
                    _driver doMove (getPosATL _targetObject);
                };
                (_veh distance _targetObject) < 45 ||
                _targetObject == _target ||
                time > _pursuitDeadline
            };
        };

        if (!isNull _driver && alive _driver) then {
            doStop _driver;
            _veh forceSpeed 0;
        };

        [_escortUnits, _veh, _target] call _dismountEscort;

        [[_target], _grp] call co_main_fnc_checkpointAlert;

        // Driver tries to cut off escape
        [_veh, _target] spawn {
            params ["_bus", "_target"];
            private _driver = driver _bus;
            if (isNull _driver) exitWith {};

            while { alive _bus && alive _target && !captive _target } do {
                private _interceptPos = getPosATL _target;
                if (isPlayer _target) then {
                    private _vel = velocity _target;
                    _interceptPos = _interceptPos vectorAdd (_vel vectorMultiply 6);
                };

                _driver doMove _interceptPos;
                sleep 1.5;
            };
        };

        private _engageDeadline = time + 30;
        waitUntil {
            sleep 0.5;
            captive _target ||
            !alive _target ||
            !(_target getVariable ["CO_captureInProgress", false]) ||
            time > _engageDeadline ||
            !alive _veh
        };

        {
            if (alive _x) then {
                _x allowGetIn true;
                _x assignAsCargo _veh;
                [_x] orderGetIn true;
                _x doMove (getPosATL _veh);
            };
        } forEach _escortUnits;

        private _reboardDeadline = time + 10;
        waitUntil {
            sleep 0.5;
            ({ vehicle _x == _veh } count _escortUnits) >= ((count _escortUnits) max 1) ||
            time > _reboardDeadline ||
            !alive _veh
        };

        _veh lockCargo false;
        _veh forceSpeed -1;

        if (!isNull _driver && alive _driver) then {
            _driver setBehaviour "AWARE";
            _driver setCombatMode "YELLOW";
            _driver setVariable ["CO_vehicleChaseDriver", false, false];
            private _currentWpPos = waypointPosition [_grp, currentWaypoint _grp];
            if !(_currentWpPos isEqualTo [0,0,0]) then {
                _driver doMove _currentWpPos;
            };
        };

        if ((_veh getVariable ["CO_busState", "patrol"]) == "engaging") then {
            _veh setVariable ["CO_busState", "patrol", true];
        };

        sleep 4;
    };

    sleep 1;
};