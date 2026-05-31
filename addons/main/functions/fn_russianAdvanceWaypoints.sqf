// fn_russianAdvanceWaypoints.sqf
// Gives a group a series of westward road-following waypoints
params ["_grp"];

private _lane = _grp getVariable ["CO_advanceLane", ""];
if (_lane isEqualTo "") then {
    private _leaderPos = getPosATL (leader _grp);
    _lane = switch (true) do {
        case ((_leaderPos select 1) > 10500): { "north" };
        case ((_leaderPos select 1) < 5200):  { "south" };
        default                               { "central" };
    };
};

private _advanceRoute = switch (_lane) do {
    case "north": {
        // Closer-to-Krasnostav spawn arm. The first waypoint is set to
        // start near the new northern spawn (CO_rus_spawnXNorth ~12800),
        // then steps straight onto the Krasnostav combat axis.
        [
            [12700, 12340, 0],
            [12100, 12320, 0],
            [11600, 12300, 0],
            [11200, 12300, 0],  // Krasnostav combat axis
            [10000, 11600, 0],
            [ 8500, 10200, 0],
            [ 7300,  7900, 0]
        ]
    };
    case "south": {
        [
            [14050,  3300, 0],
            [12400,  3100, 0],
            [10200,  2300, 0],  // Elektro
            [ 8500,  2500, 0],
            [ 6400,  2400, 0]   // Chernogorsk
        ]
    };
    default {
        [
            [14050,  7800, 0],
            [12800,  7500, 0],
            [12300,  9700, 0],  // Berezino
            [ 9800,  6900, 0],
            [ 8500,  5000, 0],
            [ 6400,  2400, 0]
        ]
    };
};

{
    private _wp = _grp addWaypoint [_x, 30];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "NORMAL";
    _wp setWaypointBehaviour "COMBAT";
    _wp setWaypointCombatMode "RED";
} forEach _advanceRoute;

// Final hold
private _holdWp = _grp addWaypoint [_advanceRoute select (count _advanceRoute - 1), 0];
_holdWp setWaypointType "HOLD";