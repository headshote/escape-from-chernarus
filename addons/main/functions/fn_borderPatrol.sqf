// fn_borderPatrol.sqf
// Spawns land soldiers, ATV patrols, and boat patrols at map edges.

// Map boundary approximate box: Chernarus 15360x15360
CO_borderZones = [
    // [startPos, endPos, type]
    [[0, 7680, 0],   [0, 15360, 0],   "land"],  // West edge
    [[7680, 15360, 0],[15360,15360,0], "land"],  // North edge
    [[15360,7680,0], [15360, 0, 0],   "land"],  // East edge
    [[0, 0, 0],      [15360, 0, 0],   "boat"],  // South coast
];

// Spawn ATV patrols along land edges
{
    private _start = _x select 0;
    private _end   = _x select 1;
    private _type  = _x select 2;
    private _steps = round ((_start distance _end) / 800);

    for "_i" from 0 to _steps do {
        private _t   = _i / _steps;
        private _pos = _start vectorMultiply (1-_t) vectorAdd (_end vectorMultiply _t);
        _pos = _pos vectorAdd [random 50 - 25, random 50 - 25, 0];

        if (_type == "land") then {
            private _grp = createGroup east;
            private _atv = "O_MRAP_02_F" createVehicle _pos;
            for "_j" from 0 to 1 do {
                private _u = _grp createUnit ["O_Soldier_F", _pos, [], 2, "CARGO"];
                if (_j == 0) then { _u moveInDriver _atv; } else { _u moveInCargo _atv; };
            };
            // Patrol along border
            [_grp, _start, _end] call co_main_fnc_borderPatrolWaypoints;
        };

        if (_type == "boat") then {
            private _grp = createGroup east;
            private _boat = "O_Boat_Armed_01_hmg_F" createVehicle _pos;
            private _u = _grp createUnit ["O_Soldier_F", _pos, [], 0, "CARGO"];
            _u moveInDriver _boat;
            [_grp, _start, _end] call co_main_fnc_borderPatrolWaypoints;
        };
    };
} forEach CO_borderZones;

// Become hostile only when player spotted near border (within 150m)
addMissionEventHandler ["EachFrame", {
    {
        private _p = _x;
        if (!(captive _p) && _p distance2D [0, 7680] < 150) then { // simplified edge check
            // Alert nearest border group
            allGroups select {
                side _x == east &&
                (leader _x) distance _p < 300
            } apply { [units _x, _p] call co_main_fnc_borderAlert; };
        };
    } forEach allPlayers;
}];