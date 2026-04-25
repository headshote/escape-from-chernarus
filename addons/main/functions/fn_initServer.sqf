// fn_initServer.sqf — revised call order
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
[] spawn co_main_fnc_russianAdvance;     // eastern front wave loop
[] spawn co_main_fnc_desertionMonitor;   // per-player check loop