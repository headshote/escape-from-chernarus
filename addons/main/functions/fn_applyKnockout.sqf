// ============================================================
// fn_applyKnockout.sqf
// Server-side non-lethal knockout used by player melee and bus captures.
// ============================================================
params [
    ["_attacker", objNull],
    ["_target", objNull],
    ["_duration", 60],
    ["_keepCaptive", false],
    ["_requireCloseAttacker", true]
];

if (!isServer) exitWith {
    [_attacker, _target, _duration, _keepCaptive, _requireCloseAttacker] remoteExecCall ["co_main_fnc_applyKnockout", 2];
};

if (isNull _target || !alive _target || !(_target isKindOf "CAManBase")) exitWith {};
if (_target getVariable ["CO_knockedOut", false]) exitWith {};

// NOTE: these guards must exit the FUNCTION, not a then{} block. exitWith
// inside `then {}` only leaves the block, so the knockout would still run
// for a dead or out-of-range attacker.
if (!isNull _attacker && {!alive _attacker}) exitWith {};
if (_requireCloseAttacker && {!isNull _attacker && {(_attacker distance _target) > 3}}) exitWith {};

_duration = (_duration max 5) min 120;

_target setVariable ["CO_knockedOut", true, true];
_target setVariable ["CO_knockedOutUntil", time + _duration, true];
_target setVariable ["CO_knockoutPersistentCaptive", _keepCaptive, true];
_target setCaptive true;
_target setUnconscious true;

if (!isPlayer _target) then {
    _target disableAI "MOVE";
    _target disableAI "PATH";
    _target disableAI "AUTOTARGET";
    _target disableAI "TARGET";
};

[_target, _duration, _keepCaptive] spawn {
    params ["_target", "_duration", "_keepCaptive"];

    sleep _duration;

    if (isNull _target || !alive _target) exitWith {};

    _target setUnconscious false;
    _target setVariable ["CO_knockedOut", false, true];

    if (!isPlayer _target) then {
        _target enableAI "MOVE";
        _target enableAI "PATH";
        _target enableAI "AUTOTARGET";
        _target enableAI "TARGET";
    };

    if (!_keepCaptive) then {
        _target setCaptive false;
    };
};
