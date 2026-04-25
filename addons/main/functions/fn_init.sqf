// fn_init.sqf — shared pre-init (called from initServer/initClient/initHC)
// Globals are loaded from CO_adminDefaults.sqf on server.
// Clients wait for broadcast via publicVariable in initServer.
// This file is intentionally minimal \u2014 real init is split by machine role.
diag_log "[CO] fn_init executed";