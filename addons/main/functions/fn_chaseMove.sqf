// ============================================================
// fn_chaseMove.sqf — chase movement kit (server-side)
//
// Replaces the old "everyone doMove target-pos every second"
// pattern, which had three problems:
//   1. re-issuing doMove every tick makes AI pause ~0.5 s to
//      re-path → visible stutter and lost ground;
//   2. all chasers converge on the same point → conga-line the
//      target simply outruns;
//   3. AI foot speed ≈ player sprint → chases never close.
//
// What this does per call (call it every chase tick, ~0.7 s):
//   - orders go to a PREDICTED INTERCEPT point (target pos +
//     velocity × time-to-reach, capped) instead of current pos;
//   - a doMove is only re-issued when the desired destination
//     drifted > 10 m from the last order (or every 6 s as a
//     keep-alive), so pathing is never thrashed;
//   - chaser 0 (nearest) runs direct intercept, chasers 1..4 get
//     cordon offsets fanned ±55°/±115° around the target's flight
//     vector so the pack cuts off flight instead of tailing;
//   - every chaser gets setAnimSpeedCoef CO_chase_speedCoef
//     (default 1.12) — slightly faster than a sprinting player,
//     so escapes come from breaking line-of-sight and endurance,
//     not raw speed. fn_releaseUnit resets the coefficient.
//
// params: [_chasers (on-foot units), _target]
// ============================================================
params [
    ["_chasers", []],
    ["_target", objNull]
];

if (isNull _target) exitWith {};
if (_chasers isEqualTo []) exitWith {};

private _speedCoef = missionNamespace getVariable ["CO_chase_speedCoef", 1.12];
private _staminaDrain = missionNamespace getVariable ["CO_chase_aiStaminaDrain", 0.42];

private _tgtVeh = vehicle _target;
private _tgtPos = getPosATL _tgtVeh;
private _vel = velocity _tgtVeh;
_vel set [2, 0];
private _speed = vectorMagnitude _vel;

// Flight direction: target velocity, or away-from-nearest-chaser
// when the target is standing still.
private _flightDir = if (_speed > 0.5) then {
    vectorNormalized _vel
} else {
    private _away = _tgtPos vectorDiff (getPosATL (_chasers select 0));
    _away set [2, 0];
    if ((vectorMagnitude _away) < 0.1) then { [1,0,0] } else { vectorNormalized _away }
};

// Sort so role 0 = nearest (direct intercept), outer roles cordon.
private _sorted = [_chasers, [], { _x distance2D _target }, "ASCEND"] call BIS_fnc_sortBy;

// Cordon fan angles relative to the flight vector (degrees).
private _fan = [0, 55, -55, 115, -115];

{
    private _u = _x;
    if (alive _u && vehicle _u == _u) then {

        // One-time chase posture. Never re-applied per tick — that
        // is exactly the command spam this kit exists to remove.
        if !(_u getVariable ["CO_chasePosture", false]) then {
            _u setVariable ["CO_chasePosture", true, false];
            _u setBehaviour "AWARE";
            _u setUnitPos "UP";
            _u enableAI "MOVE";
            _u enableAI "PATH";
            _u forceSpeed -1;
        };
        // Predicted intercept for this chaser.
        private _dist = _u distance2D _tgtVeh;
        private _stamina = _u getVariable ["CO_aiStamina", 100];
        private _drain = _staminaDrain + ((_dist min 80) / 260);
        _stamina = (_stamina - _drain) max 25;
        _u setVariable ["CO_aiStamina", _stamina, false];

        private _staminaFactor = linearConversion [25, 100, _stamina, 0.45, 1, true];
        private _effectiveCoef = 1 + ((_speedCoef - 1) * _staminaFactor);
        _u setAnimSpeedCoef _effectiveCoef;

        private _tta = (_dist / (5.0 * _effectiveCoef)) min 3.5;  // ~AI sprint m/s
        private _lead = _tgtPos vectorAdd (_vel vectorMultiply _tta);

        // Cordon offset for outer roles: a point ahead of the
        // target, rotated off the flight axis.
        private _angle = _fan select ((_forEachIndex min 4));
        private _dest = if (_angle == 0) then {
            _lead
        } else {
            private _dx = _flightDir select 0;
            private _dy = _flightDir select 1;
            private _rot = [
                _dx * cos _angle - _dy * sin _angle,
                _dx * sin _angle + _dy * cos _angle,
                0
            ];
            _lead vectorAdd (_rot vectorMultiply 14)
        };

        // Re-issue only when the destination meaningfully moved.
        private _lastDest = _u getVariable ["CO_chaseDest", [0,0,0]];
        private _lastAt   = _u getVariable ["CO_chaseOrderAt", 0];
        if ((_dest distance2D _lastDest) > 10 || (time - _lastAt) > 6) then {
            _u doMove _dest;
            _u setVariable ["CO_chaseDest", _dest, false];
            _u setVariable ["CO_chaseOrderAt", time, false];
        };
    };
} forEach _sorted;
