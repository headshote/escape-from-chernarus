// fn_frontCollapse.sqf - when front is broken
// Surviving front units retreat west, some defect to Resistance

// Idempotency guard: this is invoked from every CRN_FRONT "Killed" handler
// once the survivor count drops to/below 10, so without this it would run
// up to ~10 times — re-deleting waypoints, re-rolling defection until the
// whole line defects, and spamming the global collapse hint. Run once.
if (missionNamespace getVariable ["CO_frontCollapsed", false]) exitWith {};
CO_frontCollapsed = true;
publicVariable "CO_frontCollapsed";

{
    private _grp = _x;
    private _waypointCount = count (waypoints _grp);
    if (_waypointCount > 0) then {
        for "_waypointIndex" from (_waypointCount - 1) to 0 step -1 do {
            deleteWaypoint [_grp, _waypointIndex];
        };
    };
    private _retreatPos = [3000 + random 2000, 3000 + random 5000, 0]; // west
    private _wp = _grp addWaypoint [_retreatPos, 50];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";

    // 30% chance each unit defects to Resistance on retreat
    private _resistanceGrp = grpNull;
    {
        if (random 1 < 0.3) then {
            if (isNull _resistanceGrp) then {
                _resistanceGrp = createGroup resistance;
                _resistanceGrp setVariable ["CO_faction", "RESIST", true];
            };
            [_x] joinSilent _resistanceGrp;
        };
    } forEach units _grp;
} forEach (allGroups select { _x getVariable ["CO_faction",""] == "CRN_FRONT" });

// Broadcast to all players (flag already set + broadcast at top)
["THE FRONT HAS COLLAPSED - Russian forces are advancing on all towns."] remoteExecCall ["hint", 0];
