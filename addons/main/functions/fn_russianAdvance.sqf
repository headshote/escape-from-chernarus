// fn_russianAdvance.sqf — master controller, runs on server

CO_rus_advanceFront = 13000;   // current X coord of front line (was 14000; closer to Krasnostav)
publicVariable "CO_rus_advanceFront";
if (isNil "CO_rus_waveCooldown") then { CO_rus_waveCooldown = 100; };
if (isNil "CO_rus_unitsPerWave") then { CO_rus_unitsPerWave = 30; };
if (isNil "CO_rus_firstWaveDelay") then { CO_rus_firstWaveDelay = 12; };
if (isNil "CO_rus_spawnX") then { CO_rus_spawnX = 13000; };
if (isNil "CO_rus_spawnXNorth") then { CO_rus_spawnXNorth = 12800; };
if (isNil "CO_rus_tankFrequency") then { CO_rus_tankFrequency = 4; };
CO_rus_advanceSpeed = 0.5;     // front moves this many meters per second of game time (abstract)

// Town capture checkpoints west to east
CO_rus_townObjectives = [
    ["Krasnostav",     11200, "marker_krasnostav", [11200, 12300, 0]],
    ["Berezino",       12300, "marker_berezino",   [12300,  9700, 0]],
    ["Elektrozavodsk", 10200, "marker_elektro",    [10200,  2300, 0]],
    ["Chernogorsk",     6400, "marker_cherno",     [ 6400,  2400, 0]],
    ["Balota",          4500, "marker_balota",     [ 4500,  2500, 0]]
];

// Spawn loop. First wave fires after a brief warmup so players see Russian
// activity within ~30 seconds of mission start instead of waiting a full
// CO_rus_waveCooldown (default 180s) before anything spawns east.
[] spawn {
    sleep CO_rus_firstWaveDelay;
    diag_log "[CO] Russian advance: first wave triggering.";
    while { CO_rus_advanceFront > 3000 } do { // stop at west coast
        [] call co_main_fnc_spawnRussianWave;
        CO_rus_advanceFront = CO_rus_advanceFront - 120; // advance front abstraction
        publicVariable "CO_rus_advanceFront";
        [] call co_main_fnc_updateFrontLine;
        [] call co_main_fnc_checkTownCapture;
        sleep CO_rus_waveCooldown;
    };
    diag_log "[CO] Russian advance loop exited (front reached west coast or stopped).";
};