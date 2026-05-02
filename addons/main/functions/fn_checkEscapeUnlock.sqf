// fn_checkEscapeUnlock.sqf — called when player crosses border
params ["_player"];

if (!isPlayer _player) exitWith {};
if (_player getVariable ["CO_escapeUnlocked", false]) exitWith {};

_player setVariable ["CO_escapeUnlocked", true, true];

// Persist unlock on the escaping player's machine.
[] remoteExecCall ["co_main_fnc_unlockResistanceRespawn", _player];