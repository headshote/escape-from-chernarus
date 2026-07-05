// fn_spawnRussianWave.sqf
// Siege maintainer: tops the Krasnostav/airstrip zone back up to its target
// live headcount every time it runs, spawning ONLY the deficit and never
// exceeding the global CO_rus_maxActive cap (server-safety bound). All units
// assault in from the north/east approaches and are handed the town<->airstrip
// patrol in fn_russianAdvanceWaypoints, so the assault is permanent and heavy
// without unbounded growth.
if (!isServer) exitWith {};
if (isNil "CO_rus_waveCount") then { CO_rus_waveCount = 0; };

private _zoneCenter = missionNamespace getVariable ["CO_rus_zoneCenter", [11400, 12650, 0]];
private _zoneRadius = missionNamespace getVariable ["CO_rus_zoneRadius", 1500];
private _zoneTarget = missionNamespace getVariable ["CO_rus_zoneTarget", 45];
private _maxActive  = missionNamespace getVariable ["CO_rus_maxActive", 95];
private _perWaveMax = missionNamespace getVariable ["CO_rus_unitsPerWave", 20];
private _armorFreq  = (missionNamespace getVariable ["CO_rus_armorFrequency", 2]) max 1;
private _tankFreq   = (missionNamespace getVariable ["CO_rus_tankFrequency", 3]) max 1;

// Live RUS_ADV infantry: global (the hard cap) and in-zone (the presence we
// maintain). Vehicles are excluded from the head-count so armor never starves
// the infantry budget.
private _rusMen = allUnits select {
    alive _x && _x isKindOf "Man" &&
    ((group _x) getVariable ["CO_faction", ""] == "RUS_ADV")
};
private _globalActive = count _rusMen;
private _zoneActive = { (_x distance2D _zoneCenter) <= (_zoneRadius + 400) } count _rusMen;

private _deficit = (_zoneTarget - _zoneActive) max 0;
private _room    = (_maxActive - _globalActive) max 0;
private _toSpawn = (_deficit min _perWaveMax) min _room;

if (_toSpawn <= 0) exitWith {
    diag_log format [
        "[CO] RUS siege at strength (%1 in-zone / target %2, %3/%4 global).",
        _zoneActive, _zoneTarget, _globalActive, _maxActive
    ];
};

CO_rus_waveCount = CO_rus_waveCount + 1;
private _waveNo = CO_rus_waveCount;

// Approaches ring the zone from the north (over the airstrip) and the east,
// so the assault pushes INTO the town/airstrip the player defends.
private _approaches = [
    [11300, 13700, 0],
    [11950, 13560, 0],
    [12750, 12900, 0],
    [12650, 12150, 0]
];

private _infantryClasses = ["O_Soldier_F", "O_Soldier_AR_F", "O_Medic_F", "O_Soldier_GL_F", "O_Soldier_LAT_F"];

private _prepUnit = {
    params ["_unit"];
    _unit setVariable ["CO_faction", "RUS_ADV", true];
    _unit setVariable ["CO_advanceLane", "north", true];
    _unit setUnitPos "UP";
    _unit setBehaviour "COMBAT";
    _unit setCombatMode "RED";
    _unit allowFleeing 0;
    _unit setSkill ["aimingAccuracy", 0.32];
    _unit setSkill ["aimingShake", 0.42];
    _unit setSkill ["spotDistance", 0.85];
    _unit setSkill ["spotTime", 0.75];
    _unit setSkill ["courage", 1];
    // No per-death replacement EH: repopulation is handled centrally by this
    // maintainer, which keeps spawn load bounded and predictable.
};

private _newSquad = {
    // deleteWhenEmpty so wiped groups auto-reclaim (avoids an east-side group
    // leak that would eventually starve createGroup and break spawning).
    private _grp = createGroup [east, true];
    _grp setVariable ["CO_faction", "RUS_ADV", true];
    _grp setVariable ["CO_advanceLane", "north", true];
    _grp
};

// ---- Infantry: split the deficit into ~6-man assault squads ----
private _remaining = _toSpawn;
while { _remaining > 0 } do {
    private _sz = _remaining min 6;
    private _spawnPos = selectRandom _approaches;
    private _grp = call _newSquad;
    _grp setVariable ["CO_advanceSpawnPos", _spawnPos, true];
    for "_i" from 1 to _sz do {
        private _u = _grp createUnit [selectRandom _infantryClasses, _spawnPos, [], 12, "FORM"];
        [_u] call _prepUnit;
    };
    [_grp] call co_main_fnc_russianAdvanceWaypoints;
    _remaining = _remaining - _sz;
};

// ---- Armor, gated on remaining global room AND a hull cap ----
// Crews count against _maxActive, but the hulls themselves do not — so
// without a separate vehicle cap, armor could quietly pile up around the
// town if the player kills infantry but leaves the vehicles alone.
private _liveRoom = (_maxActive - _globalActive - _toSpawn) max 0;
private _maxVehicles = missionNamespace getVariable ["CO_rus_maxVehicles", 6];
private _vehActive = count (vehicles select {
    alive _x && !(_x isKindOf "Man") &&
    (_x getVariable ["CO_faction", ""] == "RUS_ADV")
});

private _spawnVehicleGroup = {
    params ["_vehicleClasses", ["_cargoCount", 0]];
    private _spawnPos = selectRandom _approaches;
    private _grp = call _newSquad;
    _grp setVariable ["CO_advanceSpawnPos", _spawnPos, true];

    private _veh = createVehicle [selectRandom _vehicleClasses, _spawnPos, [], 0, "NONE"];
    _veh setVariable ["CO_faction", "RUS_ADV", true];
    _veh setVariable ["CO_advanceLane", "north", true];
    _veh setVehicleReceiveRemoteTargets true;
    _veh setVehicleReportRemoteTargets true;
    _veh engineOn true;

    private _driver = _grp createUnit ["O_Soldier_F", _spawnPos, [], 0, "CARGO"];
    [_driver] call _prepUnit;
    _driver moveInDriver _veh;

    private _gunner = _grp createUnit ["O_Soldier_F", _spawnPos, [], 0, "CARGO"];
    [_gunner] call _prepUnit;
    if (_veh emptyPositions "gunner" > 0) then { _gunner moveInGunner _veh } else { _gunner moveInCargo _veh };

    private _cmd = _grp createUnit ["O_Soldier_F", _spawnPos, [], 0, "CARGO"];
    [_cmd] call _prepUnit;
    if (_veh emptyPositions "commander" > 0) then { _cmd moveInCommander _veh } else { _cmd moveInCargo _veh };

    for "_i" from 1 to _cargoCount do {
        if (_veh emptyPositions "cargo" > 0) then {
            private _cargo = _grp createUnit [selectRandom _infantryClasses, _spawnPos, [], 0, "CARGO"];
            [_cargo] call _prepUnit;
            _cargo moveInCargo _veh;
        };
    };

    [_grp] call co_main_fnc_russianAdvanceWaypoints;
};

private _spawnedApc = false;
private _spawnedTank = false;

// Armed MRAP every top-up (3 crew) when there is room and hull headroom.
if (_liveRoom >= 3 && _vehActive < _maxVehicles) then {
    [["O_MRAP_02_hmg_F", "O_MRAP_02_gmg_F"], 2] call _spawnVehicleGroup;
    _liveRoom = _liveRoom - 5;   // 3 crew + up to 2 cargo
    _vehActive = _vehActive + 1;
};

// APC on the armor cadence.
if (_waveNo % _armorFreq == 0 && _liveRoom >= 4 && _vehActive < _maxVehicles) then {
    [["O_APC_Wheeled_02_rcws_F", "O_APC_Tracked_02_cannon_F"], 4] call _spawnVehicleGroup;
    _liveRoom = _liveRoom - 7;
    _vehActive = _vehActive + 1;
    _spawnedApc = true;
};

// MBT on the tank cadence.
if (_waveNo % _tankFreq == 0 && _liveRoom >= 3 && _vehActive < _maxVehicles) then {
    [["O_MBT_02_cannon_F"], 0] call _spawnVehicleGroup;
    _spawnedTank = true;
};

diag_log format [
    "[CO] RUS siege wave %1: +%2 infantry (zone %3->~%4/%5), APC=%6 Tank=%7, global %8/%9.",
    _waveNo, _toSpawn, _zoneActive, (_zoneActive + _toSpawn), _zoneTarget,
    _spawnedApc, _spawnedTank, _globalActive, _maxActive
];
