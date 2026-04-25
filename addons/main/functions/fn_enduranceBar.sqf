// fn_enduranceBar.sqf — runs on client via CBA pfh
// Uses setHUDMovementLevels + a text-based overlay for endurance feedback.
#define BAR_MAX 100
CO_playerEndurance = BAR_MAX;

// Sprint animation state names (Arma 3 vanilla)
private _sprintAnims = [
    "AmovPercMsprSlowWrflDf",
    "AmovPercMsprSlowWrflDfl",
    "AmovPercMsprSlowWrflDfr",
    "AmovPercMevaSdirDf",
    "AmovPercMevaSdirDl",
    "AmovPercMevaSdirDr"
];

// CBA per-frame handler
[{
    params ["_args", "_handle"];
    private _player = player;
    if (isNull _player || !alive _player) exitWith {};

    private _anim = animationState _player;
    private _isSprinting = _anim in _sprintAnims;

    if (_isSprinting) then {
        CO_playerEndurance = ((CO_playerEndurance - 0.35) max 0);
        if (CO_playerEndurance <= 0) then {
            // Force walk — remove sprint via setCustomAimCoef penalty
            _player setCustomAimCoef 4; // heavy aim sway = exhausted effect
            _player setVariable ["CO_exhausted", true, false];
        };
    } else {
        CO_playerEndurance = ((CO_playerEndurance + 0.12) min BAR_MAX);
        if (CO_playerEndurance > 20) then {
            _player setCustomAimCoef 1;
            _player setVariable ["CO_exhausted", false, false];
        };
    };

    // HUD: simple text overlay using titleText (low cost)
    private _pct = CO_playerEndurance / BAR_MAX;
    private _bars = floor (_pct * 20);
    private _barStr = "[" + ("|" * _bars) + (" " * (20 - _bars)) + "]";
    private _color = if (_pct < 0.25) then {"#FF4444"} else {if (_pct < 0.6) then {"#FFAA00"} else {"#44FF44"}};

    // Use a lightweight hint-like approach via ctrlSetText on a persistent RscTitle
    // (Full RscTitles would need HPP — use hintSilent as fallback for now)
    if (diag_frameNo % 6 == 0) then { // update every 6 frames ~10x/sec
        private _label = if (CO_playerEndurance <= 0) then {
            "<t color='#FF2222'>EXHAUSTED</t>"
        } else {
            format ["<t color='%2'>Stamina %1</t>", _barStr, _color]
        };
        hintSilent parseText _label;
    };

}, 0, []] call CBA_fnc_addPerFrameHandler;