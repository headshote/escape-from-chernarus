// fn_russianAdvance.sqf — master controller, runs on server

CO_rus_advanceFront = 14000;   // current X coord of front line (starts at east edge ~15000)
CO_rus_waveCooldown = 180;     // seconds between waves
CO_rus_unitsPerWave = 12;
CO_rus_advanceSpeed = 0.5;     // front moves this many meters per second of game time (abstract)

// Town capture checkpoints west to east
CO_rus_townObjectives = [
    ["Berezino",       11600, "marker_berezino"],
    ["Elektrozavodsk", 10200, "marker_elektro"],
    ["Chernogorsk",     6400, "marker_cherno"],
    ["Balota",          4500, "marker_balota"],
];

// Spawn loop
[] spawn {
    while { CO_rus_advanceFront > 3000 } do { // stop at west coast
        [] call co_main_fnc_spawnRussianWave;
        CO_rus_advanceFront = CO_rus_advanceFront - 120; // advance front abstraction
        [] call co_main_fnc_updateFrontLine;
        [] call co_main_fnc_checkTownCapture;
        sleep CO_rus_waveCooldown;
    };
};