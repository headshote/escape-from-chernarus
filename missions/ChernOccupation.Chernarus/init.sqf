// ============================================================
// ChernOccupation — Mission Init
// ============================================================
waitUntil { !isNull player }; // wait for player to exist

if (hasInterface) then {
    // This machine has a screen (player or HC with interface — rare)
    [] call co_main_fnc_initClient;
};

if (isServer) then {
    [] call co_main_fnc_initServer;
};

if (!hasInterface && !isServer) then {
    // Headless Client
    [] call co_main_fnc_initHC;
};