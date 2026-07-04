// fn_russianAdvanceWaypoints.sqf
// Commits a RUS_ADV group to the Krasnostav siege: assault in from wherever
// it spawned, then perpetually SAD-patrol the town <-> airstrip line so it
// keeps hunting deployed conscripts / CRN_FRONT and never marches off west
// (the old north/central/south routes drained forces toward Chernogorsk and
// left Krasnostav empty for players arriving later).
params ["_grp"];
if (isNull _grp) exitWith {};

private _townPos  = missionNamespace getVariable ["CO_rus_townPos",  [11200, 12300, 0]];
private _airstrip = missionNamespace getVariable ["CO_rus_airstripPos", [11600, 13050, 0]];

// Clear any prior waypoints (safe on a fresh group too).
for "_i" from ((count (waypoints _grp)) - 1) to 0 step -1 do {
    deleteWaypoint [_grp, _i];
};

// Alternating town / airstrip sweep — this is the ground they hold.
private _route = [
    _townPos  vectorAdd [(random 220) - 110, (random 220) - 110, 0],
    _airstrip vectorAdd [(random 320) - 160, (random 200) - 100, 0],
    _townPos  vectorAdd [(random 300) - 150, (random 300) - 150, 0],
    _airstrip vectorAdd [(random 260) - 130, (random 220) - 110, 0]
];

{
    private _wp = _grp addWaypoint [_x, 40];
    _wp setWaypointType "SAD";
    _wp setWaypointSpeed (if (_forEachIndex == 0) then { "FULL" } else { "LIMITED" });
    _wp setWaypointBehaviour "COMBAT";
    _wp setWaypointCombatMode "RED";
    _wp setWaypointCompletionRadius 90;
} forEach _route;

private _cyc = _grp addWaypoint [_townPos, 0];
_cyc setWaypointType "CYCLE";
_cyc setWaypointBehaviour "COMBAT";
_cyc setWaypointCombatMode "RED";
_cyc setWaypointCompletionRadius 120;
