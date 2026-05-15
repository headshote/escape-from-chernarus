// ============================================================
// fn_spawnDetentionGuards.sqf
// Spawns guards around a detention center position.
// params: [_pos]
// ============================================================
params ["_pos"];

private _guardedCenters = missionNamespace getVariable ["CO_guardedDetentionCenters", []];
private _guardKey = format ["%1_%2", round (_pos select 0), round (_pos select 1)];

// Avoid respawning if already guarded
if (_guardKey in _guardedCenters) exitWith {};
_guardedCenters pushBack _guardKey;
missionNamespace setVariable ["CO_guardedDetentionCenters", _guardedCenters];

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
    _wp1 setWaypointType "MOVE";
    private _wp2 = _grp addWaypoint [_pos getPos [22, _angle - 30], 5];
    _wp2 setWaypointType "CYCLE";
    // Active scan so escape attempts are spotted immediately
    [_grp, _pos, 60, "CRN_ENF"] call co_main_fnc_guardAggroLoop;
};

// Roving interior patrol group
[_pos, 15, 3, "CRN_ENF"] call co_main_fnc_spawnRovingGuards;