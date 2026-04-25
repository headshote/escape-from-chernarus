// fn_spawnRussianWave.sqf
if (isNil "CO_rus_waveCount") then { CO_rus_waveCount = 0; };

private _spawnX    = 15200; // east edge
private _spawnYMin = 2000;
private _spawnYMax = 11000;

private _waveGroups = [];

// Infantry squad
for "_w" from 0 to 2 do {
    private _spawnPos = [_spawnX - (random 200), _spawnYMin + random (_spawnYMax - _spawnYMin), 0];
    private _grp = createGroup east;
    _grp setVariable ["CO_faction", "RUS_ADV"];

    for "_i" from 0 to (CO_rus_unitsPerWave / 3) do {
        private _u = _grp createUnit [
            selectRandom ["O_Soldier_F","O_Soldier_AR_F","O_Medic_F"],
            _spawnPos, [], 8, "FORM"
        ];
        _u setUnitPos "UP";
    };

    // Give westward advance objective
    [_grp] call co_main_fnc_russianAdvanceWaypoints;
    _waveGroups pushBack _grp;
};

// Armored support every 3rd wave
CO_rus_waveCount = CO_rus_waveCount + 1;
if (CO_rus_waveCount % 3 == 0) then {
    private _apcPos = [_spawnX - 100, 6000 + random 3000, 0];
    private _apcGrp = createGroup east;
    _apcGrp setVariable ["CO_faction", "RUS_ADV"];
    private _apc = "O_APC_Wheeled_02_rcws_F" createVehicle _apcPos;
    private _driver = _apcGrp createUnit ["O_Soldier_F", _apcPos, [], 0, "CARGO"];
    _driver moveInDriver _apc;
    private _gunner = _apcGrp createUnit ["O_Soldier_F", _apcPos, [], 0, "CARGO"];
    _gunner moveInGunner _apc;
    [_apcGrp] call co_main_fnc_russianAdvanceWaypoints;
};