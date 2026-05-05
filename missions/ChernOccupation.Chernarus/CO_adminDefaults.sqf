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
CO_westBorderCampCount          = 14;     // number of active forest camps on west edge
CO_westBorderCampGuardsMin      = 2;
CO_westBorderCampGuardsMax      = 4;
CO_westBorderForestPatrols      = 5;      // foot patrols rovingthe forest strip
CO_westBorderTownGuardCount     = 6;
CO_westBorderChaseRadius        = 220;    // guards chase with melee inside this distance from their post
CO_westBorderFireRadius         = 95;     // once target gets this far from their post, guards escalate to gunfire
CO_westRoadCheckpointGuardCount = 6;
CO_westRoadCheckpointLethal     = true;
CO_westBorderFemaleOnlyTowns    = ["Komarovo", "Balota", "Pavlovo", "Myshkino", "Lopatino"];

// --- Hostile Buses (TCK trucks) ---
CO_bus_aggroRadius              = 140;    // detection range while cruising
CO_bus_maxCaptives              = 3;      // force delivery once truck holds this many
CO_busDetentionThreshold        = 2;      // immediate delivery threshold
CO_busCruiseAfterCapture        = 60;     // seconds bus keeps hunting after first capture

// --- Airfield / Training Camp ---
CO_airfield_guardCount          = 14;     // total roving guards inside
CO_airfield_gateGuards          = 4;      // per gate

// --- Conscription Pipeline ---
CO_conscript_detainTime         = 300;    // seconds in detention before transfer
CO_conscript_trainTime          = 600;    // seconds in training before front deploy

// --- Police ---
CO_police_carStopChance         = 0.05;
CO_police_active                = true;

// --- Admin ---
CO_adminUIDs                    = [76561198054336866];     // add Steam64 UIDs allowed to open the admin panel

// Broadcast all to clients
{
    publicVariable _x;
} forEach [
    "CO_checkpoint_hostilesPerPost","CO_checkpoint_includeLarge","CO_checkpoint_includeMedium",
    "CO_checkpoint_includeSmall","CO_checkpoint_fortTemplate",
    "CO_bus_totalCruising","CO_bus_hostilesPerBus","CO_bus_townGuaranteed","CO_bus_vehiclePool",
    "CO_rus_waveCooldown","CO_rus_unitsPerWave","CO_rus_armorFrequency",
    "CO_front_initialStrength","CO_front_lineSpacingY","CO_front_depthRows","CO_front_rowSpacing",
    "CO_border_postSpacing","CO_border_includeCoast","CO_border_includeLand","CO_border_patrolDensity",
    "CO_westBorderCampCount","CO_westBorderCampGuardsMin","CO_westBorderCampGuardsMax",
    "CO_westBorderTownGuardCount","CO_westBorderChaseRadius","CO_westBorderFireRadius",
    "CO_westRoadCheckpointGuardCount","CO_westRoadCheckpointLethal","CO_westBorderFemaleOnlyTowns",
    "CO_westBorderForestPatrols",
    "CO_bus_aggroRadius","CO_bus_maxCaptives","CO_busDetentionThreshold","CO_busCruiseAfterCapture",
    "CO_airfield_guardCount","CO_airfield_gateGuards",
    "CO_conscript_detainTime","CO_conscript_trainTime",
    "CO_police_carStopChance","CO_police_active",
    "CO_adminUIDs"
];