// ============================================================
// fn_spawnDetentionGuards.sqf
// Spawns guards around a detention center position.
// params: [_pos]
// ============================================================
params ["_pos"];

// Avoid respawning if already guarded
if (_pos getVariable ["CO_guardsSpawned", false]) exitWith {};
_pos setVariable ["CO_guardsSpawned", true];

// Perimeter guards
for "_i" from 0 to 5 do {
    private _angle = _i * 60;
    private _gPos  = _pos getPos [20, _angle];
    private _grp   = createGroup west;
    _grp setVariable ["CO_faction", "CRN_ENF"];
    private _u = _grp createUnit ["B_Soldier_F", _gPos, [], 2, "FORM"];
    [_u] call co_main_fnc_initHostileUnit;
    // Short patrol loop around their post
    private _wp1 = _grp addWaypoint [_pos getPos [22, _angle + 30], 5];
    _wp1 setWaypointType "CYCLE";
    private _wp2 = _grp addWaypoint [_pos getPos [22, _angle - 30], 5];
    _wp2 setWaypointType "CYCLE";
};

// Roving interior patrol group
[_pos, 15, 3, "CRN_ENF"] call co_main_fnc_spawnRovingGuards;