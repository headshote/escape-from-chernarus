// fn_initServer.sqf — revised call order
// CO_adminDefaults.sqf is executed from mission init.sqf before this runs
// Globals should already be set; broadcast them now in case they weren't\n{
    publicVariable _x;
} forEach [
    "CO_checkpoint_hostilesPerPost","CO_checkpoint_includeSmall",
    "CO_bus_totalCruising","CO_bus_hostilesPerBus","CO_bus_townGuaranteed",
    "CO_rus_waveCooldown","CO_rus_unitsPerWave","CO_front_initialStrength",
    "CO_border_postSpacing","CO_airfield_guardCount","CO_conscript_detainTime",
    "CO_conscript_trainTime","CO_police_carStopChance","CO_police_active"
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