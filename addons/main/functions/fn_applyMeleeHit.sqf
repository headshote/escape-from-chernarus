// ============================================================
// fn_applyMeleeHit.sqf
// Server-side unarmed punch system. Repeated punches within a short window
// knock the target out instead of causing lethal damage.
// ============================================================
params [
    ["_attacker", objNull],
    ["_target", objNull]
];

if (!isServer) exitWith {
    [_attacker, _target] remoteExecCall ["co_main_fnc_applyMeleeHit", 2];
};

if (isNull _attacker || isNull _target) exitWith {};
if (!alive _attacker || !alive _target) exitWith {};
if (!(_attacker isKindOf "CAManBase") || !(_target isKindOf "CAManBase")) exitWith {};
if (_attacker == _target) exitWith {};
if (vehicle _attacker != _attacker || vehicle _target != _target) exitWith {};
if (_attacker distance _target > 2.6) exitWith {};
if (_target getVariable ["CO_knockedOut", false]) exitWith {};

private _nextAllowedAt = _attacker getVariable ["CO_nextMeleeAt", 0];
if (time < _nextAllowedAt) exitWith {};
_attacker setVariable ["CO_nextMeleeAt", time + 0.9, false];

private _punchState = _target getVariable ["CO_meleePunchState", [0, 0]];
private _hitCount = _punchState select 0;
private _lastHitAt = _punchState select 1;
if ((time - _lastHitAt) > 8) then {
    _hitCount = 0;
};

_hitCount = _hitCount + 1;
_target setVariable ["CO_meleePunchState", [_hitCount, time], true];

if (!isPlayer _target) then {
    _target setVariable ["CO_civState", "fleeing", false];
    _target setVariable ["CO_civAlertUntil", time + 12, false];
};

private _pushVector = vectorNormalized ((getPosWorld _target) vectorDiff (getPosWorld _attacker));
if !(_pushVector isEqualTo [0, 0, 0]) then {
    _target setVelocity [(_pushVector select 0) * 0.9, (_pushVector select 1) * 0.9, 0.18];
};

if (_hitCount >= 3) then {
    _target setVariable ["CO_meleePunchState", [0, 0], true];
    [_attacker, _target, 60, false] call co_main_fnc_applyKnockout;
    if (isPlayer _attacker) then {
        ["Target knocked out."] remoteExecCall ["systemChat", owner _attacker];
    };
} else {
    if (isPlayer _attacker) then {
        [format ["Punch landed (%1/3).", _hitCount]] remoteExecCall ["systemChat", owner _attacker];
    };
};