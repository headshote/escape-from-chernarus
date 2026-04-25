// ============================================================
// CO_adminDefaults.sqf — all tunable globals
// Overridden by CBA settings UI or admin panel dialog.
// ============================================================

// --- Checkpoints ---
CO_checkpoint_hostilesPerPost   = 4;      // guards per checkpoint
CO_checkpoint_includeLarge      = true;   // checkpoints on large-town roads
CO_checkpoint_includeMedium     = true;   // checkpoints on medium roads
CO_checkpoint_includeSmall      = false;  // small settlement roads (raises difficulty)
CO_checkpoint_fortTemplate      = "checkpoint_light"; // "checkpoint_light" | "checkpoint_heavy"

// --- Buses ---
CO_bus_totalCruising            = 30;     // total buses on map
CO_bus_hostilesPerBus           = 5;      // hostiles per bus
CO_bus_townGuaranteed           = 3;      // min intra-town buses per large city
CO_bus_vehiclePool              = ["C_Van_01_transport_F","C_Truck_02_transport_F"];

// --- Eastern Front ---
CO_rus_waveCooldown             = 180;    // seconds between Russian waves
CO_rus_unitsPerWave             = 12;
CO_rus_armorFrequency           = 3;      // every Nth wave gets an APC
CO_front_initialStrength        = 60;
CO_front_lineSpacingY           = 200;    // meters between front nodes N-S
CO_front_depthRows              = 2;      // rows of fortification
CO_front_rowSpacing             = 50;

// --- Border Patrol ---
CO_border_postSpacing           = 600;    // meters between border posts
CO_border_includeCoast          = true;
CO_border_includeLand           = true;
CO_border_patrolDensity         = 1.0;    // multiplier on guard counts

// --- Airfield / Training Camp ---
CO_airfield_guardCount          = 14;     // total roving guards inside
CO_airfield_gateGuards          = 4;      // per gate

// --- Conscription Pipeline ---
CO_conscript_detainTime         = 300;    // seconds in detention before transfer
CO_conscript_trainTime          = 600;    // seconds in training before front deploy

// --- Police ---
CO_police_carStopChance         = 0.05;
CO_police_active                = true;

// Broadcast all to clients
{
    publicVariable _x;
} forEach [
    "CO_checkpoint_hostilesPerPost","CO_checkpoint_includeSmall",
    "CO_bus_totalCruising","CO_bus_hostilesPerBus","CO_bus_townGuaranteed",
    "CO_rus_waveCooldown","CO_rus_unitsPerWave","CO_front_initialStrength",
    "CO_border_postSpacing","CO_airfield_guardCount","CO_conscript_detainTime",
    "CO_conscript_trainTime","CO_police_carStopChance"
];