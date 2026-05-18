// fn_enduranceBar.sqf — runs on client via CBA pfh
//
// Previous implementation called `hintSilent parseText` every 6 frames
// (~10 Hz). hintSilent forces a full UI redraw and parseText allocates
// a structured-text object on every call; running that at 10 Hz from
// mission start created a steady stream of client-side UI work that
// compounded over a long session into hard FPS drops (the bug the
// player reported after completing boot camp). The redraw rate is now
// throttled to the lowest possible cadence: hintSilent is only called
// when the *displayed* state (bar count or exhausted flag) actually
// changes. With endurance recovering at 0.12/tick the bar count rarely
// changes more than ~1 time/sec, and is fully idle when the player
// isn't moving.
//
// We also moved the per-frame work itself to a 4 Hz tick instead of
// every-frame (`0.25` interval). Endurance is sampled in 0.25 s
// quanta which is plenty for HUD purposes.
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

CO_enduranceLastBars = -1;
CO_enduranceLastExhausted = false;
CO_enduranceAimCoefSet = -1;

// 0.25 s tick instead of every-frame. The sprint penalty/recovery is
// scaled by 5 (0.35*5 = 1.75 drop / 0.12*5 = 0.6 recover) to preserve
// the original per-second drain/recovery rates.
[{
    params ["_args", "_handle"];
    private _player = player;
    if (isNull _player || !alive _player) exitWith {};

    private _anim = animationState _player;
    private _isSprinting = _anim in _sprintAnims;

    if (_isSprinting) then {
        CO_playerEndurance = ((CO_playerEndurance - 1.75) max 0);
    } else {
        CO_playerEndurance = ((CO_playerEndurance + 0.6) min BAR_MAX);
    };

    // setCustomAimCoef only when threshold crosses (state change)
    private _exhausted = CO_playerEndurance <= 0;
    private _wantCoef = if (_exhausted) then { 4 } else {
        if (CO_playerEndurance > 20) then { 1 } else { CO_enduranceAimCoefSet }
    };
    if (_wantCoef > 0 && _wantCoef != CO_enduranceAimCoefSet) then {
        _player setCustomAimCoef _wantCoef;
        CO_enduranceAimCoefSet = _wantCoef;
        _player setVariable ["CO_exhausted", _exhausted, false];
    };

    // Compute displayed bar count and only refresh the UI on change.
    private _pct = CO_playerEndurance / BAR_MAX;
    private _bars = floor (_pct * 20);
    if (_bars != CO_enduranceLastBars || _exhausted != CO_enduranceLastExhausted) then {
        CO_enduranceLastBars = _bars;
        CO_enduranceLastExhausted = _exhausted;
        private _barStr = "[" + ("|" * _bars) + (" " * (20 - _bars)) + "]";
        private _color = if (_pct < 0.25) then {"#FF4444"} else {if (_pct < 0.6) then {"#FFAA00"} else {"#44FF44"}};
        private _label = if (_exhausted) then {
            "<t color='#FF2222'>EXHAUSTED</t>"
        } else {
            format ["<t color='%2'>Stamina %1</t>", _barStr, _color]
        };
        hintSilent parseText _label;
    };

}, 0.25, []] call CBA_fnc_addPerFrameHandler;