// ============================================================
// fn_initHC.sqf
// Headless Client initialisation — offloads heavy NPC loops.
// HC takes control of groups by moving them to HC's machine.
// ============================================================

// Wait for server to finish building the world
waitUntil { !isNil "CO_roadGraph" };
sleep 5;

// Ask the server to hand newly spawned AI groups to this HC.
[clientOwner] remoteExecCall ["co_main_fnc_registerHC", 2];
