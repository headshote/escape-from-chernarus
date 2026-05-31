// ============================================================
// fn_alertEnforcers.sqf
// Alerts the nearest Enforcer group to a given position.
// params: [_pos]
// ============================================================
params ["_pos"];

private _nearEnforcers = allGroups select {
    _x getVariable ["CO_faction",""] == "CRN_ENF" &&
    count (units _x) > 0 &&
    (leader _x) distance _pos < 800
};

if (count _nearEnforcers == 0) exitWith {};

private _closest = [_nearEnforcers, [], { (leader _x) distance _pos }, "ASCEND"] call BIS_fnc_sortBy;
private _grp = _closest select 0;

{
    _x setCombatMode "RED";
    _x setBehaviour "COMBAT";
    _x doMove _pos;
} forEach units _grp;
