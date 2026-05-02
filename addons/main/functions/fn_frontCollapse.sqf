// fn_frontCollapse.sqf - when front is broken
// Surviving front units retreat west, some defect to Resistance

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
                _resistanceGrp setVariable ["CO_faction", "RESIST"];
            };
            [_x] joinSilent _resistanceGrp;
        };
    } forEach units _grp;
} forEach (allGroups select { _x getVariable ["CO_faction",""] == "CRN_FRONT" });

// Broadcast to all players
CO_frontCollapsed = true;
publicVariable "CO_frontCollapsed";
["THE FRONT HAS COLLAPSED - Russian forces are advancing on all towns."] remoteExecCall ["hint", 0];