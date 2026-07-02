// ============================================================
// fn_setEscalationState.sqf
// Shared doctrine helper: records the current security posture for
// a suspect and optional group, publishes heat, and gives clients a
// readable state for HUD/stingers.
// States: UNAWARE, SUSPICIOUS, PURSUIT, WEAPONS, LETHAL, SEARCH, CLEAR
// params: [_target, _state, _source, _heat, _grp]
// ============================================================
params [
    ["_target", objNull],
    ["_state", "UNAWARE"],
    ["_source", "unknown"],
    ["_heat", 0],
    ["_grp", grpNull]
];

if (isNull _target) exitWith {};

private _old = _target getVariable ["CO_escalationState", "UNAWARE"];
_target setVariable ["CO_escalationState", _state, true];
_target setVariable ["CO_escalationSource", _source, true];
_target setVariable ["CO_escalationUntil", time + 90, true];
_target setVariable ["CO_heatLevel", ((_target getVariable ["CO_heatLevel", 0]) max _heat), true];

if (!isNull _grp) then {
    _grp setVariable ["CO_escalationState", _state, true];
    _grp setVariable ["CO_escalationTarget", _target, false];
};

if (isServer && _state != "CLEAR") then {
    [_target, getPosATL (vehicle _target), _source, _heat] call co_main_fnc_alertPublish;
};

if (isPlayer _target && _old != _state) then {
    [_state, _target] call co_main_fnc_chaseStinger;
};

_state
