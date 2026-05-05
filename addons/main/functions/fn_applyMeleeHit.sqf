// ============================================================
// fn_applyMeleeHit.sqf
// Server-side unarmed punch system. Plays a visible swing animation
// on every machine, applies non-lethal damage that caps below death,
// and on the third hit knocks the target unconscious for capture.
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
if (_attacker distance _target > 2.8) exitWith {};
if (_target getVariable ["CO_knockedOut", false]) exitWith {};

private _nextAllowedAt = _attacker getVariable ["CO_nextMeleeAt", 0];
if (time < _nextAllowedAt) exitWith {};
_attacker setVariable ["CO_nextMeleeAt", time + 0.9, false];

// --- Face the target so the swing reads correctly on every client ---
private _toTarget = (getPosWorld _target) vectorDiff (getPosWorld _attacker);
private _yaw = (_toTarget select 0) atan2 (_toTarget select 1);
[_attacker, _yaw] remoteExec ["setDir", 0];

// Visible punch animation broadcast globally so every viewer sees the swing.
// "Acts_PoloShirtConfrontation_Loop" plays a clear arm-swing motion in vanilla A3
// and overrides whatever animation the unit was in.
[_attacker, "Acts_PoloShirtConfrontation_Loop"] remoteExec ["switchMove", 0];
[_attacker] spawn {
    params ["_a"];
    sleep 0.7;
    if (!isNull _a && alive _a) then {
        [_a, ""] remoteExec ["switchMove", 0];
    };
};

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

// --- Apply non-lethal damage similar to bullets, capped well below kill ---
private _maxDamage = 0.85;
private _bodyAdd = 0.18 + random 0.08;
private _curBody = _target getHitPointDamage "HitBody";
_target setHitPointDamage ["HitBody", ((_curBody + _bodyAdd) min _maxDamage)];

private _curHead = _target getHitPointDamage "HitHead";
_target setHitPointDamage ["HitHead", ((_curHead + (_bodyAdd * 0.5)) min _maxDamage)];

if ((damage _target) > _maxDamage) then {
    _target setDamage _maxDamage;
};

// --- Visible flinch + small knock-back ---
private _pushVector = vectorNormalized _toTarget;
if !(_pushVector isEqualTo [0, 0, 0]) then {
    _target setVelocity [(_pushVector select 0) * 1.2, (_pushVector select 1) * 1.2, 0.25];
};
// Brief hand-up flinch broadcast on the target (cleared automatically by their move loop)
[_target, "AmovPercMstpSrasWrflDnon_diary"] remoteExec ["switchMove", 0];

if (!isPlayer _attacker) then {
    _attacker doMove (getPosATL _target);
};

if (_hitCount >= 3) then {
    _target setVariable ["CO_meleePunchState", [0, 0], true];

    // Final, knock-out hit: collapse animation broadcast for visibility
    [_target, "Acts_ExecutionVictim_Loop"] remoteExec ["switchMove", 0];

    [_attacker, _target, 60, false] call co_main_fnc_applyKnockout;
    if (isPlayer _attacker) then {
        ["Target knocked out."] remoteExecCall ["systemChat", owner _attacker];
    };
} else {
    if (isPlayer _attacker) then {
        [format ["Punch landed (%1/3).", _hitCount]] remoteExecCall ["systemChat", owner _attacker];
    };
};