// ============================================================
// fn_buildBorderForts.sqf
// Stamps watchtowers and outposts around map perimeter.
// Spacing and density from admin panel.
// ============================================================

params [
    ["_spacing",       600],   // meters between posts
    ["_includeCoast",  true],
    ["_includeLand",   true]
];

// Border segments: [start, end, facing direction]
CO_borderSegments = [
    [[200,   200,  0], [200,  14800, 0], 270,  "land"],   // West edge, face west
    [[200,  14800, 0], [14800,14800, 0], 0,    "land"],   // North edge, face north
    [[14800,14800, 0], [14800,  200, 0], 90,   "land"],   // East edge  (Russian side — skip)
    [[200,   200,  0], [14800,  200, 0], 180,  "coast"]   // South coast, face south
];

{
    private _start  = _x select 0;
    private _end    = _x select 1;
    private _facing = _x select 2;
    private _type   = _x select 3;

    if (_type == "coast" && !_includeCoast) then { continue };
    if (_type == "land"  && !_includeLand)  then { continue };
    if (_type == "land"  && (_x select 2 == 90)) then { continue }; // skip east (Russian spawn)

    private _totalDist = _start distance _end;
    private _steps     = floor (_totalDist / _spacing);

    for "_i" from 0 to _steps do {
        private _t   = _i / _steps;
        private _pos = _start vectorMultiply (1 - _t) vectorAdd (_end vectorMultiply _t);
        _pos = _pos vectorAdd [random 30 - 15, random 30 - 15, 0];

        // Alternate tower and outpost
        private _template = if (_i % 3 == 0) then {"border_outpost"} else {"border_tower"};
        [_pos, _facing, _template] call co_main_fnc_stampFortification;

        // Spawn border guards
        [_pos, _facing, "CRN_ENF"] call co_main_fnc_spawnFortGuards;
    };

} forEach CO_borderSegments;