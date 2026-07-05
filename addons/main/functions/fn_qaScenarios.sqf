// ============================================================
// fn_qaScenarios.sqf
// Live-session verification harness for the repair plan.
//
// Run from the server console/admin action:
//   ["all"] call co_main_fnc_qaScenarios;
//   ["police_id_approach", [6400,2400,0]] call co_main_fnc_qaScenarios;
//
// Logs [CO][QA] PASS/FAIL lines to RPT. These are intentionally
// gameplay-observable assertions: dismount happened, distance closed,
// capture/inspection happened, and sticky flags cleared.
//
// params: [_mode, _anchor]
// ============================================================
params [
    ["_mode", "all"],
    ["_anchor", [6400,2400,0]]
];

if (!isServer) exitWith {
    [_mode, _anchor] remoteExecCall ["co_main_fnc_qaScenarios", 2];
};

private _remoteOwner = if (isNil "remoteExecutedOwner") then { 0 } else { remoteExecutedOwner };
private _authorized = true;
private _callerUID = "server";

if (_remoteOwner > 2) then {
    _authorized = false;
    private _adminUIDs = (missionNamespace getVariable ["CO_adminUIDs", []]) apply {
        if (_x isEqualType "") then { _x } else { format ["%1", _x] }
    };
    {
        if (owner _x == _remoteOwner) exitWith {
            _callerUID = getPlayerUID _x;
            _authorized = _callerUID in _adminUIDs;
        };
    } forEach allPlayers;
};

if (!_authorized) exitWith {
    diag_log format [
        "[CO][SECURITY] Rejected QA scenario '%1' from non-admin owner=%2 uid=%3.",
        _mode, _remoteOwner, _callerUID
    ];
    false
};

if (!canSuspend) exitWith {
    [_mode, _anchor] spawn co_main_fnc_qaScenarios;
};

private _results = [];
private _log = {
    params ["_name", "_ok", "_reason"];
    private _state = if (_ok) then { "PASS" } else { "FAIL" };
    diag_log format ["[CO][QA] %1 %2 %3", _state, _name, _reason];
    _results pushBack [_name, _ok, _reason];
};

private _cleanup = {
    params ["_objects", "_groups"];
    {
        if (!isNull _x) then { deleteVehicle _x };
    } forEach _objects;
    {
        private _grp = _x;
        { if (!isNull _x) then { deleteVehicle _x } } forEach units _grp;
        deleteGroup _grp;
    } forEach _groups;
};

private _mkPolice = {
    params ["_pos", ["_withCar", false]];
    private _grp = createGroup [west, true];
    _grp setVariable ["CO_faction", "POLICE", true];
    _grp setBehaviour "SAFE";
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode "LIMITED";

    private _car = objNull;
    if (_withCar) then {
        _car = createVehicle ["C_Offroad_01_F", _pos, [], 0, "NONE"];
        _car setPosATL _pos;
        _car setDir 90;
        _grp setVariable ["CO_policePatrolCar", _car, true];
    };

    for "_i" from 0 to 1 do {
        private _u = _grp createUnit ["B_Soldier_F", _pos getPos [2 + _i, 270], [], 0, "FORM"];
        removeAllWeapons _u;
        removeAllItems _u;
        removeUniform _u;
        removeVest _u;
        removeHeadgear _u;
        _u forceAddUniform "U_B_GendarmerieSuit_01_F";
        _u addVest "V_HarnessOGL_ghex_F";
        _u addWeapon "hgun_P07_F";
        _u addMagazine "16Rnd_9x21_Mag";
        _u addMagazine "16Rnd_9x21_Mag";
        _u allowFleeing 0;
        [_u] call co_main_fnc_installCrimeWitness;
        if (_withCar) then {
            if (_i == 0) then { _u moveInDriver _car } else { _u moveInCargo _car };
        };
    };

    [_grp, _car]
};

private _mkCivilian = {
    params ["_pos"];
    private _grp = createGroup [civilian, true];
    private _u = _grp createUnit ["C_man_1", _pos, [], 0, "NONE"];
    removeAllWeapons _u;
    _u allowFleeing 0;
    _u setVariable ["CO_QATarget", true, true];
    [_u, _grp]
};

private _runPoliceFootCapture = {
    private _name = "police_foot_capture";
    private _objects = [];
    private _groups = [];
    private _pos = _anchor getPos [35, 20];
    private _targetPack = [_pos] call _mkCivilian;
    private _target = _targetPack select 0;
    _groups pushBack (_targetPack select 1);
    _target setVariable ["CO_wantedLevel", 80, true];

    private _polPack = [_anchor, false] call _mkPolice;
    private _grp = _polPack select 0;
    _groups pushBack _grp;

    private _startDist = (leader _grp) distance2D _target;
    private _minDist = _startDist;
    [_grp, objNull, _target] spawn co_main_fnc_policeFootChase;

    private _end = time + 65;
    waitUntil {
        sleep 0.5;
        if (({ alive _x } count units _grp) > 0 && alive _target) then {
            _minDist = _minDist min ((leader _grp) distance2D _target);
        };
        captive _target ||
        (_target getVariable ["CO_knockedOut", false]) ||
        time > _end
    };

    private _ok = (_minDist < (_startDist - 12)) &&
        { captive _target || (_target getVariable ["CO_knockedOut", false]) };
    [_name, _ok, format ["start=%1m min=%2m captive=%3 ko=%4",
        round _startDist, round _minDist, captive _target, _target getVariable ["CO_knockedOut", false]
    ]] call _log;

    [_objects + [_target], _groups] call _cleanup;
};

private _runPoliceIdApproach = {
    private _name = "police_id_approach";
    private _objects = [];
    private _groups = [];
    private _targetPack = [_anchor getPos [32, 90]] call _mkCivilian;
    private _target = _targetPack select 0;
    _groups pushBack (_targetPack select 1);

    private _polPack = [_anchor, true] call _mkPolice;
    private _grp = _polPack select 0;
    private _car = _polPack select 1;
    _groups pushBack _grp;
    _objects pushBack _car;

    private _startDist = (leader _grp) distance2D _target;
    private _minDist = _startDist;
    [_grp, _car, _target, "CO_QA_suspicion", 0] spawn co_main_fnc_policeOrderInspection;

    private _sawInspecting = false;
    private _end = time + 38;
    waitUntil {
        sleep 0.5;
        if (_target getVariable ["CO_policeInspecting", false]) then { _sawInspecting = true };
        private _foot = (units _grp) select { alive _x && vehicle _x == _x };
        if !(_foot isEqualTo []) then {
            private _sorted = [_foot, [], { _x distance2D _target }, "ASCEND"] call BIS_fnc_sortBy;
            _minDist = _minDist min ((_sorted select 0) distance2D _target);
        };
        (!_target getVariable ["CO_policeInspecting", false] && _sawInspecting) ||
        time > _end
    };

    private _ok = _sawInspecting &&
        { _minDist < 18 } &&
        { !(_grp getVariable ["CO_policeInspectionActive", false]) };
    [_name, _ok, format ["start=%1m min=%2m sawInspecting=%3 active=%4",
        round _startDist, round _minDist, _sawInspecting, _grp getVariable ["CO_policeInspectionActive", false]
    ]] call _log;

    [_objects + [_target], _groups] call _cleanup;
};

private _runTckEmergencyDismount = {
    private _name = "tck_emergency_dismount";
    private _objects = [];
    private _groups = [];
    private _busPos = _anchor getPos [45, 180];
    private _targetPack = [_busPos getPos [45, 90]] call _mkCivilian;
    private _target = _targetPack select 0;
    _groups pushBack (_targetPack select 1);
    _target setVariable ["CO_wantedLevel", 90, true];

    private _bus = createVehicle ["C_Truck_02_transport_F", _busPos, [], 0, "NONE"];
    _bus setPosATL _busPos;
    _bus setDir 90;
    _bus engineOn true;
    _objects pushBack _bus;

    private _driverGrp = createGroup [west, true];
    private _escortGrp = createGroup [west, true];
    _driverGrp setVariable ["CO_faction", "CRN_ENF", true];
    _escortGrp setVariable ["CO_faction", "CRN_ENF", true];
    _driverGrp setVariable ["CO_isBusDriverGrp", true, true];
    _escortGrp setVariable ["CO_isBusEscortGrp", true, true];
    _driverGrp setVariable ["CO_transportVehicle", _bus, true];
    _escortGrp setVariable ["CO_transportVehicle", _bus, true];
    _groups pushBack _driverGrp;
    _groups pushBack _escortGrp;

    private _driver = _driverGrp createUnit ["B_Soldier_F", _busPos, [], 0, "NONE"];
    [_driver] call co_main_fnc_initHostileUnit;
    _driver moveInDriver _bus;
    for "_i" from 0 to 3 do {
        private _u = _escortGrp createUnit ["B_Soldier_F", _busPos, [], 0, "NONE"];
        [_u] call co_main_fnc_initHostileUnit;
        _u moveInCargo _bus;
    };

    _bus setVariable ["CO_isBusPatrol", true, true];
    _bus setVariable ["CO_busRouteWps", [_busPos, _busPos getPos [90, 90]], true];
    _bus setVariable ["CO_busCaptives", [], true];
    _bus setVariable ["CO_busDriverGrp", _driverGrp, true];
    _bus setVariable ["CO_busEscortGrp", _escortGrp, true];
    [_bus, _driverGrp, _escortGrp] spawn co_main_fnc_busAgroLoop;

    sleep 2;
    _bus setVariable ["CO_busEmergencyTarget", _target, false];
    _bus setVariable ["CO_busEmergencyUntil", time + 60, false];
    _bus setVariable ["CO_busEmergencyWeapons", true, false];

    private _startMounted = { alive _x && vehicle _x == _bus } count units _escortGrp;
    private _minDist = 9999;
    private _end = time + 25;
    waitUntil {
        sleep 0.5;
        private _foot = (units _escortGrp) select { alive _x && vehicle _x == _x };
        if !(_foot isEqualTo []) then {
            private _sorted = [_foot, [], { _x distance2D _target }, "ASCEND"] call BIS_fnc_sortBy;
            _minDist = _minDist min ((_sorted select 0) distance2D _target);
        };
        ({ alive _x && vehicle _x == _x } count units _escortGrp) >= 2 ||
        time > _end
    };

    private _footCount = { alive _x && vehicle _x == _x } count units _escortGrp;
    private _ok = _startMounted >= 2 && _footCount >= 2;
    [_name, _ok, format ["mountedStart=%1 foot=%2 minTargetDist=%3m busState=%4",
        _startMounted, _footCount, round _minDist, _bus getVariable ["CO_busState", ""]
    ]] call _log;

    [_objects + [_target], _groups] call _cleanup;
};

private _runCheckpointPursuit = {
    private _name = "checkpoint_failed_papers_pursuit";
    private _objects = [];
    private _groups = [];
    private _cpPos = _anchor getPos [85, 270];
    private _cp = [_cpPos, 90] call co_main_fnc_stampCheckpoint;
    private _cpObjects = _cp select 2;
    private _guardGrp = _cp select 3;
    private _pursuitCar = _cp select 4;
    private _pursuitGrp = _cp select 5;
    _objects append _cpObjects;
    _groups pushBack _guardGrp;
    _groups pushBack _pursuitGrp;

    private _targetCar = createVehicle ["C_Offroad_01_F", _cpPos getPos [18, 90], [], 0, "NONE"];
    _targetCar setDir 90;
    _objects pushBack _targetCar;
    private _targetPack = [getPosATL _targetCar] call _mkCivilian;
    private _driver = _targetPack select 0;
    _groups pushBack (_targetPack select 1);
    _driver moveInDriver _targetCar;
    _driver setVariable ["CO_wantedLevel", 90, true];

    private _sawPursuit = false;
    private _end = time + 34;
    waitUntil {
        sleep 0.5;
        if (
            (_pursuitGrp getVariable ["CO_vehiclePursuitActive", false]) ||
            (_pursuitCar getVariable ["CO_responseActive", false]) ||
            (_driver getVariable ["CO_escalationState", ""]) in ["PURSUIT", "WEAPONS"]
        ) then { _sawPursuit = true };
        _sawPursuit || time > _end
    };

    private _ok = _sawPursuit;
    [_name, _ok, format ["pursuitActive=%1 responseActive=%2 state=%3 wanted=%4",
        _pursuitGrp getVariable ["CO_vehiclePursuitActive", false],
        _pursuitCar getVariable ["CO_responseActive", false],
        _driver getVariable ["CO_escalationState", ""],
        _driver getVariable ["CO_wantedLevel", 0]
    ]] call _log;

    [_objects + [_driver], _groups] call _cleanup;
};

private _wanted = if (_mode == "all") then {
    ["police_id_approach", "police_foot_capture", "tck_emergency_dismount", "checkpoint_failed_papers_pursuit"]
} else {
    [_mode]
};

diag_log format ["[CO][QA] START modes=%1 anchor=%2", _wanted, _anchor];
{
    switch (_x) do {
        case "police_id_approach": { call _runPoliceIdApproach };
        case "police_foot_capture": { call _runPoliceFootCapture };
        case "tck_emergency_dismount": { call _runTckEmergencyDismount };
        case "checkpoint_failed_papers_pursuit": { call _runCheckpointPursuit };
        default { [_x, false, "unknown scenario"] call _log };
    };
    sleep 1;
} forEach _wanted;

private _failed = _results select { !(_x select 1) };
diag_log format ["[CO][QA] SUMMARY total=%1 failed=%2", count _results, count _failed];
count _failed == 0
