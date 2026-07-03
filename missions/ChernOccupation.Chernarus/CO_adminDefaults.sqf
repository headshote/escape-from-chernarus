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
CO_rus_waveCooldown             = 70;     // seconds between Russian waves
CO_rus_unitsPerWave             = 42;     // total infantry across the three lanes
CO_rus_armorFrequency           = 1;      // every Nth wave gets an APC
CO_rus_tankFrequency            = 3;      // every Nth wave gets an MBT
CO_rus_firstWaveDelay           = 8;      // seconds after init before first visible wave
CO_rus_spawnX                   = 13000;  // central/south lane spawn (closer to front; was 14100)
CO_rus_spawnXNorth              = 12550;  // north (Krasnostav) lane spawn
CO_rus_maxActive                = 120;    // hard cap on live RUS_ADV units
CO_awolRadius                   = 1800;   // base Krasnostav safe radius before AWOL warning logic
CO_frontSafeZones               = [
    [[11200, 12300, 0], 1800, "Krasnostav town/outskirts"],
    [[12050, 12650, 0], 1400, "Krasnostav airfield"],
    [[11200, 13600, 0], 1500, "north forest staging area"],
    [[12150, 12300, 0], 1200, "forward defense line"]
];
CO_awolGrace                    = 60;     // seconds outside Krasnostav before AWOL flag
CO_front_initialStrength        = 60;
CO_front_lineSpacingY           = 280;    // meters between front nodes N-S (was 200; lighter default)
CO_front_depthRows              = 2;      // rows of fortification
CO_front_rowSpacing             = 60;

// --- Border Patrol ---
CO_border_postSpacing           = 1000;   // meters between border posts (default sparse to avoid AI overload)
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
CO_bus_aggroRadius              = 260;    // detection range while cruising
CO_bus_maxCaptives              = 3;      // force delivery once truck holds this many
CO_busDetentionThreshold        = 2;      // immediate delivery threshold
CO_busCruiseAfterCapture        = 60;     // seconds bus keeps hunting after first capture
CO_bus_patrolStopInterval       = 75;     // seconds between proactive bus dismount-and-search stops

// --- Airfield / Training Camp ---
CO_airfield_guardCount          = 14;     // total roving guards inside
CO_airfield_gateGuards          = 4;      // per gate

// --- Conscription Pipeline ---
CO_conscript_detainTime         = 300;    // seconds in detention before transfer
CO_conscript_trainTime          = 600;    // seconds in training before front deploy

// --- Police ---
CO_police_carStopChance         = 0.08;
CO_police_active                = true;
CO_difficultyPreset             = "Standard"; // Quiet Occupation | Standard | Martial Law
CO_suspicion_baseRate           = 12;
CO_search_duration              = 150;
CO_chase_speedCoef              = 1.12;
CO_chase_aiStaminaDrain         = 0.42;
CO_chase_tackleRange            = 2.2;
CO_chase_tackleTime             = 1.5;
CO_tracker_speedCoef            = 1.25;
CO_checkpoint_maxCount          = 20;
CO_border_innerJitter           = 200;
CO_heat_decayPerMinute          = 5;
CO_kpiLogInterval               = 120;
CO_maxSimultaneousChases        = 6;

// --- Crime & witness system (repair R1-a) ---
CO_crime_killWanted             = 60;     // wanted added for a WITNESSED kill of TCK/police
CO_crime_woundWanted            = 40;     // ... for a witnessed wounding
CO_crime_gunfireWanted          = 10;     // ... per reported gunshot (throttled)
CO_checkpoint_chaseLeash        = 250;    // max chase distance from a checkpoint before radio handoff
CO_police_chaseDeadline         = 180;    // seconds before a police foot chase converts to search
CO_police_returnFireWindow      = 10;     // seconds since the player's last shot that police keep trading fire
CO_lockdown_extraPatrols        = 2;      // temporary foot-patrol pairs after witnessed violence
CO_lockdown_duration            = 600;    // seconds

// --- Training / AWOL ---
CO_training_escapeRadius        = 250;    // metres from airfield center before a recruit counts as escaping
CO_awol_detainChance            = 0.5;    // chance a squad detains (vs executes) a cornered deserter

// --- Admin ---
CO_adminUIDs                    = [76561198054336866];     // add Steam64 UIDs allowed to open the admin panel

// Broadcast all to clients
{
    publicVariable _x;
} forEach [
    "CO_checkpoint_hostilesPerPost","CO_checkpoint_includeLarge","CO_checkpoint_includeMedium",
    "CO_checkpoint_includeSmall","CO_checkpoint_fortTemplate",
    "CO_bus_totalCruising","CO_bus_hostilesPerBus","CO_bus_townGuaranteed","CO_bus_vehiclePool",
    "CO_rus_waveCooldown","CO_rus_unitsPerWave","CO_rus_armorFrequency","CO_rus_firstWaveDelay","CO_rus_spawnX",
    "CO_rus_spawnXNorth","CO_rus_tankFrequency","CO_rus_maxActive","CO_awolRadius","CO_frontSafeZones","CO_awolGrace",
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
    "CO_difficultyPreset","CO_suspicion_baseRate","CO_search_duration",
    "CO_chase_speedCoef","CO_chase_aiStaminaDrain","CO_chase_tackleRange","CO_chase_tackleTime",
    "CO_tracker_speedCoef","CO_checkpoint_maxCount","CO_border_innerJitter","CO_heat_decayPerMinute",
    "CO_kpiLogInterval","CO_maxSimultaneousChases",
    "CO_crime_killWanted","CO_crime_woundWanted","CO_crime_gunfireWanted",
    "CO_checkpoint_chaseLeash","CO_police_chaseDeadline","CO_police_returnFireWindow",
    "CO_lockdown_extraPatrols","CO_lockdown_duration",
    "CO_training_escapeRadius","CO_awol_detainChance",
    "CO_adminUIDs"
];
