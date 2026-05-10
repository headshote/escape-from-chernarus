// fn_busAgroLoop.sqf — server-side, monitors bus for nearby targets
params ["_veh", "_grp"];

private _aggroRadius = missionNamespace getVariable ["CO_bus_aggroRadius", 180];
private _maxCaptives = missionNamespace getVariable ["CO_bus_maxCaptives", 3];
private _patrolStopInterval = missionNamespace getVariable ["CO_bus_patrolStopInterval", 150];

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
        alive _x &&
        !captive _x &&
        side _x == civilian &&
        !(_x getVariable ["CO_isFemale", false]) &&
        !(_x getVariable ["CO_captureInProgress", false]) &&
        !(_x getVariable ["CO_knockedOut", false]) &&
        vehicle _x == _x
    };

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
                        _x allowGetIn false;
                        unassignVehicle _x;
                        if (vehicle _x == _bus) then { doGetOut _x; };
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
        private _sortedTargets = [_nearTargets, [], { _x distance _veh }, "ASCEND"] call BIS_fnc_sortBy;
        private _target = _sortedTargets select 0;
        private _driver = driver _veh;
        private _escortUnits = units _grp select { alive _x && _x != _driver };

        _veh setVariable ["CO_busState", "engaging", true];
        _veh setVariable ["CO_busNextEngageAt", time + 12, false];
        _veh lockCargo false;

        if (!isNull _driver) then {
            doStop _driver;
            _veh forceSpeed 0;
            _driver setBehaviour "COMBAT";
            _driver doMove (getPosATL _target);
        };

        // Dismount escort team and keep them outside until the capture attempt resolves.
        {
            _x allowGetIn false;
            if (vehicle _x == _veh) then {
                unassignVehicle _x;
                doGetOut _x;
            };
        } forEach _escortUnits;

        private _dismountDeadline = time + 6;
        waitUntil {
            sleep 0.5;
            ({ vehicle _x == _veh } count _escortUnits) == 0 ||
            time > _dismountDeadline ||
            !alive _veh
        };

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
        };

        if ((_veh getVariable ["CO_busState", "patrol"]) == "engaging") then {
            _veh setVariable ["CO_busState", "patrol", true];
        };

        sleep 4;
    };

    sleep 1;
};