// ============================================================
// fn_policeResumePatrol.sqf — shared patrol-resume epilogue
// (server-side, BLOCKING up to ~14 s — call from a scheduled
// thread: chase controllers and the watchdog both are)
//
// Repair plan R1-e. Every police engagement must end by going
// through here so a patrol can never be left parked mid-road
// (audit finding R2-2). Handles both car patrols and foot
// patrols (pass objNull as _car for foot groups).
//
// params: [_grp, _car]
// ============================================================
params [
    ["_grp", grpNull],
    ["_car", objNull]
];

if (!isServer || isNull _grp) exitWith {};

private _alive = (units _grp) select { alive _x };
if (_alive isEqualTo []) exitWith {};

// ---- Foot patrol: just restore posture + waypoints -----------------
if (isNull _car || !alive _car) exitWith {
    {
        _x setBehaviour "SAFE";
        _x setCombatMode "YELLOW";
        _x setUnitPos "AUTO";
        _x allowGetIn true;
    } forEach _alive;
    _grp setBehaviour "SAFE";
    _grp setSpeedMode "LIMITED";
    if (count (waypoints _grp) > 0) then {
        _grp setCurrentWaypoint [_grp, 0];
    };
};

// ---- Car patrol: reboard, restore cruise ----------------------------
{
    _x allowGetIn true;
    _x setBehaviour "SAFE";
    _x setCombatMode "BLUE";
    _x setUnitPos "AUTO";
} forEach _alive;

if (isNull (driver _car) || !alive (driver _car)) then {
    private _foot = _alive select { vehicle _x == _x };
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
} forEach _alive;

private _reboardEnd = time + 12;
waitUntil {
    sleep 0.5;
    !alive _car ||
    ({ alive _x && vehicle _x == _x } count _alive) == 0 ||
    time > _reboardEnd
};

{
    if (alive _x && vehicle _x == _x) then {
        _x moveInCargo _car;
    };
} forEach _alive;

if (alive _car) then {
    _car forceSpeed -1;
    _car engineOn true;
    _grp setBehaviour "SAFE";
    _grp setCombatMode "BLUE";
    _grp setSpeedMode "LIMITED";
    if (count (waypoints _grp) > 0) then {
        _grp setCurrentWaypoint [_grp, 0];
    };
};
