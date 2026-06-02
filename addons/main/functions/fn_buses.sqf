// fn_buses.sqf
// Deprecated compatibility shim. Bus spawning is now handled by
// fn_buildBusRoutes + fn_spawnAllBuses.

diag_log "[CO] fn_buses called; redirecting to fn_spawnAllBuses.";

if (isServer) then {
    if (isNil "CO_busRoutes" || { CO_busRoutes isEqualTo [] }) then {
        [] call co_main_fnc_buildBusRoutes;
    };
    [] call co_main_fnc_spawnAllBuses;
};
