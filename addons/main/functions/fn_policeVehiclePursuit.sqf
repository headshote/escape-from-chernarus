// ============================================================
// fn_policeVehiclePursuit.sqf
// Vehicle pursuit used by police and checkpoint response cars.
// params: [_grp, _car, _target, _source]
// ============================================================
params [
    ["_grp", grpNull],
    ["_car", objNull],
    ["_target", objNull],
    ["_source", "police_vehicle"]
];

if (!isServer || isNull _grp || isNull _car || isNull _target) exitWith {};
if (_grp getVariable ["CO_vehiclePursuitActive", false]) exitWith {};
_grp setVariable ["CO_vehiclePursuitActive", true, false];
["vehicle_chase_started"] call co_main_fnc_kpi;

private _priority = if (isPlayer _target) then { 75 } else { 55 };
private _token = format ["veh_chase_%1_%2", netId _car, floor (time * 10)];
private _claimed = [];
{
    if (alive _x && { [_x, _token, _priority, 45] call co_main_fnc_claimUnit }) then {
        _claimed pushBack _x;
    };
} forEach units _grp;

if (_claimed isEqualTo []) exitWith {
    _grp setVariable ["CO_vehiclePursuitActive", false, false];
};

_car setVariable ["CO_responseActive", true, true];
[_car] call co_main_fnc_policeResponseFX;
[_target, "PURSUIT", _source, _priority, _grp] call co_main_fnc_setEscalationState;

private _driver = driver _car;
if (isNull _driver && !(_claimed isEqualTo [])) then {
    (_claimed select 0) moveInDriver _car;
    _driver = driver _car;
};

{
    if (alive _x && vehicle _x == _x && _x != _driver) then {
        _x assignAsCargo _car;
        _x moveInCargo _car;
    };
} forEach _claimed;

_grp setBehaviour "AWARE";
_grp setCombatMode "YELLOW";
_grp setSpeedMode "FULL";
_car forceSpeed -1;
_car engineOn true;

private _startedAt = time;
private _lastMoveAt = 0;
private _roadblockAt = -1;
private _backupAt = -1;
private _done = false;
private _checkpointAnchor = _grp getVariable ["CO_checkpointAnchor", []];
private _checkpointLeash = _grp getVariable ["CO_checkpointLeash", missionNamespace getVariable ["CO_checkpoint_chaseLeash", 250]];

while {
    alive _car &&
    alive _target &&
    !captive _target &&
    !_done &&
    (time - _startedAt) < 180
} do {
    sleep 1;
    if (vehicle _target == _target) exitWith {
        [_grp, _car, _target] spawn co_main_fnc_policeFootChase;
        _done = true;
    };

    if !(_checkpointAnchor isEqualTo []) then {
        if ((_target distance2D _checkpointAnchor) > (_checkpointLeash + 120)) exitWith {
            [_target, getPosATL (vehicle _target), "checkpoint_vehicle_leash", 70] call co_main_fnc_alertPublish;
            [_target, "SEARCH", "checkpoint_vehicle_leash", 60, _grp] call co_main_fnc_setEscalationState;
            _done = false;
        };
    };

    // Replace a dead/missing driver mid-pursuit (audit R2-16).
    _driver = driver _car;
    if (isNull _driver || !alive _driver) then {
        private _foot = _claimed select { alive _x };
        if !(_foot isEqualTo []) then {
            private _newDriver = _foot select 0;
            if (vehicle _newDriver != _newDriver && vehicle _newDriver != _car) then {
                moveOut _newDriver;
            };
            _newDriver moveInDriver _car;
            _driver = driver _car;
        };
    };
    if (isNull _driver) exitWith { _done = false };

    [_target, "PURSUIT", _source, _priority, _grp] call co_main_fnc_setEscalationState;

    private _tVeh = vehicle _target;
    private _dest = getPosATL _tVeh;
    private _vel = velocity _tVeh;
    _vel set [2, 0];
    _dest = _dest vectorAdd (_vel vectorMultiply 3.5);

    if ((time - _lastMoveAt) > 3 || (_car distance2D _dest) > 80) then {
        _car doMove _dest;
        if (!isNull _driver) then { _driver doMove _dest };
        _lastMoveAt = time;
    };

    if (_backupAt < 0 && (time - _startedAt) > 30) then {
        _backupAt = time;
        private _near = allGroups select {
            _x != _grp &&
            (_x getVariable ["CO_faction", ""]) == "POLICE" &&
            !(_x getVariable ["CO_vehiclePursuitActive", false]) &&
            !(_x getVariable ["CO_policeFootChaseActive", false]) &&
            (leader _x distance2D _target) < 1200
        };
        if !(_near isEqualTo []) then {
            private _bGrp = _near select 0;
            private _bCar = _bGrp getVariable ["CO_policePatrolCar", objNull];
            if (!isNull _bCar && alive _bCar) then {
                [_bGrp, _bCar, _target, "police_backup"] spawn co_main_fnc_policeVehiclePursuit;
            };
        };
    };

    if (_roadblockAt < 0 && (time - _startedAt) > 45) then {
        _roadblockAt = time;
        [_target, getPosATL _car, _grp getVariable ["CO_faction", "POLICE"], 520, 180] call co_main_fnc_dispatchRoadblock;
        [_target, "WEAPONS", _source, 80, _grp] call co_main_fnc_setEscalationState;
    };

    if ((_car distance2D _target) < 22 && abs (speed (vehicle _target)) < 8) then {
        _done = true;
        [_grp, _car, _target] spawn co_main_fnc_policeFootChase;
    };
};

_car setVariable ["CO_responseActive", false, true];

if (!_done && alive _target) then {
    [_target, "SEARCH", _source, 50, _grp] call co_main_fnc_setEscalationState;
    [_target, getPosATL (vehicle _target), _source, 60] call co_main_fnc_alertPublish;
};

// A pursuit that did NOT hand off to a foot chase must put the patrol
// back on its route — this was the "police car parked dead in the
// middle of the road" bug (audit R2-2). Foot-chase handoffs resume
// patrol at the end of fn_policeFootChase instead.
if (!_done) then {
    [_grp, _car] call co_main_fnc_policeResumePatrol;
};

{
    [_x, _token] call co_main_fnc_releaseUnit;
} forEach _claimed;

_grp setVariable ["CO_vehiclePursuitActive", false, false];
