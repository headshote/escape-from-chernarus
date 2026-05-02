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

[] call co_main_fnc_factionRelations;    // setFriend calls
[] call co_main_fnc_buildRoadGraph;      // build CO_roadGraph + CO_settlements
sleep 0.5;
[] call co_main_fnc_placeCheckpoints;    // procedural checkpoints from graph
[] call co_main_fnc_buildBorderForts;    // perimeter watchtowers + outposts
[] call co_main_fnc_buildEasternFront;   // front defense line
[] call co_main_fnc_buildAirfieldCamp;   // NW airfield perimeter + gates
[] call co_main_fnc_buildBusRoutes;      // derive routes from road graph
[] call co_main_fnc_spawnAllBuses;       // spawn buses on derived routes
[] call co_main_fnc_civilianAI;          // civilian NPC spawner
[] call co_main_fnc_trafficSystem;       // car traffic
[] call co_main_fnc_frontMilitary;       // spawn initial CRN_FRONT defense line
[] spawn co_main_fnc_russianAdvance;     // eastern front wave loop
[] spawn co_main_fnc_desertionMonitor;   // per-player check loop
[] spawn co_main_fnc_policePatrols;      // police car patrols in towns
[] call co_main_fnc_spawnWeaponCaches;   // hidden weapon caches