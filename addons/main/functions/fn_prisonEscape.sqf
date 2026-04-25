// ============================================================
// fn_prisonEscape.sqf
// Called after successful lockpick — marks player as not captive,
// removes from detention group, notifies server.
// params: [_player]
// ============================================================
params ["_player"];

_player setCaptive false;
_player setVariable ["CO_detainPhase", "escaped", true];

// Remove from any group and give them a solo group
[_player] joinGroup createGroup (side group _player);

// Reduce wanted level slightly (they're out but still hunted)
private _current = _player getVariable ["CO_wantedLevel", 50];
_player setVariable ["CO_wantedLevel", (_current - 20) max 20, true];

// Client notification
[_player] remoteExecCall ["co_main_fnc_showEscapeUnlockScreen", _player];
