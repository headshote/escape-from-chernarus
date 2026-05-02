// fn_busAgroLoop.sqf — server-side, monitors bus for nearby targets
params ["_veh", "_grp"];

while { alive _veh } do {
    private _nearTargets = (_veh nearEntities [["Man"], 60]) select {
        alive _x &&
        !captive _x &&
        side _x == civilian &&
        !(_x getVariable ["CO_isFemale", false])
    };

    if (count _nearTargets > 0) then {
        private _sortedTargets = [_nearTargets, [], { _x distance _veh }, "ASCEND"] call BIS_fnc_sortBy;
        private _target = _sortedTargets select 0;

        // Dismount all non-drivers
        {
            if (_x != driver _veh && vehicle _x == _veh) then {
                unassignVehicle _x;
                _x action ["GetOut", _veh];
            };
        } forEach crew _veh;
        sleep 1.5;

        [[_target], _grp] call co_main_fnc_checkpointAlert;

        // Driver tries to cut off escape
        if (isPlayer _target) then {
            [_veh, _target] spawn {
            params ["_bus", "_target"];
            waitUntil { sleep 0.5; _target distance _bus > 40 || captive _target };
            if (!(captive _target)) then {
                // Drive ahead of player's projected position
                private _vel = velocity _target;
                private _interceptPos = (getPosATL _target) vectorAdd (_vel vectorMultiply 6);
                driver _bus doMove _interceptPos;
            };
            };
        };

        sleep 8;
    };

    sleep 2;
};