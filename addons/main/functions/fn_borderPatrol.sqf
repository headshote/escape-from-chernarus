// fn_borderPatrol.sqf
// Spawns land soldiers, ATV patrols, and boat patrols at map edges.

// Map boundary approximate box: Chernarus 15360x15360
CO_borderZones = [
    // [startPos, endPos, type]
    [[0, 7680, 0],   [0, 15360, 0],   "land"],  // West edge
    [[7680, 15360, 0],[15360,15360,0], "land"],  // North edge
    [[15360,7680,0], [15360, 0, 0],   "land"],  // East edge
    [[0, 0, 0],      [15360, 0, 0],   "boat"]   // South coast
];

// Helper: is _pos near any map edge?
CO_fnc_isNearBorder = {
    params ["_pos"];
    private _x = _pos select 0;
    private _y = _pos select 1;
    _x < 200 || _y < 200 || _x > 15160 || _y > 15160
};

// Spawn ATV patrols along land edges
{
    private _start = _x select 0;
    private _end   = _x select 1;
    private _type  = _x select 2;
    private _density = (missionNamespace getVariable ["CO_border_patrolDensity", 1]) max 0.25;
    private _spacing = (800 / _density) max 200;
    private _steps = round ((_start distance _end) / _spacing);

    for "_i" from 0 to _steps do {
        private _t   = _i / _steps;
        private _pos = _start vectorMultiply (1-_t) vectorAdd (_end vectorMultiply _t);
        _pos = _pos vectorAdd [random 50 - 25, random 50 - 25, 0];

        if (_type == "land") then {
            private _grp = createGroup west;
            _grp setVariable ["CO_faction", "CRN_ENF"];
            private _atv = "B_Quadbike_01_F" createVehicle _pos;
            private _driver = _grp createUnit ["B_Soldier_F", _pos, [], 0, "CARGO"];
            _driver moveInDriver _atv;
            private _passenger = _grp createUnit ["B_Soldier_F", _pos, [], 0, "CARGO"];
            _passenger moveInCargo _atv;
            [_driver] call co_main_fnc_initHostileUnit;
            [_passenger] call co_main_fnc_initHostileUnit;
            [_grp, _start, _end] call co_main_fnc_borderPatrolWaypoints;
        };

        if (_type == "boat") then {
            private _grp = createGroup west;
            _grp setVariable ["CO_faction", "CRN_ENF"];
            private _boat = "B_Boat_Armed_01_minigun_F" createVehicle _pos;
            private _driver = _grp createUnit ["B_Soldier_F", _pos, [], 0, "CARGO"];
            _driver moveInDriver _boat;
            private _gunner = _grp createUnit ["B_Soldier_F", _pos, [], 0, "CARGO"];
            _gunner moveInGunner _boat;
            [_driver] call co_main_fnc_initHostileUnit;
            [_gunner] call co_main_fnc_initHostileUnit;
            [_grp, _start, _end] call co_main_fnc_borderPatrolWaypoints;
        };
    };
} forEach CO_borderZones;

// Become hostile when player spotted near any border edge (within 150m)
[] spawn {
    while { true } do {
        sleep 2;
        {
            private _p = _x;
            if (captive _p || !alive _p) then { continue };
            if ([getPosATL _p] call CO_fnc_isNearBorder) then {
                // Alert nearest border groups
                {
                    if (_x getVariable ["CO_faction",""] == "CRN_ENF") then {
                        if ((leader _x) distance _p < 400) then {
                            [units _x, _p] call co_main_fnc_borderAlert;
                        };
                    };
                } forEach allGroups;

                // Check escape achievement
                private _pos = getPosATL _p;
                if ((_pos select 0 < 50 || _pos select 1 < 50 ||
                     _pos select 0 > 15310 || _pos select 1 > 15310)) then {
                    [_p] call co_main_fnc_checkEscapeUnlock;
                };
            };
        } forEach allPlayers;
    };
};