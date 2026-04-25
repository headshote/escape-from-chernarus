// ============================================================
// fn_spawnFortGuards.sqf
// Spawns a guard group at a fortification position.
// _faction: "CRN_ENF" | "CRN_FRONT"
// ============================================================

params ["_pos", "_dir", "_faction"];

private _side     = west; // both ENF and FRONT are BLUFOR
private _unitPool = ["B_Soldier_F","B_Soldier_AR_F","B_Soldier_TL_F"];
private _count    = switch (_faction) do {
    case "CRN_ENF":   { CO_checkpoint_hostilesPerPost };
    case "CRN_FRONT": { 5 };
    default           { 4 };
};

private _grp = createGroup _side;
_grp setVariable ["CO_faction", _faction];

for "_i" from 0 to (_count - 1) do {
    private _offset = [
        [3, _dir + 80],  [3, _dir + 280],
        [6, _dir],       [6, _dir + 180],
        [9, _dir + 90],  [1, _dir + 270]
    ] select (_i min 5);
    private _uPos = _pos getPos _offset;
    private _u    = _grp createUnit [selectRandom _unitPool, _uPos, [], 1, "FORM"];
    [_u] call co_main_fnc_initHostileUnit;
};

// Short patrol around fortification
private _wp1 = _grp addWaypoint [_pos getPos [15, _dir + 90],  0]; _wp1 setWaypointType "CYCLE";
private _wp2 = _grp addWaypoint [_pos getPos [15, _dir + 270], 0]; _wp2 setWaypointType "CYCLE";