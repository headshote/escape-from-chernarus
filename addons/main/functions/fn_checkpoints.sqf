// fn_checkpoints.sqf
// DEPRECATED \u2014 checkpoint placement is now handled entirely by
// fn_placeCheckpoints.sqf which uses the road graph built by fn_buildRoadGraph.
// This file is kept as a stub to avoid breaking old references.
diag_log "[CO] fn_checkpoints called but redirecting to fn_placeCheckpoints.";

if (isServer) then {
    if (isNil "CO_roadGraph" || { CO_roadGraph isEqualTo [] }) then {
        [] call co_main_fnc_buildRoadGraph;
    };
    [] call co_main_fnc_placeCheckpoints;
};
