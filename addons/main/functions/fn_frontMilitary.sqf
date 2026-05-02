// fn_frontMilitary.sqf — spawns the initial CRN_FRONT defense line

if (isNil "CO_front_initialStrength") then { CO_front_initialStrength = 60; };
CO_front_unitsRemaining  = 0;
publicVariable "CO_front_unitsRemaining";

// Defense line positions (east side, west of Russian spawn)
CO_frontDefensePositions = [
    [13800, 8100, 0],
    [13200, 6800, 0],
    [12900, 5200, 0],
    [13500, 3600, 0]
];

private _totalStrength = (missionNamespace getVariable ["CO_front_initialStrength", 60]) max 1;
private _unitsPerNode = (ceil (_totalStrength / ((count CO_frontDefensePositions) max 1))) max 1;

{
    private _pos = _x;
    private _grp = createGroup west;
    _grp setVariable ["CO_faction", "CRN_FRONT"];

    for "_i" from 1 to _unitsPerNode do {
        private _u = _grp createUnit ["B_Soldier_F", _pos, [], 15, "FORM"];
        CO_front_unitsRemaining = CO_front_unitsRemaining + 1;
        // Track death to update counter
        _u addEventHandler ["Killed", {
            CO_front_unitsRemaining = CO_front_unitsRemaining - 1;
            publicVariable "CO_front_unitsRemaining";
            // If total collapses — all remaining front groups retreat westward
            if (CO_front_unitsRemaining <= 10) then {
                [] call co_main_fnc_frontCollapse;
            };
        }];
    };

    // Dig-in behavior: fortify position, engage east
    private _wpHold = _grp addWaypoint [_pos, 0];
    _wpHold setWaypointType "HOLD";
    _wpHold setWaypointBehaviour "COMBAT";
    _wpHold setWaypointCombatMode "RED";

} forEach CO_frontDefensePositions;

publicVariable "CO_front_unitsRemaining";