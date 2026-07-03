// ============================================================
// fn_awolMonitor.sqf
//
// Watches a deployed conscript. If they leave the accepted Krasnostav/front
// duty area for longer than CO_awolGrace seconds, they are marked AWOL and
// hostile systems may hunt them. Re-entering before the grace expires clears
// the warning timer.
// ============================================================
params ["_player", ["_frontCenter", [11200, 12300, 0]]];

if (!isServer) exitWith {};
if (isNull _player) exitWith {};

private _grace = missionNamespace getVariable ["CO_awolGrace", 60];
private _outsideAt = -1;
private _warned = false;

while {
    alive _player &&
    (_player getVariable ["CO_isCleared", false]) &&
    ((_player getVariable ["CO_detainPhase", ""]) == "deployed") &&
    !(_player getVariable ["CO_isAWOL", false])
} do {
    sleep 5;

    private _frontState = [_player, _frontCenter] call co_main_fnc_isFrontSafeZone;
    _frontState params ["_insideFront", "_zoneName", "_distance"];

    if (!_insideFront) then {
        if (_outsideAt < 0) then { _outsideAt = time };
        private _outsideFor = time - _outsideAt;

        if (!_warned && { _outsideFor > 15 }) then {
            _warned = true;
            private _remaining = (_grace - _outsideFor) max 0;
            [[format [
                "AWOL WARNING\nReturn to the Krasnostav front area in %1 seconds or you will be hunted.",
                round _remaining
            ]]] remoteExec ["hint", _player];
        };

        if (_outsideFor > _grace) then {
            _player setVariable ["CO_isAWOL", true, true];
            _player setVariable ["CO_detainPhase", "awol", true];
            _player setVariable ["CO_awolSource", "front_desertion", true];
            [["YOU ARE AWOL\nAll factions will engage on sight."]] remoteExec ["hint", _player];
            diag_log format [
                "[CO] AWOL: %1 left the Krasnostav front safe area (nearest zone %2 m) for %3 s.",
                name _player,
                round _distance,
                round _outsideFor
            ];
        };
    } else {
        _outsideAt = -1;
        if (_warned) then {
            _warned = false;
            [[format ["Welcome back to the front: %1. AWOL warning cleared.", _zoneName]] remoteExec ["hint", _player];
        };
    };
};
