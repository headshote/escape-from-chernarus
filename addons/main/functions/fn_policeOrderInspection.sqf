// ============================================================
// fn_policeOrderInspection.sqf
// Server-side physical ID-check beat.
//
// The police brain decides that a target should be checked; this
// helper owns the movement so the check is not just a message and a
// timer. It stops the patrol car, dismounts officers if needed, claims
// them, walks them to the target's CURRENT position, then resolves pass
// / warning / pursuit.
//
// params: [_grp, _car, _target, _susKey, _townAlert]
// ============================================================
params [
    ["_grp", grpNull],
    ["_car", objNull],
    ["_target", objNull],
    ["_susKey", ""],
    ["_townAlert", 0]
];

if (!isServer || isNull _grp || isNull _target) exitWith { false };
if (!alive _target || captive _target) exitWith { false };
if (_target getVariable ["CO_policeInspecting", false]) exitWith { false };
if (_grp getVariable ["CO_policeInspectionActive", false]) exitWith { false };

private _targetKey = netId _target;
if (_targetKey == "") then { _targetKey = str _target };
private _token = format ["police_inspect_%1_%2", _targetKey, floor (time * 10)];
private _priority = if (isPlayer _target) then { 65 } else { 45 };

private _claimed = [];
{
    if (alive _x && { [_x, _token, _priority, 35] call co_main_fnc_claimUnit }) then {
        _claimed pushBack _x;
    };
} forEach units _grp;

if (_claimed isEqualTo []) exitWith { false };

_grp setVariable ["CO_policeInspectionActive", true, false];
_target setVariable ["CO_policeInspecting", true, true];
[_target, "SUSPICIOUS", "police_id_check", 30, _grp] call co_main_fnc_setEscalationState;

if (isPlayer _target) then {
    ["Police: STOP. Document check - stand still."] remoteExecCall ["systemChat", _target];
};

if (!isNull _car && alive _car) then {
    _car forceSpeed 0;
    _car engineOn true;
    private _drv = driver _car;
    if (!isNull _drv) then { doStop _drv };
};

{
    private _u = _x;
    _u allowGetIn false;
    _u setBehaviour "AWARE";
    _u setCombatMode "YELLOW";
    _u setUnitPos "UP";
    _u enableAI "MOVE";
    _u enableAI "PATH";
    if (vehicle _u != _u) then {
        private _veh = vehicle _u;
        unassignVehicle _u;
        _u action ["GetOut", _veh];
        doGetOut _u;
        [_u, _veh] spawn {
            params ["_unit", "_veh"];
            sleep 1.1;
            if (alive _unit && vehicle _unit == _veh) then {
                moveOut _unit;
                if (vehicle _unit == _veh) then {
                    _unit setPosATL ((getPosATL _veh) vectorAdd [(random 4) - 2, (random 4) - 2, 0]);
                };
            };
        };
    };
} forEach _claimed;

sleep 1.2;

private _cleanup = {
    params [["_resume", true]];
    _target setVariable ["CO_policeInspecting", false, true];
    _grp setVariable ["CO_policeInspectionActive", false, false];
    {
        [_x, _token] call co_main_fnc_releaseUnit;
    } forEach _claimed;
    if (_resume) then {
        [_grp, _car] call co_main_fnc_policeResumePatrol;
    };
};

private _nearestDist = 9999;
private _complied = false;
private _aborted = false;
private _approachEnd = time + 14;

while { alive _target && !captive _target && time < _approachEnd && !_complied && !_aborted } do {
    private _live = _claimed select {
        alive _x &&
        vehicle _x == _x &&
        { [_x, _token, _priority, 20] call co_main_fnc_claimUnit }
    };
    if (_live isEqualTo []) exitWith { _aborted = true };

    private _dest = getPosATL _target;
    {
        _x doWatch _target;
        if ((_x distance2D _dest) > 6) then { _x doMove _dest };
    } forEach _live;

    private _sorted = [_live, [], { _x distance2D _target }, "ASCEND"] call BIS_fnc_sortBy;
    _nearestDist = (_sorted select 0) distance2D _target;

    if ((abs (speed _target)) < 2 && _nearestDist < 16) then {
        _complied = true;
    };

    // Running away from the approaching officer turns the check into a
    // pursuit. Standing still does not punish the player if pathing is
    // momentarily slow; the officer keeps walking until the window ends.
    if ((abs (speed _target)) > 5 && _nearestDist > 28) then {
        _aborted = true;
    };
    sleep 0.7;
};

if (!alive _target || captive _target) exitWith {
    [true] call _cleanup;
    true
};

private _fledBeforeCheck = !_complied && { (abs (speed _target)) > 4 || _nearestDist > 42 };
if (_fledBeforeCheck) exitWith {
    private _wl = ((_target getVariable ["CO_wantedLevel", 0]) + 20) min 100;
    _target setVariable ["CO_wantedLevel", _wl, true];
    [_target, "PURSUIT", "police_fled_id", 65, _grp] call co_main_fnc_setEscalationState;
    ["police_id_fled"] call co_main_fnc_kpi;
    [false] call _cleanup;
    [_grp, _car, _target] spawn co_main_fnc_policeFootChase;
    true
};

if (isPlayer _target) then {
    ["Police are checking your papers. Stay still."] remoteExecCall ["systemChat", _target];
};

private _checkEnd = time + 8 + random 4;
while { alive _target && !captive _target && time < _checkEnd } do {
    private _live = _claimed select { alive _x && vehicle _x == _x };
    if (_live isEqualTo []) exitWith {};
    private _dest = getPosATL _target;
    {
        _x doWatch _target;
        if ((_x distance2D _dest) > 9) then { _x doMove _dest };
    } forEach _live;
    sleep 0.7;
};

if (!alive _target || captive _target) exitWith {
    [true] call _cleanup;
    true
};

private _liveAfter = _claimed select { alive _x && vehicle _x == _x };
private _nearestAfter = 9999;
if !(_liveAfter isEqualTo []) then {
    private _sortedAfter = [_liveAfter, [], { _x distance2D _target }, "ASCEND"] call BIS_fnc_sortBy;
    _nearestAfter = (_sortedAfter select 0) distance2D _target;
};

if ((abs (speed _target)) > 4 || _nearestAfter > 35) exitWith {
    private _wl = ((_target getVariable ["CO_wantedLevel", 0]) + 20) min 100;
    _target setVariable ["CO_wantedLevel", _wl, true];
    [_target, "PURSUIT", "police_fled_id", 65, _grp] call co_main_fnc_setEscalationState;
    ["police_id_fled"] call co_main_fnc_kpi;
    [false] call _cleanup;
    [_grp, _car, _target] spawn co_main_fnc_policeFootChase;
    true
};

private _wanted = _target getVariable ["CO_wantedLevel", 0];
private _disguise = _target getVariable ["CO_disguiseLevel", 0];
private _risk = _wanted - (_disguise * 12) + random 20 + (_townAlert * 5);

if (_risk < 45 && _wanted < 50) exitWith {
    if (_susKey != "") then { _grp setVariable [_susKey, 0, false] };
    [_target, "CLEAR", "police_id_pass", 0, _grp] call co_main_fnc_setEscalationState;
    ["police_id_pass"] call co_main_fnc_kpi;
    if (isPlayer _target) then { ["Police: Documents in order. Move along."] remoteExecCall ["systemChat", _target] };
    [true] call _cleanup;
    true
};

if (_risk < 65 && _wanted < 50) exitWith {
    if (_susKey != "") then { _grp setVariable [_susKey, 25, false] };
    [_target, "SUSPICIOUS", "police_id_warned", 30, _grp] call co_main_fnc_setEscalationState;
    if (isPlayer _target) then { ["Police: We're watching you. Move along."] remoteExecCall ["systemChat", _target] };
    [true] call _cleanup;
    true
};

[_target, "PURSUIT", "police_id_fail", 70, _grp] call co_main_fnc_setEscalationState;
["police_id_detain"] call co_main_fnc_kpi;
[false] call _cleanup;
[_grp, _car, _target] spawn co_main_fnc_policeFootChase;
true
