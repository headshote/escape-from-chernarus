// fn_spawnRussianWave.sqf
if (isNil "CO_rus_waveCount") then { CO_rus_waveCount = 0; };

// Population cap — prevent unbounded RUS_ADV growth (round 9 fix:
// Krasnostav FPS drop). If the live RUS_ADV count is already at or
// above CO_rus_maxActive, skip this wave entirely instead of piling
// on +30 more units.
private _maxActive = missionNamespace getVariable ["CO_rus_maxActive", 80];
private _activeCount = {
    alive _x &&
    ((group _x) getVariable ["CO_faction",""] == "RUS_ADV")
} count allUnits;
if (_activeCount >= _maxActive) exitWith {
    diag_log format ["[CO] RUS_ADV wave skipped (%1/%2 active).", _activeCount, _maxActive];
};

private _spawnX     = missionNamespace getVariable ["CO_rus_spawnX", 13000];
private _northX     = missionNamespace getVariable ["CO_rus_spawnXNorth", 12800];
private _armorFreq  = missionNamespace getVariable ["CO_rus_armorFrequency", 3];
private _tankFreq   = missionNamespace getVariable ["CO_rus_tankFrequency", 4];

// Lane allocation — the north (Krasnostav) lane gets the heaviest weight
// because that's the player's spawn target. South/central are lighter.
private _lanes = [
    ["north",   [_northX - random 120, 12300 + random 220 - 110, 0], 0.50],
    ["central", [_spawnX - random 120,  7800 + random 260 - 130, 0], 0.28],
    ["south",   [_spawnX - random 120,  3300 + random 260 - 130, 0], 0.22]
];

private _waveSize = (missionNamespace getVariable ["CO_rus_unitsPerWave", 24]) max 3;

private _spawnGroup = {
    params ["_lane", "_count"];
    private _laneName = _lane select 0;
    private _spawnPos = _lane select 1;
    private _grp = createGroup east;
    _grp setVariable ["CO_faction", "RUS_ADV"];
    _grp setVariable ["CO_advanceLane", _laneName];
    _grp setVariable ["CO_advanceSpawnPos", _spawnPos, true];

    for "_i" from 1 to _count do {
        private _u = _grp createUnit [
            selectRandom ["O_Soldier_F","O_Soldier_AR_F","O_Medic_F","O_Soldier_GL_F","O_Soldier_LAT_F"],
            _spawnPos, [], 8, "FORM"
        ];
        _u setVariable ["CO_advanceLane", _laneName, true];
        _u setUnitPos "UP";
        _u setBehaviour "COMBAT";
        _u setCombatMode "RED";
        _u allowFleeing 0;
        // Killed EH for 1:1 replenishment (separate from the generic
        // hostile-unit handler so we don't double-spawn).
        _u addEventHandler ["Killed", {
            params ["_killed"];
            [_killed] spawn {
                params ["_dead"];
                sleep (2 + random 4);
                [_dead] call co_main_fnc_spawnRussianReplacement;
            };
        }];
    };

    [_grp] call co_main_fnc_russianAdvanceWaypoints;
    _grp
};

// Allocate per-lane infantry counts by weight
private _waveGroups = [];
{
    private _laneCount = round (_waveSize * (_x select 2));
    if (_laneCount < 2) then { _laneCount = 2 };
    private _grp = [_x, _laneCount] call _spawnGroup;
    _waveGroups pushBack _grp;
} forEach _lanes;

CO_rus_waveCount = CO_rus_waveCount + 1;

// ---- APC support every Nth wave (north lane prioritized) ----
if (CO_rus_waveCount % _armorFreq == 0) then {
    private _apcLane = _lanes select 0; // north — Krasnostav axis
    private _apcPos = (_apcLane select 1) vectorAdd [-40, 0, 0];
    private _apcGrp = createGroup east;
    _apcGrp setVariable ["CO_faction", "RUS_ADV"];
    _apcGrp setVariable ["CO_advanceLane", _apcLane select 0];
    private _apcCls = selectRandom ["O_APC_Wheeled_02_rcws_F","O_APC_Tracked_02_cannon_F"];
    private _apc = _apcCls createVehicle _apcPos;
    private _driver = _apcGrp createUnit ["O_Soldier_F", _apcPos, [], 0, "CARGO"];
    _driver moveInDriver _apc;
    private _gunner = _apcGrp createUnit ["O_Soldier_F", _apcPos, [], 0, "CARGO"];
    _gunner moveInGunner _apc;
    private _cmd    = _apcGrp createUnit ["O_Soldier_F", _apcPos, [], 0, "CARGO"];
    _cmd moveInCommander _apc;
    _apc addEventHandler ["Killed", {
        params ["_killed"];
        [_killed] spawn {
            sleep 10; [_this select 0] call co_main_fnc_spawnRussianReplacement;
        };
    }];
    [_apcGrp] call co_main_fnc_russianAdvanceWaypoints;
};

// ---- Main battle tank every Nth wave (Krasnostav axis) ----
if (CO_rus_waveCount % _tankFreq == 0) then {
    private _tankLane = _lanes select 0; // north — Krasnostav
    private _tankPos = (_tankLane select 1) vectorAdd [-80, 30, 0];
    private _tankGrp = createGroup east;
    _tankGrp setVariable ["CO_faction", "RUS_ADV"];
    _tankGrp setVariable ["CO_advanceLane", _tankLane select 0];
    private _tank = "O_MBT_02_cannon_F" createVehicle _tankPos;
    private _td = _tankGrp createUnit ["O_Soldier_F", _tankPos, [], 0, "CARGO"];
    _td moveInDriver _tank;
    private _tg = _tankGrp createUnit ["O_Soldier_F", _tankPos, [], 0, "CARGO"];
    _tg moveInGunner _tank;
    private _tc = _tankGrp createUnit ["O_Soldier_F", _tankPos, [], 0, "CARGO"];
    _tc moveInCommander _tank;
    [_tankGrp] call co_main_fnc_russianAdvanceWaypoints;
};

diag_log format [
    "[CO] Russian wave %1: north spawnX=%2 weave size=%3, APC=%4, Tank=%5.",
    CO_rus_waveCount, _northX, _waveSize,
    (CO_rus_waveCount % _armorFreq == 0),
    (CO_rus_waveCount % _tankFreq == 0)
];
