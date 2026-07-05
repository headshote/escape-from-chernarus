// fn_russianAdvance.sqf — Krasnostav siege controller (server)
//
// Reworked from a westward-marching "front" into a PERMANENT siege of
// Krasnostav and the airstrip immediately to its north. The old design
// spread each wave across north/central/south lanes and marched the central
// and south lanes to Chernogorsk, spending the global unit budget far from
// where deployed conscripts actually fight — so a player arriving at the
// front later in the match often found it deserted.
//
// Now every Russian is committed to the Krasnostav/airstrip zone and this
// loop keeps a target headcount alive there on a short cadence: heavy,
// effectively endless waves, but hard-capped so AI load never runs away.

if (!isServer) exitWith {};

// --- Ground being fought over -------------------------------------------
CO_rus_townPos     = [11200, 12300, 0];   // Krasnostav town
CO_rus_airstripPos = [11600, 13050, 0];   // airstrip just to the north
CO_rus_zoneCenter  = [11400, 12650, 0];   // midpoint the siege orbits
CO_rus_zoneRadius  = 1500;
publicVariable "CO_rus_townPos";
publicVariable "CO_rus_airstripPos";
publicVariable "CO_rus_zoneCenter";
publicVariable "CO_rus_zoneRadius";

// Front-line marker sits on Krasnostav — the fight never leaves.
CO_rus_advanceFront = 11400;
publicVariable "CO_rus_advanceFront";

// --- Tunables (defaults if CO_adminDefaults didn't set them) -------------
if (isNil "CO_rus_waveCooldown")   then { CO_rus_waveCooldown = 25; };   // seconds between top-ups
if (isNil "CO_rus_firstWaveDelay") then { CO_rus_firstWaveDelay = 8; };
if (isNil "CO_rus_zoneTarget")     then { CO_rus_zoneTarget = 45; };     // live RUS infantry held in-zone
if (isNil "CO_rus_maxActive")      then { CO_rus_maxActive = 95; };      // global hard cap (server safety)
if (isNil "CO_rus_unitsPerWave")   then { CO_rus_unitsPerWave = 20; };   // max infantry added per top-up
if (isNil "CO_rus_armorFrequency") then { CO_rus_armorFrequency = 2; };
if (isNil "CO_rus_tankFrequency")  then { CO_rus_tankFrequency = 3; };

// Kept for compatibility with fn_checkTownCapture / fn_desertionMonitor
// readers; the siege itself no longer marches the front across these.
CO_rus_townObjectives = [
    ["Krasnostav",     11200, "marker_krasnostav", [11200, 12300, 0]],
    ["Berezino",       12300, "marker_berezino",   [12300,  9700, 0]],
    ["Elektrozavodsk", 10200, "marker_elektro",    [10200,  2300, 0]],
    ["Chernogorsk",     6400, "marker_cherno",     [ 6400,  2400, 0]],
    ["Balota",          4500, "marker_balota",     [ 4500,  2500, 0]]
];

[] spawn {
    sleep CO_rus_firstWaveDelay;
    diag_log "[CO] Russian siege of Krasnostav: online.";
    [] call co_main_fnc_updateFrontLine;
    while { true } do {
        [] call co_main_fnc_spawnRussianWave;   // tops the zone up to target
        sleep CO_rus_waveCooldown;
    };
};
