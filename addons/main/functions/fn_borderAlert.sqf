// ============================================================
// fn_borderAlert.sqf
// Makes a list of border patrol units pursue a specific target.
// params: [_units, _target]
// ============================================================
params ["_units", "_target"];

{
    _x doTarget _target;
    _x doMove getPosATL _target;
    _x setCombatMode "RED";
    _x setBehaviour "COMBAT";
} forEach _units;

// Capture check — same pattern as checkpoint
[_target, group (_units select 0)] spawn {
    params ["_target", "_grp"];
    waitUntil {
        sleep 0.5;
        private _nearest = units _grp select { alive _x };
        if (count _nearest == 0) exitWith { true };
        private _sorted = [_nearest, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
        if ((_sorted select 0) distance _target < 2.5) then {
            [_target] remoteExecCall ["co_main_fnc_wrangleMinigame", _target];
            waitUntil { !isNil { _target getVariable "CO_wrangleResult" } };
            private _result = _target getVariable ["CO_wrangleResult", "captured"];
            _target setVariable ["CO_wrangleResult", nil, true];
            if (_result == "captured") then {
                _target setCaptive true;
                [_target, _grp] call co_main_fnc_transportToDetention;
            };
            true
        } else {
            false
        };
    };
};