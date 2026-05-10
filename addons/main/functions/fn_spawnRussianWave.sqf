// fn_spawnRussianWave.sqf
if (isNil "CO_rus_waveCount") then { CO_rus_waveCount = 0; };

private _spawnX = missionNamespace getVariable ["CO_rus_spawnX", 14100];
private _lanes = [
    ["north",   [_spawnX - random 120, 12300 + random 220 - 110, 0]],
    ["central", [_spawnX - random 120,  7800 + random 260 - 130, 0]],
    ["south",   [_spawnX - random 120,  3300 + random 260 - 130, 0]]
];

private _waveGroups = [];
private _waveSize = (missionNamespace getVariable ["CO_rus_unitsPerWave", 12]) max 1;
private _unitsPerGroup = (ceil (_waveSize / 3)) max 1;

// Infantry squad
for "_w" from 0 to 2 do {
    private _lane = _lanes select _w;
    private _spawnPos = _lane select 1;
    private _grp = createGroup east;
    _grp setVariable ["CO_faction", "RUS_ADV"];
    _grp setVariable ["CO_advanceLane", _lane select 0];

    for "_i" from 1 to _unitsPerGroup do {
        private _u = _grp createUnit [
            selectRandom ["O_Soldier_F","O_Soldier_AR_F","O_Medic_F"],
            _spawnPos, [], 8, "FORM"
        ];
        _u setUnitPos "UP";
        _u setBehaviour "COMBAT";
        _u setCombatMode "RED";
        _u allowFleeing 0;
    };

    // Give westward advance objective
    [_grp] call co_main_fnc_russianAdvanceWaypoints;
    _waveGroups pushBack _grp;
};

// Armored support every 3rd wave
CO_rus_waveCount = CO_rus_waveCount + 1;
if (CO_rus_waveCount % 3 == 0) then {
    private _apcLane = selectRandom _lanes;
    private _apcPos = (_apcLane select 1) vectorAdd [-80, 0, 0];
    private _apcGrp = createGroup east;
    _apcGrp setVariable ["CO_faction", "RUS_ADV"];
    _apcGrp setVariable ["CO_advanceLane", _apcLane select 0];
    private _apc = "O_APC_Wheeled_02_rcws_F" createVehicle _apcPos;
    private _driver = _apcGrp createUnit ["O_Soldier_F", _apcPos, [], 0, "CARGO"];
    _driver moveInDriver _apc;
    private _gunner = _apcGrp createUnit ["O_Soldier_F", _apcPos, [], 0, "CARGO"];
    _gunner moveInGunner _apc;
    [_apcGrp] call co_main_fnc_russianAdvanceWaypoints;
};

diag_log format ["[CO] Russian wave %1 spawned near front on north/central/south lanes.", CO_rus_waveCount];