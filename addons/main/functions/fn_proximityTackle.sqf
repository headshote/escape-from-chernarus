// ============================================================
// fn_proximityTackle.sqf — sustained-proximity grab detector
// (server-side)
//
// Replaces "3 melee hits at < 2.8 m with a 0.9 s cooldown inside
// an 8 s window" as the CHASE capture condition — which was
// essentially impossible to land on a sprinting player. A chaser
// who stays within tackle range for a cumulative ~1.5 s now
// triggers a grab; the caller (fn_pursuitChase) decides what a
// grab means (wrangle minigame for players, knockout for NPCs).
//
// fn_applyMeleeHit stays as the player-initiated melee system.
//
// State (server-local, on the target):
//   CO_tackleCharge      [accumulatedSeconds, lastTickTime]
//   CO_tackleImmuneUntil grace window after a won wrangle so the
//                        head-start is real
//
// params: [_chasers (on-foot units), _target]
// returns: BOOL — true exactly once when the tackle triggers
// ============================================================
params [
    ["_chasers", []],
    ["_target", objNull]
];

if (isNull _target || !alive _target) exitWith { false };
if (_chasers isEqualTo []) exitWith { false };

// Can't tackle someone inside a vehicle, and a downed/captive
// target needs no tackle.
if (vehicle _target != _target) exitWith { false };
if (captive _target || (_target getVariable ["CO_knockedOut", false])) exitWith { false };
if (time < (_target getVariable ["CO_tackleImmuneUntil", 0])) exitWith { false };

private _range = missionNamespace getVariable ["CO_chase_tackleRange", 2.2];
private _need  = missionNamespace getVariable ["CO_chase_tackleTime", 1.5];

private _state = _target getVariable ["CO_tackleCharge", [0, time]];
_state params ["_charge", "_lastAt"];
private _dt = (time - _lastAt) min 2;

private _inRange = false;
{
    if (alive _x && vehicle _x == _x && (_x distance _target) <= _range) exitWith {
        _inRange = true;
    };
} forEach _chasers;

if (_inRange) then {
    _charge = _charge + _dt;
} else {
    _charge = (_charge - (_dt * 1.5)) max 0;
};

if (_charge >= _need) exitWith {
    _target setVariable ["CO_tackleCharge", [0, time], false];
    true
};

_target setVariable ["CO_tackleCharge", [_charge, time], false];
false
