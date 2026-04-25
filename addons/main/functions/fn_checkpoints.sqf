// fn_checkpoints.sqf
// Spawns hostile military groups at road checkpoints.
// Checkpoint positions defined as array of [pos, roadDir].

CO_checkpointDefs = [
    [[3691, 5842, 0], 45],   // Road N of Elektrozavodsk
    [[7200, 7800, 0], 90],   // Stary Sobor crossroads
    [[11300, 7500, 0], 0],   // Berezino south approach
    // ... add ~20 total
];

{
    private _pos    = _x select 0;
    private _dir    = _x select 1;
    private _grpSize = CO_checkpoint_hostilesPerPost;

    // Spawn barrier objects
    private _barrier1 = "Land_CncBarrierMedium4_F" createVehicle (_pos vectorAdd [5, 0, 0]);
    private _barrier2 = "Land_CncBarrierMedium4_F" createVehicle (_pos vectorAdd [-5, 0, 0]);

    // Spawn hostile group
    private _grp = createGroup east;
    for "_i" from 1 to _grpSize do {
        private _unit = _grp createUnit ["O_Soldier_F", _pos, [], 5, "FORM"];
        _unit setUnitPos "UP";
        [_unit] call co_main_fnc_initHostileUnit;
    };

    // Patrol waypoints around checkpoint
    private _wp = _grp addWaypoint [_pos vectorAdd [10, 10, 0], 0];
    _wp setWaypointType "CYCLE";
    _wp = _grp addWaypoint [_pos vectorAdd [-10, -10, 0], 0];
    _wp setWaypointType "CYCLE";

    // Aggro trigger: detect players/civilian males within 80m
    private _trigger = createTrigger ["EmptyDetector", _pos];
    _trigger setTriggerArea [80, 80, 0, false];
    _trigger setTriggerActivation ["WEST", "PRESENT", true]; // West = blufor civilians
    _trigger setTriggerStatements [
        "thisList findIf { isPlayer _x || side _x == civilian } > -1",
        "[thisList, " + str _grp + "] call co_main_fnc_checkpointAlert;",
        ""
    ];
} forEach CO_checkpointDefs;