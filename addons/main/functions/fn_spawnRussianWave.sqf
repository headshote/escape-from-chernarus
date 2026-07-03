// fn_spawnRussianWave.sqf
if (isNil "CO_rus_waveCount") then { CO_rus_waveCount = 0; };

private _maxActive = missionNamespace getVariable ["CO_rus_maxActive", 120];
private _activeCount = {
    alive _x &&
    ((group _x) getVariable ["CO_faction", ""] == "RUS_ADV")
} count allUnits;
if (_activeCount >= _maxActive) exitWith {
    diag_log format ["[CO] RUS_ADV wave skipped (%1/%2 active).", _activeCount, _maxActive];
};

private _spawnX = missionNamespace getVariable ["CO_rus_spawnX", 13000];
private _northX = missionNamespace getVariable ["CO_rus_spawnXNorth", 12550];
private _armorFreq = (missionNamespace getVariable ["CO_rus_armorFrequency", 1]) max 1;
private _tankFreq = (missionNamespace getVariable ["CO_rus_tankFrequency", 3]) max 1;
private _nextWaveNumber = CO_rus_waveCount + 1;
private _vehicleReserve = 12 + (if (_nextWaveNumber % _tankFreq == 0) then { 3 } else { 0 });
if (_activeCount >= (_maxActive - _vehicleReserve)) exitWith {
    diag_log format [
        "[CO] RUS_ADV wave skipped to preserve vehicle reserve (%1/%2 active, reserve=%3).",
        _activeCount,
        _maxActive,
        _vehicleReserve
    ];
};

private _lanes = [
    ["north", [_northX - random 120, 12300 + random 260 - 130, 0], 0.62],
    ["central", [_spawnX - random 120, 7800 + random 260 - 130, 0], 0.24],
    ["south", [_spawnX - random 120, 3300 + random 260 - 130, 0], 0.14]
];

private _infantryBudget = (_maxActive - _activeCount - _vehicleReserve) max 6;
private _waveSize = ((missionNamespace getVariable ["CO_rus_unitsPerWave", 42]) min _infantryBudget) max 3;
private _infantryClasses = ["O_Soldier_F", "O_Soldier_AR_F", "O_Medic_F", "O_Soldier_GL_F", "O_Soldier_LAT_F"];

private _prepUnit = {
    params ["_unit", "_laneName"];
    _unit setVariable ["CO_advanceLane", _laneName, true];
    _unit setUnitPos "UP";
    _unit setBehaviour "COMBAT";
    _unit setCombatMode "RED";
    _unit allowFleeing 0;
    _unit setSkill ["aimingAccuracy", 0.32];
    _unit setSkill ["aimingShake", 0.42];
    _unit setSkill ["spotDistance", 0.85];
    _unit setSkill ["spotTime", 0.75];
    _unit setSkill ["courage", 1];
    _unit addEventHandler ["Killed", {
        params ["_killed"];
        [_killed] spawn {
            params ["_dead"];
            sleep (2 + random 4);
            [_dead] call co_main_fnc_spawnRussianReplacement;
        };
    }];
};

private _spawnGroup = {
    params ["_lane", "_count"];
    private _laneName = _lane select 0;
    private _spawnPos = _lane select 1;
    private _grp = createGroup east;
    _grp setVariable ["CO_faction", "RUS_ADV", true];
    _grp setVariable ["CO_advanceLane", _laneName, true];
    _grp setVariable ["CO_advanceSpawnPos", _spawnPos, true];

    for "_i" from 1 to _count do {
        private _u = _grp createUnit [selectRandom _infantryClasses, _spawnPos, [], 8, "FORM"];
        [_u, _laneName] call _prepUnit;
    };

    [_grp] call co_main_fnc_russianAdvanceWaypoints;
    _grp
};

private _spawnVehicleGroup = {
    params ["_lane", "_offset", "_vehicleClasses", ["_cargoCount", 0]];
    private _laneName = _lane select 0;
    private _spawnPos = (_lane select 1) vectorAdd _offset;
    private _grp = createGroup east;
    _grp setVariable ["CO_faction", "RUS_ADV", true];
    _grp setVariable ["CO_advanceLane", _laneName, true];
    _grp setVariable ["CO_advanceSpawnPos", _spawnPos, true];

    private _veh = createVehicle [selectRandom _vehicleClasses, _spawnPos, [], 0, "NONE"];
    _veh setVariable ["CO_faction", "RUS_ADV", true];
    _veh setVariable ["CO_advanceLane", _laneName, true];
    _veh setVehicleReceiveRemoteTargets true;
    _veh setVehicleReportRemoteTargets true;
    _veh engineOn true;

    private _driver = _grp createUnit ["O_Soldier_F", _spawnPos, [], 0, "CARGO"];
    [_driver, _laneName] call _prepUnit;
    _driver moveInDriver _veh;

    private _gunner = _grp createUnit ["O_Soldier_F", _spawnPos, [], 0, "CARGO"];
    [_gunner, _laneName] call _prepUnit;
    if (_veh emptyPositions "gunner" > 0) then { _gunner moveInGunner _veh } else { _gunner moveInCargo _veh };

    private _cmd = _grp createUnit ["O_Soldier_F", _spawnPos, [], 0, "CARGO"];
    [_cmd, _laneName] call _prepUnit;
    if (_veh emptyPositions "commander" > 0) then { _cmd moveInCommander _veh } else { _cmd moveInCargo _veh };

    for "_i" from 1 to _cargoCount do {
        private _cargo = _grp createUnit [selectRandom _infantryClasses, _spawnPos, [], 0, "CARGO"];
        [_cargo, _laneName] call _prepUnit;
        if (_veh emptyPositions "cargo" > 0) then { _cargo moveInCargo _veh };
    };

    _veh addEventHandler ["Killed", {
        params ["_killed"];
        [_killed] spawn {
            params ["_dead"];
            sleep 10;
            [_dead] call co_main_fnc_spawnRussianReplacement;
        };
    }];

    [_grp] call co_main_fnc_russianAdvanceWaypoints;
    [_grp, _veh]
};

private _waveGroups = [];
{
    private _laneCount = round (_waveSize * (_x select 2));
    if (_laneCount < 2) then { _laneCount = 2 };
    _waveGroups pushBack ([_x, _laneCount] call _spawnGroup);
} forEach _lanes;

CO_rus_waveCount = CO_rus_waveCount + 1;

// Light armed vehicle every wave on the Krasnostav axis.
[_lanes select 0, [-20, -55, 0], ["O_MRAP_02_hmg_F", "O_MRAP_02_gmg_F"], 2] call _spawnVehicleGroup;

private _spawnedApc = false;
if (CO_rus_waveCount % _armorFreq == 0) then {
    [_lanes select 0, [-55, 20, 0], ["O_APC_Wheeled_02_rcws_F", "O_APC_Tracked_02_cannon_F"], 4] call _spawnVehicleGroup;
    _spawnedApc = true;
};

private _spawnedTank = false;
if (CO_rus_waveCount % _tankFreq == 0) then {
    [_lanes select 0, [-95, 55, 0], ["O_MBT_02_cannon_F"], 0] call _spawnVehicleGroup;
    _spawnedTank = true;
};

diag_log format [
    "[CO] Russian wave %1: north spawnX=%2 size=%3 groups=%4 MRAP=true APC=%5 Tank=%6 activeBefore=%7/%8.",
    CO_rus_waveCount,
    _northX,
    _waveSize,
    count _waveGroups,
    _spawnedApc,
    _spawnedTank,
    _activeCount,
    _maxActive
];
