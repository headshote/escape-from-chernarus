// ============================================================
// ChernOccupation — Mission Init
// ============================================================
// Dedicated servers never own a player object, so keep server init separate.
if (isServer) then {
    execVM "CO_adminDefaults.sqf";
    waitUntil { !isNil "CO_checkpoint_hostilesPerPost" };
    [] call co_main_fnc_initServer;
};

if (hasInterface) then {
    waitUntil { !isNull player };
    [] call co_main_fnc_initClient;
};

if (!hasInterface && !isServer) then {
    [] call co_main_fnc_initHC;
};