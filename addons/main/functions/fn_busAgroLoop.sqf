// fn_busAgroLoop.sqf — server-side, monitors bus for nearby targets
params ["_veh", "_grp"];

while { alive _veh } do {
    if ((_veh getVariable ["CO_busState", "patrol"]) == "delivering") then {
        sleep 2;
        continue;
    };

    if (time < (_veh getVariable ["CO_busNextEngageAt", 0])) then {
        sleep 2;
        continue;
    };

    private _nearTargets = (_veh nearEntities [["Man"], 60]) select {
        alive _x &&
        !captive _x &&
        side _x == civilian &&
        !(_x getVariable ["CO_isFemale", false]) &&
        !(_x getVariable ["CO_captureInProgress", false]) &&
        vehicle _x == _x
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
            _driver setBehaviour "SAFE";
        };

        if ((_veh getVariable ["CO_busState", "patrol"]) == "engaging") then {
            _veh setVariable ["CO_busState", "patrol", true];
        };

        sleep 4;
    };

    sleep 2;
};