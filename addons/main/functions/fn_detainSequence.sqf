// ============================================================
// fn_detainSequence.sqf — the physical arrest beat (server-side)
//
// "No telekinetic detainment." Before a captive is teleported into
// a transport, an arresting officer must physically reach arm's
// length, and the detainee is forced to their knees for a brief,
// visible beat. THEN the capture transport is dispatched.
//
// Handles both entry states:
//   - conscious (came from a proximity tackle): a guard is already
//     within reach, so the kneel starts immediately;
//   - knocked out at range (shot down): the nearest guard walks up
//     first. If none can reach within the approach window, the
//     detain aborts and the target is freed — being downed at a
//     distance no longer magics you into a truck.
//
// The transport itself (fn_spawnCaptureTransport) is the accepted
// "spawn a truck next to me and load me" step the design already
// uses; this function only guarantees a guard is present and adds
// the kneel animation before it fires.
//
// params: [_target, _capturingGrp]
// ============================================================
params [
    ["_target", objNull],
    ["_grp", grpNull]
];

if (!isServer) exitWith {};
if (isNull _target || !alive _target) exitWith {};
if (_target getVariable ["CO_detainInProgress", false]) exitWith {};
if (_target getVariable ["CO_transportInProgress", false]) exitWith {};
_target setVariable ["CO_detainInProgress", true, true];
_target setVariable ["CO_captureInProgress", true, true];
_target setCaptive true;

[_target, _grp] spawn {
    params ["_target", "_grp"];

    private _abort = {
        _target setVariable ["CO_detainInProgress", false, true];
        _target setVariable ["CO_captureInProgress", false, true];
    };

    // ---- Pick an arresting officer -------------------------------
    private _pickOfficer = {
        private _pool = (getPosATL _target nearEntities [["Man"], 60]) select {
            alive _x && vehicle _x == _x &&
            !isPlayer _x &&
            ((group _x) getVariable ["CO_faction", ""]) in ["CRN_ENF", "POLICE"]
        };
        if (!isNull _grp) then {
            {
                if (alive _x && vehicle _x == _x && !(_x in _pool)) then { _pool pushBack _x };
            } forEach (units _grp);
        };
        if (_pool isEqualTo []) then { objNull } else {
            ([_pool, [], { _x distance2D _target }, "ASCEND"] call BIS_fnc_sortBy) select 0
        }
    };

    private _officer = call _pickOfficer;
    if (isNull _officer) exitWith { call _abort };

    // ---- Approach to arm's reach (skip if already close) ---------
    // Keep a knocked-out target pinned down while the officer walks up.
    private _wasKO = _target getVariable ["CO_knockedOut", false];
    private _approachEnd = time + 14;
    _officer disableAI "AUTOTARGET";
    _officer setVariable ["CO_vehicleChaseDriver", false, true];
    while {
        alive _target && vehicle _target == _target &&
        alive _officer &&
        (_officer distance _target) > 2.8 &&
        time < _approachEnd &&
        !(_target getVariable ["CO_transportInProgress", false])
    } do {
        _officer setBehaviour "AWARE";
        _officer setUnitPos "UP";
        _officer doMove (getPosATL _target);
        _officer doWatch _target;
        // Re-pin a downed target so the knockout timer can't wake them
        // and let them run before the officer arrives.
        if (_wasKO && alive _target) then {
            _target setVariable ["CO_knockedOutUntil", time + 20, true];
        };
        sleep 0.6;
    };

    if (!alive _target) exitWith { call _abort };

    // Officer died en route — try one replacement.
    if (isNull _officer || !alive _officer) then {
        _officer = call _pickOfficer;
    };

    // No officer reached arm's reach → no telekinesis: the target
    // got away and is freed.
    if (isNull _officer || !alive _officer || (_officer distance _target) > 5) exitWith {
        diag_log format ["[CO] Detain aborted: no officer reached %1.", _target];
        call _abort;
    };

    // ---- The arrest: force the detainee to their knees -----------
    _officer doWatch _target;
    _officer doTarget _target;
    [_officer, "GestureFreeze"] remoteExec ["playActionNow", 0];

    // Helper: hold the detainee down on their knees for this call.
    // Acts_ExecutionVictim_Loop is a looping ground pose; re-asserting
    // it (on all machines + the owner) prevents a player from mashing
    // a movement key back out of the animation.
    private _pin = {
        _target setUnconscious false;
        _target setVariable ["CO_knockedOut", false, true];
        _target setCaptive true;
        [_target, "Acts_ExecutionVictim_Loop"] remoteExec ["switchMove", 0];
        if (isPlayer _target) then {
            [_target, "Acts_ExecutionVictim_Loop"] remoteExec ["switchMove", _target];
        };
    };

    // Brief, visible arrest beat.
    private _kneelUntil = time + 2.5;
    while { alive _target && vehicle _target == _target && time < _kneelUntil } do {
        call _pin;
        sleep 0.5;
    };

    if (!alive _target) exitWith { call _abort };

    // ---- Dispatch the transport, then STAY pinned until seated ---
    // Previously the kneel was released here and the player got a 2-3 s
    // free-run window while the van spawned and drove up. Now they are
    // held on their knees continuously until the transport actually
    // seats them (vehicle change) or direct-delivers them to training
    // (failsafe). No free-run window.
    _target setVariable ["CO_detainInProgress", false, true];
    _officer enableAI "AUTOTARGET";
    [_target, _grp] spawn co_main_fnc_spawnCaptureTransport;

    private _pinCap = time + 30;   // safety net if the transport hangs
    while {
        alive _target &&
        vehicle _target == _target &&
        (_target getVariable ["CO_detainPhase", ""]) != "training" &&
        time < _pinCap
    } do {
        call _pin;
        sleep 0.4;
    };

    // Seated / delivered / timed out — let any lingering ground pose
    // resolve so the seat (or standing) animation takes over cleanly.
    if (alive _target && vehicle _target == _target) then {
        [_target, ""] remoteExec ["switchMove", 0];
    };
    diag_log format ["[CO] Detain complete for %1 — transport dispatched.", _target];
};
