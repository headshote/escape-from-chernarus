// fn_russianAdvanceWaypoints.sqf
// Gives a group a series of westward road-following waypoints
params ["_grp"];

// Pre-baked advance corridor waypoints (road-following, west direction)
private _advanceRoute = [
    [14500, 7800, 0],  // East coast road
    [12800, 7500, 0],  // Approach Berezino
    [11600, 7800, 0],  // Berezino
    [10200, 7200, 0],  // Elektrozavodsk approach
    [8500,  5000, 0],  // Central corridor
    [6400,  2400, 0],  // Chernogorsk
];

{
    private _wp = _grp addWaypoint [_x, 30];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "LIMITED";
    _wp setWaypointBehaviour "COMBAT";
    _wp setWaypointCombatMode "YELLOW";
} forEach _advanceRoute;

// Final hold
private _holdWp = _grp addWaypoint [_advanceRoute select (count _advanceRoute - 1), 0];
_holdWp setWaypointType "HOLD";