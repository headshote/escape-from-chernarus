// ============================================================
// fn_borderPatrolWaypoints.sqf
// Gives a group back-and-forth patrol waypoints along a border segment.
// params: [_grp, _startPos, _endPos]
// ============================================================
params ["_grp", "_startPos", "_endPos"];

// Break the segment into ~5 patrol waypoints
private _steps = 5;
for "_i" from 0 to _steps do {
    private _t   = _i / _steps;
    private _pos = _startPos vectorMultiply (1 - _t) vectorAdd (_endPos vectorMultiply _t);
    _pos = _pos vectorAdd [random 20 - 10, random 20 - 10, 0];
    private _wp = _grp addWaypoint [_pos, 20];
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointType "MOVE";
};
// Return waypoint
private _returnWp = _grp addWaypoint [_startPos vectorAdd [random 20 - 10, random 20 - 10, 0], 20];
_returnWp setWaypointType "CYCLE";
