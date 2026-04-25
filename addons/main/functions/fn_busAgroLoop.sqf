// fn_busAgroLoop.sqf — server-side, monitors bus for nearby targets
params ["_veh", "_grp"];

while { alive _veh } do {
    private _nearPlayers = allPlayers select { _x distance _veh < 60 && !(captive _x) };

    if (count _nearPlayers > 0) then {
        private _target = _nearPlayers select 0;

        // Dismount all non-drivers
        { if (_x != driver _veh) then { unassignVehicle _x; _x action ["GetOut", _veh]; }; } forEach crew _veh;
        sleep 1.5;

        // Order pursuit
        { _x doTarget _target; _x doMove getPosATL _target; } forEach (units _grp - [driver _veh]);

        // Driver tries to cut off escape
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

    sleep 2;
};