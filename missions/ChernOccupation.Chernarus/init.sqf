// ============================================================
// ChernOccupation — Mission Init
// ============================================================
waitUntil { !isNull player }; // wait for player to exist

// Server loads admin defaults first so globals exist before clients connect
if (isServer) then {
    execVM "CO_adminDefaults.sqf";
    sleep 0.3;
    [] call co_main_fnc_initServer;
};

if (hasInterface) then {
    // This machine has a screen (player or HC with interface — rare)
    [] call co_main_fnc_initClient;
};

if (!hasInterface && !isServer) then {
    // Headless Client
    [] call co_main_fnc_initHC;
};