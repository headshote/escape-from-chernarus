// ============================================================
// fn_policeFootChase.sqf - server-side
//
// Stops a patrol car, claims both officers through the engagement
// arbiter, dismounts them, then runs a real pursuit using:
//   - fn_chaseMove for predicted intercept movement;
//   - fn_proximityTackle for sustained close-contact grabs;
//   - fn_alertPublish/fn_searchBehavior for last-known-position memory.
//
// Params:
//   _grp    - patrol group
//   _car    - patrol vehicle
//   _target - civilian/player to chase
// ============================================================
params ["_grp", "_car", "_target"];

if (!isServer) exitWith {};
if (isNull _grp || isNull _car || isNull _target) exitWith {};
if (_grp getVariable ["CO_policeFootChaseActive", false]) exitWith {};
_grp setVariable ["CO_policeFootChaseActive", true, false];

private _isPlayer = isPlayer _target;
private _priority = if (_isPlayer) then { 70 } else { 50 };
private _targetKey = netId _target;
if (_targetKey == "") then { _targetKey = str _target };
private _token = format ["police_chase_%1_%2", _targetKey, floor (time * 10)];

private _claimedUnits = [];
{
    if (alive _x && { [_x, _token, _priority, 45] call co_main_fnc_claimUnit }) then {
        _claimedUnits pushBack _x;
    };
} forEach (units _grp);

if (_claimedUnits isEqualTo []) exitWith {
    _grp setVariable ["CO_policeFootChaseActive", false, false];
};

_target setVariable ["CO_captureInProgress", true, true];
[_target] call co_main_fnc_installNonLethalDamage;
[_target, getPosATL _target, "police_chase", _priority] call co_main_fnc_alertPublish;
[_target, "PURSUIT", "police_chase", _priority, _grp] call co_main_fnc_setEscalationState;
["police_foot_chase_started"] call co_main_fnc_kpi;
_car setVariable ["CO_responseActive", true, true];
[_car] call co_main_fnc_policeResponseFX;

// Stop the car and keep the driver from resuming waypoints mid-dismount.
_car forceSpeed 0;
private _drv = driver _car;
if (!isNull _drv) then {
    doStop _drv;
    _drv setBehaviour "SAFE";
    _drv setCombatMode "BLUE";
};

{
    private _u = _x;
    _u allowGetIn false;
    _u setBehaviour "AWARE";
    _u setCombatMode "YELLOW";
    _u enableAI "MOVE";
    _u enableAI "PATH";
    _u setUnitPos "UP";

    if (vehicle _u != _u) then {
        unassignVehicle _u;
        _u action ["GetOut", _car];
        doGetOut _u;
        [_u, _car] spawn {
            params ["_uu", "_cc"];
            sleep 1.2;
            if (alive _uu && vehicle _uu == _cc) then {
                moveOut _uu;
                if (vehicle _uu == _cc) then {
                    _uu setPosATL ((getPosATL _cc) vectorAdd [
                        (random 4) - 2,
                        (random 4) - 2,
                        0
                    ]);
                };
            };
        };
    };
} forEach _claimedUnits;

sleep 1.4;

private _captured = false;
private _escaped = false;
private _lastKnownPos = getPosATL _target;
private _lostSightAt = -1;
private _lastAlertAt = 0;
private _deadline = time + (missionNamespace getVariable ["CO_police_chaseDeadline", 180]);
private _backupRequested = false;

private _captureTarget = {
    params [["_attacker", objNull]];

    private _wl = (_target getVariable ["CO_wantedLevel", 0]) + 20;
    _target setVariable ["CO_wantedLevel", _wl min 100, true];

    if (_isPlayer) then {
        [_target] remoteExecCall ["co_main_fnc_wrangleMinigame", _target];
        private _wrangleDeadline = time + 20;
        waitUntil {
            sleep 0.3;
            !alive _target ||
            !isNil { _target getVariable "CO_wrangleResult" } ||
            time > _wrangleDeadline
        };

        private _result = _target getVariable ["CO_wrangleResult", "captured"];
        _target setVariable ["CO_wrangleResult", nil, true];

        if (_result == "captured") exitWith {
            _target setCaptive true;
            _target setUnconscious false;
            _target setVariable ["CO_knockedOut", false, true];
            _target setVariable ["CO_captureInProgress", false, true];
            [_target, _grp] spawn co_main_fnc_spawnCaptureTransport;
            diag_log format ["[CO] Police foot chase captured player %1.", name _target];
            true
        };

        _target setVariable ["CO_tackleImmuneUntil", time + 6, true];
        ["You broke the grab - run or hide."] remoteExecCall ["systemChat", _target];
        sleep 2;
        false
    } else {
        if (isNull _attacker) then {
            private _liveAttackers = _claimedUnits select { alive _x && vehicle _x == _x };
            if !(_liveAttackers isEqualTo []) then { _attacker = _liveAttackers select 0 };
        };
        if (!isNull _attacker) then {
            [_attacker, _target, 60, true] call co_main_fnc_applyKnockout;
        };
        _target setCaptive true;
        _target setVariable ["CO_captureInProgress", false, true];
        [_target, _grp] spawn co_main_fnc_transportToDetention;
        diag_log format ["[CO] Police foot chase captured NPC %1.", _target];
        true
    }
};

while {
    alive _target &&
    !captive _target &&
    !(_target getVariable ["CO_knockedOut", false]) &&
    time < _deadline &&
    !_captured &&
    !_escaped
} do {
    private _live = _claimedUnits select {
        alive _x &&
        vehicle _x == _x &&
        { [_x, _token, _priority, 30] call co_main_fnc_claimUnit }
    };
    if (_live isEqualTo []) exitWith {};

    [_live, _target] call co_main_fnc_chaseMove;

    private _hasSight = false;
    {
        if ((_x distance2D _target) < 90) then {
            private _vis = [vehicle _x, "VIEW"] checkVisibility [eyePos _x, eyePos _target];
            if (_vis > 0.15) exitWith { _hasSight = true };
        };
    } forEach _live;

    if (_hasSight) then {
        _lastKnownPos = getPosATL (vehicle _target);
        _lostSightAt = -1;
        if ((time - _lastAlertAt) > 5) then {
            [_target, _lastKnownPos, "police_chase", _priority] call co_main_fnc_alertPublish;
            _lastAlertAt = time;
        };
    } else {
        if (_lostSightAt < 0) then { _lostSightAt = time };
        if ((time - _lostSightAt) > 10) then {
            private _found = [
                _live,
                _lastKnownPos,
                missionNamespace getVariable ["CO_search_duration", 120],
                _target,
                _token,
                _priority
            ] call co_main_fnc_searchBehavior;

            if (isNull _found) then {
                _escaped = true;
            } else {
                _lostSightAt = -1;
                _lastKnownPos = getPosATL _target;
                [_target, _lastKnownPos, "police_respotted", _priority] call co_main_fnc_alertPublish;
            };
        };
    };

    if (vehicle _target == _target && { [_live, _target] call co_main_fnc_proximityTackle }) then {
        private _sorted = [_live, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
        private _attacker = _sorted select 0;
        _captured = [_attacker] call _captureTarget;
        if (_captured) then { ["police_foot_chase_caught"] call co_main_fnc_kpi };
    };

    if (!_backupRequested && (time > (_deadline - 150))) then {
        _backupRequested = true;
        private _near = allGroups select {
            _x != _grp &&
            (_x getVariable ["CO_faction", ""]) == "POLICE" &&
            !(_x getVariable ["CO_vehiclePursuitActive", false]) &&
            !(_x getVariable ["CO_policeFootChaseActive", false]) &&
            (leader _x distance2D _target) < 900
        };
        if !(_near isEqualTo []) then {
            private _bGrp = _near select 0;
            private _bCar = _bGrp getVariable ["CO_policePatrolCar", objNull];
            if (!isNull _bCar && alive _bCar) then {
                [_bGrp, _bCar, _target, "police_backup"] spawn co_main_fnc_policeVehiclePursuit;
            };
        };
    };

    if ((_target getVariable ["CO_wantedLevel", 0]) >= 75 || (_target getVariable ["CO_hasFiredWeapon", false])) then {
        [_target, "WEAPONS", "police_escalation", 85, _grp] call co_main_fnc_setEscalationState;
    };

    sleep 0.7;
};

if (!_captured && !_escaped && alive _target && !captive _target) then {
    private _live = _claimedUnits select {
        alive _x &&
        vehicle _x == _x &&
        { [_x, _token, _priority, 20] call co_main_fnc_claimUnit }
    };
    if !(_live isEqualTo []) then {
        private _found = [
            _live,
            _lastKnownPos,
            missionNamespace getVariable ["CO_search_duration", 120],
            _target,
            _token,
            _priority
        ] call co_main_fnc_searchBehavior;
        if (isNull _found) then { _escaped = true };
    };
};

if (_escaped) then { ["police_foot_chase_lost"] call co_main_fnc_kpi };

if (alive _target && !(_target getVariable ["CO_knockedOut", false]) && !_captured) then {
    _target setVariable ["CO_captureInProgress", false, true];
};

// Reboard while the claim is still held so no ambient controller steals
// an officer during the handoff back to patrol.
if (alive _car) then {
    private _alivePolice = _claimedUnits select { alive _x };

    {
        _x allowGetIn true;
        _x setBehaviour "SAFE";
        _x setCombatMode "BLUE";
    } forEach _alivePolice;

    if (isNull (driver _car)) then {
        private _foot = _alivePolice select { vehicle _x == _x };
        if !(_foot isEqualTo []) then {
            private _newDriver = _foot select 0;
            _newDriver assignAsDriver _car;
            _newDriver moveInDriver _car;
        };
    };

    {
        if (alive _x && vehicle _x == _x && _x != driver _car) then {
            _x assignAsCargo _car;
            [_x] orderGetIn true;
            _x doMove (getPosATL _car);
        };
    } forEach _alivePolice;

    private _reboardEnd = time + 12;
    waitUntil {
        sleep 0.5;
        !alive _car ||
        ({ alive _x && vehicle _x == _x } count _alivePolice) == 0 ||
        time > _reboardEnd
    };

    {
        if (alive _x && vehicle _x == _x) then {
            _x moveInCargo _car;
        };
    } forEach _alivePolice;

    if (alive _car) then {
        _car forceSpeed -1;
        _grp setBehaviour "SAFE";
        _grp setCombatMode "BLUE";
        _grp setSpeedMode "LIMITED";
        private _wpCount = count (waypoints _grp);
        if (_wpCount > 0) then {
            _grp setCurrentWaypoint [_grp, 0];
        };
    };
};

_car setVariable ["CO_responseActive", false, true];

{
    [_x, _token] call co_main_fnc_releaseUnit;
} forEach _claimedUnits;

_grp setVariable ["CO_policeFootChaseActive", false, false];
