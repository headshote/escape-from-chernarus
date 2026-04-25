// fn_frontCollapse.sqf — when front is broken
// Surviving front units retreat west, some defect to Resistance

allGroups select { _x getVariable ["CO_faction",""] == "CRN_FRONT" } apply {
    private _grp = _x;
    clearWaypoints _grp;
    private _retreatPos = [3000 + random 2000, 3000 + random 5000, 0]; // west
    private _wp = _grp addWaypoint [_retreatPos, 50];
    _wp setWaypointType "MOVE";
    _wp setWaypointSpeed "FULL";

    // 30% chance each unit defects to Resistance on retreat
    { if (random 1 < 0.3) then { [_x] joinGroup createGroup west; group _x setVariable ["CO_faction","RESIST"]; }; } forEach units _grp;
};

// Broadcast to all players
["CO_frontCollapsed", true] remoteExec ["publicVariable", -2];
hint "THE FRONT HAS COLLAPSED — Russian forces are advancing on all towns.";