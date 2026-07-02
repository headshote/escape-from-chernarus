// ============================================================
// fn_releaseUnit.sqf — engagement arbiter release (server-side)
//
// Releases a unit claimed via fn_claimUnit, but ONLY if the
// caller still holds the claim (token match). If a higher-
// priority controller stole the unit in the meantime, this is a
// no-op so we never clobber the new owner's state.
//
// Also resets the chase sprint coefficient applied by
// fn_chaseMove, so released units go back to normal move speed.
//
// params: [_unit, _token]
// ============================================================
params [
    ["_unit", objNull],
    ["_token", ""]
];

if (isNull _unit || _token == "") exitWith {};

private _cur = _unit getVariable ["CO_claim", []];
if (_cur isEqualTo []) exitWith {};
if ((_cur select 0) != _token) exitWith {};

_unit setVariable ["CO_claim", nil, false];
_unit setVariable ["CO_chaseDest", nil, false];
_unit setVariable ["CO_chaseOrderAt", nil, false];
_unit setVariable ["CO_chasePosture", nil, false];
if (alive _unit) then {
    _unit setAnimSpeedCoef 1;
    _unit setVariable [
        "CO_aiStamina",
        ((_unit getVariable ["CO_aiStamina", 100]) + 35) min 100,
        false
    ];
};
