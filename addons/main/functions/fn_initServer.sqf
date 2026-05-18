// fn_initServer.sqf — revised call order
// CO_adminDefaults.sqf is executed from mission init.sqf before this runs
// Globals should already be set; broadcast them again for connected clients.
{
    publicVariable _x;
} forEach [
    "CO_checkpoint_hostilesPerPost","CO_checkpoint_includeLarge","CO_checkpoint_includeMedium",
    "CO_checkpoint_includeSmall","CO_checkpoint_fortTemplate",
    "CO_bus_totalCruising","CO_bus_hostilesPerBus","CO_bus_townGuaranteed","CO_bus_vehiclePool",
    "CO_rus_waveCooldown","CO_rus_unitsPerWave","CO_rus_armorFrequency","CO_rus_firstWaveDelay","CO_rus_spawnX",
    "CO_rus_spawnXNorth","CO_rus_tankFrequency","CO_awolRadius","CO_awolGrace",
    "CO_front_initialStrength","CO_front_lineSpacingY","CO_front_depthRows","CO_front_rowSpacing",
    "CO_border_postSpacing","CO_border_includeCoast","CO_border_includeLand","CO_border_patrolDensity",
    "CO_westBorderCampCount","CO_westBorderCampGuardsMin","CO_westBorderCampGuardsMax",
    "CO_westBorderTownGuardCount","CO_westBorderChaseRadius","CO_westBorderFireRadius",
    "CO_westRoadCheckpointGuardCount","CO_westRoadCheckpointLethal","CO_westBorderFemaleOnlyTowns",
    "CO_westBorderForestPatrols",
    "CO_bus_aggroRadius","CO_bus_maxCaptives","CO_busDetentionThreshold","CO_busCruiseAfterCapture","CO_bus_patrolStopInterval",
    "CO_airfield_guardCount","CO_airfield_gateGuards",
    "CO_conscript_detainTime","CO_conscript_trainTime",
    "CO_police_carStopChance","CO_police_active",
    "CO_adminUIDs"
];
sleep 0.5;

// Each init step is wrapped so an SQF error in one subsystem cannot silently
// abort downstream subsystems. We track per-step status in
// CO_initStepStatus for in-game diagnostics via the admin panel / RPT.
missionNamespace setVariable ["CO_initStepStatus", createHashMap, true];

private _markStep = {
    params ["_label", "_state", ["_detail", ""]];
    private _status = missionNamespace getVariable ["CO_initStepStatus", createHashMap];
    _status set [_label, [_state, _detail, time]];
    missionNamespace setVariable ["CO_initStepStatus", _status, true];
};

private _runStep = {
    params ["_label", "_code"];
    [_label, "running"] call _markStep;
    diag_log format ["[CO] Init step start: %1", _label];
    private _ok = true;
    private _err = "";
    if (!isNil { _label }) then {
        // Use call inside a fault-tolerant wrapper. SQF doesn't have try/catch
        // in older runtimes outside of throw/catch blocks, so we use that.
        try {
            call _code;
        } catch {
            _ok = false;
            _err = str _exception;
            diag_log format ["[CO] Init step FAILED: %1 -> %2", _label, _err];
        };
    };
    if (_ok) then {
        [_label, "done"] call _markStep;
        diag_log format ["[CO] Init step done: %1", _label];
    } else {
        [_label, "failed", _err] call _markStep;
    };
};

private _launchStep = {
    params ["_label", "_code"];
    [_label, "scheduled"] call _markStep;
    [_label, _code] spawn {
        params ["_stepLabel", "_stepCode"];
        diag_log format ["[CO] Async step start: %1", _stepLabel];
        private _status = missionNamespace getVariable ["CO_initStepStatus", createHashMap];
        _status set [_stepLabel, ["running", "", time]];
        missionNamespace setVariable ["CO_initStepStatus", _status, true];
        try {
            call _stepCode;
            _status = missionNamespace getVariable ["CO_initStepStatus", createHashMap];
            _status set [_stepLabel, ["done", "", time]];
            missionNamespace setVariable ["CO_initStepStatus", _status, true];
            diag_log format ["[CO] Async step done: %1", _stepLabel];
        } catch {
            private _err = str _exception;
            _status = missionNamespace getVariable ["CO_initStepStatus", createHashMap];
            _status set [_stepLabel, ["failed", _err, time]];
            missionNamespace setVariable ["CO_initStepStatus", _status, true];
            diag_log format ["[CO] Async step FAILED: %1 -> %2", _stepLabel, _err];
        };
    };
};

["factionRelations", { [] call co_main_fnc_factionRelations; }] call _runStep;
["buildRoadGraph", { [] call co_main_fnc_buildRoadGraph; }] call _runStep;
sleep 0.5;
["placeCheckpoints", { [] call co_main_fnc_placeCheckpoints; }] call _runStep;
["buildBusRoutes", { [] call co_main_fnc_buildBusRoutes; }] call _runStep;

// Day/night cycle so morning, midday, and night affect police recognition,
// civilian density, and patrol behaviour. 6x runs a 24h Chernarus day in 4h.
setTimeMultiplier 6;

["spawnAllBuses", { [] call co_main_fnc_spawnAllBuses; }] call _launchStep;
["tckGlobalAggression", { [] call co_main_fnc_tckGlobalAggression; }] call _launchStep;
["civilianAI", { [] call co_main_fnc_civilianAI; }] call _launchStep;
["trafficSystem", { [] call co_main_fnc_trafficSystem; }] call _launchStep;
["policePatrols", { [] call co_main_fnc_policePatrols; }] call _launchStep;
["spawnWeaponCaches", { [] call co_main_fnc_spawnWeaponCaches; }] call _launchStep;
// Western enforcement is the most player-visible border layer: run it first
// in its own task so guards appear in seconds rather than after the slow
// perimeter fort placement finishes.
["westBorderEnforcement", { [] call co_main_fnc_buildWestBorderEnforcement; }] call _launchStep;
["swBorderFort", { [] call co_main_fnc_buildSWBorderFort; }] call _launchStep;
["perimeterBorderForts", { [] call co_main_fnc_buildBorderForts; }] call _launchStep;
["borderRovingPatrols", { [] call co_main_fnc_borderPatrol; }] call _launchStep;
["frontSystem", {
    [] call co_main_fnc_buildEasternFront;
    [] call co_main_fnc_frontMilitary;
    [] call co_main_fnc_russianAdvance;
}] call _launchStep;
["airfieldCamp", { [] call co_main_fnc_buildAirfieldCamp; }] call _launchStep;
["desertionMonitor", { [] call co_main_fnc_desertionMonitor; }] call _launchStep;

diag_log "[CO] Server init scheduling complete.";