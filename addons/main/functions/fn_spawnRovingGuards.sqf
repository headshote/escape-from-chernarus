// ============================================================
// fn_spawnRovingGuards.sqf
// For open areas like the airfield interior.
// ============================================================

params ["_center", "_radius", "_count", "_faction"];

private _grp = createGroup west;
_grp setVariable ["CO_faction", _faction];

for "_i" from 0 to (_count - 1) do {
    private _angle = random 360;
    private _dist  = random _radius;
    private _pos   = _center getPos [_dist, _angle];
    private _u     = _grp createUnit ["B_Soldier_F", _pos, [], 3, "FORM"];
    [_u] call co_main_fnc_initHostileUnit;
};

// Random roving waypoints within the compound
for "_w" from 0 to 5 do {
    private _wPos  = _center getPos [random (_radius * 0.8), random 360];
    private _wp    = _grp addWaypoint [_wPos, 20];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
};
private _cycleWp = _grp addWaypoint [_center, 0];
_cycleWp setWaypointType "CYCLE";

_grp