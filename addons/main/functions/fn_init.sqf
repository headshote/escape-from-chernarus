// ---- Admin-tunable globals (overridden by admin panel / CBA settings) ----
CO_checkpoint_hostilesPerPost = 4;
CO_bus_totalCruising           = 30;
CO_bus_hostilesPerBus          = 5;
CO_bus_townGuaranteed          = 3;   // min buses in Cherno/Elektro/Berezino
CO_border_patrolDensity        = 1.0; // multiplier
CO_police_carStopChance        = 0.05;
CO_police_active               = true;

// ---- Spawn systems ----
[] spawn co_main_fnc_checkpoints;
[] spawn co_main_fnc_buses;
[] spawn co_main_fnc_borderPatrol;
[] spawn co_main_fnc_civilianAI;
[] spawn co_main_fnc_trafficSystem;

publicVariable "CO_checkpoint_hostilesPerPost";
publicVariable "CO_bus_totalCruising";
// ... broadcast rest