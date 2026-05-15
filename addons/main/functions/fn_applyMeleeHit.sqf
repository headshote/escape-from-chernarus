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
// playActionNow uses gesture layers that don't get cancelled by the player's
// movement state (unlike switchMove which is overridden the next frame). We
// alternate "GestureGo" / "GestureFollow" / "GestureCeaseFire" so successive
// punches read as different swings and a final knockout animation reads as
// distinct from the in-progress swings.
// Visible swing: combine a body action with a gesture overlay so the
// punch reads on every viewer regardless of stance. We pick from a few
// known gestures + a small body lunge.
private _swingGesture = selectRandom ["GestureGo", "GestureFollow", "GestureCeaseFire", "GestureAttack"];
[_attacker, _swingGesture] remoteExec ["playActionNow", 0];
[_attacker, "PutDown"] remoteExec ["playAction", 0];

// Audible punch hit cue, broadcast globally
playSound3D [
    "A3\Sounds_F\characters\human-sfx\other\Body_Fall1.wss",
    _target, false, getPosASL _target, 1.6, 1, 25
];

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
// Short flinch gesture broadcast on the target. playActionNow layers on top of
// the existing animation so it reads as a hit reaction without freezing them
// in place.
[_target, "GestureNo"] remoteExec ["playActionNow", 0];

if (!isPlayer _attacker) then {
    _attacker doMove (getPosATL _target);
};

if (_hitCount >= 3) then {
    _target setVariable ["CO_meleePunchState", [0, 0], true];

    // Final, knock-out hit: collapse animation broadcast for visibility.
    // Acts_ExecutionVictim_Loop reads as a downed-on-knees pose.
    [_target, "Acts_ExecutionVictim_Loop"] remoteExec ["switchMove", 0];
    [_attacker, "GestureFreeze"] remoteExec ["playActionNow", 0];

    [_attacker, _target, 60, false] call co_main_fnc_applyKnockout;
    if (isPlayer _attacker) then {
        ["Target knocked out."] remoteExecCall ["systemChat", owner _attacker];
    };
} else {
    if (isPlayer _attacker) then {
        [format ["Punch landed (%1/3).", _hitCount]] remoteExecCall ["systemChat", owner _attacker];
    };
};