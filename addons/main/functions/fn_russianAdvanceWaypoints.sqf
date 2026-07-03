// fn_russianAdvanceWaypoints.sqf
// Gives a Russian advance group lane-specific movement and combat patrols.
params ["_grp"];

private _lane = _grp getVariable ["CO_advanceLane", ""];
if (_lane isEqualTo "") then {
    private _leaderPos = getPosATL (leader _grp);
    _lane = switch (true) do {
        case ((_leaderPos select 1) > 10500): { "north" };
        case ((_leaderPos select 1) < 5200): { "south" };
        default { "central" };
    };
};

private _advanceRoute = switch (_lane) do {
    case "north": {
        [
            [12650, 12340, 0],
            [12100, 12320, 0],
            [11600, 12300, 0],
            [11200 + random 500 - 250, 12300 + random 500 - 250, 0],
            [12050 + random 500 - 250, 12650 + random 500 - 250, 0],
            [11200 + random 650 - 325, 13600 + random 650 - 325, 0],
            [10850 + random 450 - 225, 12200 + random 450 - 225, 0],
            [11200, 12300, 0]
        ]
    };
    case "south": {
        [
            [14050, 3300, 0],
            [12400, 3100, 0],
            [10200, 2300, 0],
            [8500, 2500, 0],
            [6400, 2400, 0]
        ]
    };
    default {
        [
            [14050, 7800, 0],
            [12800, 7500, 0],
            [12300, 9700, 0],
            [9800, 6900, 0],
            [8500, 5000, 0],
            [6400, 2400, 0]
        ]
    };
};

{
    private _wp = _grp addWaypoint [_x, 50];
    private _isNorthPatrol = _lane == "north" && { _forEachIndex >= 2 };
    _wp setWaypointType (if (_isNorthPatrol) then { "SAD" } else { "MOVE" });
    _wp setWaypointSpeed (if (_lane == "north") then { "FULL" } else { "NORMAL" });
    _wp setWaypointBehaviour "COMBAT";
    _wp setWaypointCombatMode "RED";
    _wp setWaypointCompletionRadius (if (_isNorthPatrol) then { 120 } else { 60 });
} forEach _advanceRoute;

private _lastPos = _advanceRoute select ((count _advanceRoute) - 1);
private _cycleWp = _grp addWaypoint [_lastPos, 0];
_cycleWp setWaypointType (if (_lane == "north") then { "CYCLE" } else { "HOLD" });
_cycleWp setWaypointBehaviour "COMBAT";
_cycleWp setWaypointCombatMode "RED";
