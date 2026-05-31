// ============================================================
// fn_awolMonitor.sqf
//
// Watches a cleared conscript (CO_isCleared=true). If they leave
// the Krasnostav front zone for longer than CO_awolGrace seconds,
// they're flagged AWOL — all factions (TCK, border, police,
// RUS_ADV) treat them as a lethal target via guardAggroLoop's
// AWOL-priority filter.
//
// Re-entering the front zone CANCELS the warning but, once
// flagged AWOL, the status sticks for the rest of the round —
// AWOL conscripts cannot un-AWOL by hiding.
//
// Params:
//   _player       - the cleared conscript
//   _frontCenter  - position [x,y,z] of Krasnostav (front anchor)
// ============================================================
params ["_player", "_frontCenter"];

if (!isServer) exitWith {};
if (isNull _player) exitWith {};

private _grace      = missionNamespace getVariable ["CO_awolGrace", 60];
private _radius     = missionNamespace getVariable ["CO_awolRadius", 1200];
private _outsideAt  = -1;
private _warned     = false;

while {
    alive _player &&
    (_player getVariable ["CO_isCleared", false]) &&
    !(_player getVariable ["CO_isAWOL", false])
} do {
    sleep 5;
    private _d = _player distance2D _frontCenter;
    if (_d > _radius) then {
        if (_outsideAt < 0) then { _outsideAt = time };
        if (!_warned && (time - _outsideAt) > 15) then {
            _warned = true;
            [["AWOL WARNING\nReturn to Krasnostav front in 60 seconds or you will be hunted."]]
                remoteExec ["hint", _player];
        };
        if ((time - _outsideAt) > _grace) then {
            _player setVariable ["CO_isAWOL", true, true];
            [["YOU ARE AWOL\nAll factions will engage on sight."]]
                remoteExec ["hint", _player];
            diag_log format [
                "[CO] AWOL: %1 left Krasnostav (%2 m) for %3 s — flagged hostile.",
                name _player, round _d, round (time - _outsideAt)
            ];
        };
    } else {
        // Reset grace if they come back in
        _outsideAt = -1;
        if (_warned) then {
            _warned = false;
            [["Welcome back to the front. AWOL warning cleared."]]
                remoteExec ["hint", _player];
        };
    };
};

// If they died or got flagged, we exit the loop. AWOL monitor stops.
