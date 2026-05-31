// ============================================================
// fn_initHC.sqf
// Headless Client initialisation — offloads heavy NPC loops.
// HC takes control of groups by moving them to HC's machine.
// ============================================================

// Wait for server to finish building the world (sleep so the gate doesn't
// busy-spin the scheduler every frame during load).
waitUntil { sleep 0.5; !isNil "CO_roadGraph" };
sleep 5;

// Ask the server to hand newly spawned AI groups to this HC.
[clientOwner] remoteExecCall ["co_main_fnc_registerHC", 2];
