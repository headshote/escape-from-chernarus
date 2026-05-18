// ============================================================
// fn_spawnRussianReplacement.sqf
//
// Spawns a single Russian replacement for a killed RUS_ADV unit
// at the same lane's northern spawn position, then attaches it
// to that lane's advance waypoints. Called from the Killed EH
// in fn_initHostileUnit / fn_spawnRussianWave.
//
// Goal: every dead OPFOR triggers 1 fresh replacement so the
// assault never thins out as the player kills units. Players
// asked: "for every killed opfor russian unit there should be
// 1 spawned immediately from the russian spawn start".
//
// Params:
//   _dead - the unit/vehicle that died
// ============================================================
params ["_dead"];

if (!isServer) exitWith {};
if (isNil "CO_rus_waveCount") then { CO_rus_waveCount = 0 };

// Population cap — prevent unbounded RUS_ADV growth that caused
// severe FPS drops near Krasnostav (round 9). Each killed unit
// adds 1 replacement; combined with the periodic wave spawner this
// could climb to hundreds of active units in the north sector,
// overwhelming AI simulation. If we're already at the cap, skip
// the replacement entirely.
private _maxActive = missionNamespace getVariable ["CO_rus_maxActive", 80];
private _activeCount = {
    alive _x &&
    !(_x isKindOf "AllVehicles" && {_x isKindOf "Vehicle" && !(_x isKindOf "Man")}) &&
    ((group _x) getVariable ["CO_faction",""] == "RUS_ADV")
} count allUnits;
if (_activeCount >= _maxActive) exitWith {
    diag_log format ["[CO] RUS_ADV replacement skipped (%1/%2 active).", _activeCount, _maxActive];
};

private _lane = _dead getVariable ["CO_advanceLane", "north"];
private _spawnX     = missionNamespace getVariable ["CO_rus_spawnX", 13000];
private _northX     = missionNamespace getVariable ["CO_rus_spawnXNorth", 12800];

private _spawnPos = switch (_lane) do {
    case "north":   { [_northX - random 80, 12300 + random 180 - 90, 0] };
    case "south":   { [_spawnX - random 80,  3300 + random 220 - 110, 0] };
    default         { [_spawnX - random 80,  7800 + random 220 - 110, 0] };
};

// Find a thin existing RUS_ADV group on the same lane to top up;
// otherwise create a fresh one with its own waypoints.
private _candidates = allGroups select {
    (_x getVariable ["CO_faction",""] == "RUS_ADV") &&
    (_x getVariable ["CO_advanceLane",""] == _lane) &&
    (count units _x) > 0 &&
    (count units _x) < 10
};
private _grp = if (count _candidates > 0) then {
    selectRandom _candidates
} else {
    private _newGrp = createGroup east;
    _newGrp setVariable ["CO_faction", "RUS_ADV", true];
    _newGrp setVariable ["CO_advanceLane", _lane, true];
    _newGrp setVariable ["CO_advanceSpawnPos", _spawnPos, true];
    [_newGrp] call co_main_fnc_russianAdvanceWaypoints;
    _newGrp
};

private _u = _grp createUnit [
    selectRandom ["O_Soldier_F","O_Soldier_AR_F","O_Medic_F","O_Soldier_GL_F","O_Soldier_LAT_F"],
    _spawnPos, [], 8, "FORM"
];
_u setVariable ["CO_advanceLane", _lane, true];
_u setUnitPos "UP";
_u setBehaviour "COMBAT";
_u setCombatMode "RED";
_u allowFleeing 0;
_u addEventHandler ["Killed", {
    params ["_killed"];
    [_killed] spawn {
        params ["_dead"];
        sleep (2 + random 4);
        [_dead] call co_main_fnc_spawnRussianReplacement;
    };
}];

diag_log format ["[CO] Russian replacement spawned on '%1' at %2.", _lane, _spawnPos];
