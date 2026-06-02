// ============================================================
// fn_policeFootChase.sqf — server-side
//
// Stops a patrol car, dismounts both officers, and chases the
// target on foot until knockout/capture or timeout.
//
// Previous behaviour: the patrol just issued doMove on the
// mounted unit, which kept the driver cruising at LIMITED speed
// past the target; the partner never disembarked at all because
// AI never autonomously dismounts to engage civilians (engine
// civilian-friend=1 relation suppresses it).
//
// Engagement is non-lethal melee (applyMeleeHit accumulates 3
// hits → applyKnockout → captive). Players go via the dedicated
// capture-transport truck (spawnCaptureTransport) like the rest
// of the project's player-capture flow; NPC civilians get loaded
// into the patrol car and driven to detention by transportToDetention.
//
// Params:
//   _grp   - patrol group
//   _car   - patrol vehicle (Offroad)
//   _target - civ/player to chase
// ============================================================
params ["_grp", "_car", "_target"];

if (!isServer) exitWith {};
if (isNull _grp || isNull _car || isNull _target) exitWith {};
if (_grp getVariable ["CO_policeFootChaseActive", false]) then {
    private _activeTarget = _grp getVariable ["CO_policeFootChaseTarget", objNull];
    private _startedAt = _grp getVariable ["CO_policeFootChaseStartedAt", 0];
    if (
        !isNull _activeTarget &&
        alive _activeTarget &&
        !captive _activeTarget &&
        time < (_startedAt + 95)
    ) exitWith {};

    _grp setVariable ["CO_policeFootChaseActive", false, false];
    if (!isNull _activeTarget && alive _activeTarget) then {
        _activeTarget setVariable ["CO_captureInProgress", false, true];
    };
};
if (_target getVariable ["CO_captureInProgress", false]) exitWith {};
_grp setVariable ["CO_policeFootChaseActive", true, false];
_grp setVariable ["CO_policeFootChaseTarget", _target, false];
_grp setVariable ["CO_policeFootChaseStartedAt", time, false];
_target setVariable ["CO_captureInProgress", true, true];
_grp setVariable ["CO_transportVehicle", _car, true];

private _allUnits = (units _grp) select { alive _x };
if (count _allUnits == 0) exitWith {
    _target setVariable ["CO_captureInProgress", false, true];
    _grp setVariable ["CO_policeFootChaseActive", false, false];
};

// --- Stop the car ---
private _drv = driver _car;
_car forceSpeed 0;
if (!isNull _drv) then {
    doStop _drv;
    _drv setBehaviour "SAFE";
    _drv setCombatMode "BLUE";
};

// --- Force everyone out and switch to hunting posture ---
{
    private _u = _x;
    _u allowGetIn false;
    _u setBehaviour "AWARE";
    _u setCombatMode "YELLOW";
    _u enableAI "MOVE";
    _u enableAI "PATH";
    _u enableAI "TARGET";
    _u enableAI "AUTOTARGET";
    _u setUnitPos "UP";
    if (vehicle _u != _u) then {
        unassignVehicle _u;
        _u action ["GetOut", _car];
        doGetOut _u;
        // Hard fallback if the engine refuses to dismount in 1.2s
        [_u, _car] spawn {
            params ["_uu", "_cc"];
            sleep 1.2;
            if (alive _uu && vehicle _uu == _cc) then {
                moveOut _uu;
                if (vehicle _uu == _cc) then {
                    _uu setPosATL ((getPosATL _cc) vectorAdd [
                        (random 4) - 2, (random 4) - 2, 0
                    ]);
                };
            };
        };
    };
} forEach _allUnits;

sleep 1.4;

// --- Foot chase ---
private _deadline   = time + 75;
private _isPlayer   = isPlayer _target;
private _captured   = false;

while {
    alive _target && !captive _target &&
    !(_target getVariable ["CO_knockedOut", false]) &&
    time < _deadline &&
    !_captured &&
    { alive _x && vehicle _x == _x } count (units _grp) > 0
} do {
    private _live = (units _grp) select { alive _x && vehicle _x == _x };
    if (count _live == 0) exitWith {};
    private _sorted = [_live, [], { _x distance2D _target }, "ASCEND"] call BIS_fnc_sortBy;

    {
        _x reveal [_target, 4];
        _x doWatch _target;
        _x doTarget _target;
        _x doMove (getPosATL _target);
        if ((_x distance _target) < 3.0) then {
            [_x, _target] call co_main_fnc_applyMeleeHit;
        };
    } forEach _sorted;

    // Knockout → handoff
    if (_target getVariable ["CO_knockedOut", false]) then {
        _target setCaptive true;
        _target setVariable ["CO_captureInProgress", false, true];
        if (_isPlayer) then {
            _target setUnconscious false;
            _target setVariable ["CO_knockedOut", false, true];
            [_target, _grp] spawn co_main_fnc_spawnCaptureTransport;
            diag_log format ["[CO] Police foot-chase captured player %1 → dedicated transport.", name _target];
        } else {
            [_target, _grp] spawn co_main_fnc_transportToDetention;
            diag_log format ["[CO] Police foot-chase captured NPC %1 → transportToDetention.", _target];
        };
        _captured = true;
    };
    sleep 1.0;
};

// --- Reboard the car if it survived ---
if (alive _car) then {
    private _drvNow = driver _car;
    if (isNull _drvNow) then {
        private _alive = (units _grp) select { alive _x };
        if (count _alive > 0) then {
            (_alive select 0) moveInDriver _car;
        };
    };
    {
        if (alive _x && vehicle _x == _x) then {
            _x allowGetIn true;
            _x assignAsCargo _car;
            [_x] orderGetIn true;
        };
    } forEach (units _grp);

    // Resume cruise after a short reboard window
    [_grp, _car] spawn {
        params ["_g", "_v"];
        sleep 12;
        if (_g getVariable ["CO_policeFootChaseActive", false]) exitWith {};
        // Stragglers — force-board
        {
            if (alive _x && vehicle _x == _x) then {
                _x moveInCargo _v;
            };
        } forEach (units _g);
        _v forceSpeed -1;
        _g setBehaviour "SAFE";
        _g setSpeedMode "LIMITED";
        private _wpCount = count (waypoints _g);
        if (_wpCount > 0) then {
            _g setCurrentWaypoint [_g, 0];
        };
    };
};

// Cleanup capture-in-progress flag in case the chase failed.
if (alive _target && !(_target getVariable ["CO_knockedOut", false])) then {
    _target setVariable ["CO_captureInProgress", false, true];
};
_grp setVariable ["CO_policeFootChaseActive", false, false];
_grp setVariable ["CO_policeFootChaseTarget", objNull, false];
