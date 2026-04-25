// fn_enduranceBar.sqf — runs on client each frame via CBA pfh
#define BAR_MAX 100
CO_playerEndurance = BAR_MAX;

// CBA per-frame handler
[{
    params ["_args", "_handle"];
    private _player = ACE_player; // or just "player"

    if (isNull _player || !alive _player) exitWith {};

    private _isSprinting = (animationState _player) in ["AmovPercMsprSlowWrflDf","AmovPercMsprSlowWrflDfl","AmovPercMevaSdirDf"]; // detect sprint anims

    if (_isSprinting) then {
        CO_playerEndurance = ((CO_playerEndurance - 0.4) max 0);
        if (CO_playerEndurance <= 0) then {
            _player setVariable ["CO_exhausted", true, false];
            [_player] remoteExec ["setUnconscious", _player]; // stagger effect
        };
    } else {
        CO_playerEndurance = ((CO_playerEndurance + 0.15) min BAR_MAX);
        _player setVariable ["CO_exhausted", false, false];
    };

    // Draw HUD bar
    private _pct = CO_playerEndurance / BAR_MAX;
    private _color = [1 - _pct, _pct, 0, 0.85];
    drawIcon3D ["", _color, (_player modelToWorldVisual [0,-0.5,1.8]), 0,0,0,"",0]; // placeholder
    // Better: use a proper dialog/RscTitles overlay
}, 0, []] call CBA_fnc_addPerFrameHandler;