// fn_initServer.sqf — revised call order
// CO_adminDefaults.sqf is executed from mission init.sqf before this runs
// Globals should already be set; broadcast them again for connected clients.
{
    publicVariable _x;
} forEach [
    "CO_checkpoint_hostilesPerPost","CO_checkpoint_includeLarge","CO_checkpoint_includeMedium",
    "CO_checkpoint_includeSmall","CO_checkpoint_fortTemplate",
    "CO_bus_totalCruising","CO_bus_hostilesPerBus","CO_bus_townGuaranteed","CO_bus_vehiclePool",
    "CO_rus_waveCooldown","CO_rus_unitsPerWave","CO_rus_armorFrequency",
    "CO_front_initialStrength","CO_front_lineSpacingY","CO_front_depthRows","CO_front_rowSpacing",
    "CO_border_postSpacing","CO_border_includeCoast","CO_border_includeLand","CO_border_patrolDensity",
    "CO_airfield_guardCount","CO_airfield_gateGuards",
    "CO_conscript_detainTime","CO_conscript_trainTime",
    "CO_police_carStopChance","CO_police_active",
    "CO_adminUIDs"
];
sleep 0.5;

private _runStep = {
    params ["_label", "_code"];
    diag_log format ["[CO] Init step start: %1", _label];
    call _code;
    diag_log format ["[CO] Init step done: %1", _label];
};

private _launchStep = {
    params ["_label", "_code"];
    [_label, _code] spawn {
        params ["_stepLabel", "_stepCode"];
        diag_log format ["[CO] Async step start: %1", _stepLabel];
        call _stepCode;
        diag_log format ["[CO] Async step done: %1", _stepLabel];
    };
};

["factionRelations", { [] call co_main_fnc_factionRelations; }] call _runStep;
["buildRoadGraph", { [] call co_main_fnc_buildRoadGraph; }] call _runStep;
sleep 0.5;
["placeCheckpoints", { [] call co_main_fnc_placeCheckpoints; }] call _runStep;
["buildBusRoutes", { [] call co_main_fnc_buildBusRoutes; }] call _runStep;

["spawnAllBuses", { [] call co_main_fnc_spawnAllBuses; }] call _launchStep;
["civilianAI", { [] call co_main_fnc_civilianAI; }] call _launchStep;
["trafficSystem", { [] call co_main_fnc_trafficSystem; }] call _launchStep;
["policePatrols", { [] call co_main_fnc_policePatrols; }] call _launchStep;
["spawnWeaponCaches", { [] call co_main_fnc_spawnWeaponCaches; }] call _launchStep;
["borderSystem", {
    [] call co_main_fnc_buildBorderForts;
    [] call co_main_fnc_borderPatrol;
}] call _launchStep;
["frontSystem", {
    [] call co_main_fnc_buildEasternFront;
    [] call co_main_fnc_frontMilitary;
    [] call co_main_fnc_russianAdvance;
}] call _launchStep;
["airfieldCamp", { [] call co_main_fnc_buildAirfieldCamp; }] call _launchStep;
["desertionMonitor", { [] call co_main_fnc_desertionMonitor; }] call _launchStep;

diag_log "[CO] Server init scheduling complete.";