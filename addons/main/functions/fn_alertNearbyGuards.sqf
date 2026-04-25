// ============================================================
// fn_alertNearbyGuards.sqf
// Alerts all guards within 60m of a position (used by lockpick
// failure to wake detention guards).
// params: [_pos]
// ============================================================
params ["_pos"];

{
    if (_x getVariable ["CO_faction",""] in ["CRN_ENF","POLICE"]) then {
        if ((leader _x) distance _pos < 60) then {
            { _x setCombatMode "RED"; _x setBehaviour "COMBAT"; _x doMove _pos; } forEach units _x;
        };
    };
} forEach allGroups;
