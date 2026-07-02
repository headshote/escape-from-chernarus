// ============================================================
// fn_heatHud.sqf — persistent client threat HUD (repair R2-a)
//
// One threat model, one display:
//   - WANTED stars   = persistent legal standing (crimes, captures).
//   - state chip     = the security forces' CURRENT posture toward
//                      you (CALM / COOLING / WATCHED / ID CHECK /
//                      PURSUIT / HUNTED / WEAPONS FREE / SHOOT TO
//                      KILL), colored by severity.
//   - stamina line   = fn_enduranceBar's markup (it writes
//                      CO_enduranceHudText; this is the only HUD
//                      that renders it).
//
// Rendered on a dedicated RscTitles layer (ui/threat_hud.hpp) via
// cutRsc — ALWAYS visible, unlike the old hintSilent version that
// faded out seconds after each change and fought other hints for
// the single hint channel (audit R2-11). The layer is re-cut
// automatically if the display is lost (respawn, save load).
//
// Heat itself is intentionally NOT shown as a number: it is the
// AI-side attention value. The player-facing translation is the
// chip ("COOLING" = residual attention while heat drains).
// ============================================================
if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["CO_heatHudRunning", false]) exitWith {};
missionNamespace setVariable ["CO_heatHudRunning", true, false];

CO_heatHudLastText = "";

[{
    params ["_args", "_handle"];
    if (isNull player || !alive player) exitWith {};

    // ---- Ensure the layer exists (respawn/load safe) ----------------
    private _disp = uiNamespace getVariable ["CO_ThreatHUD_display", displayNull];
    if (isNull _disp) then {
        ("CO_ThreatHUDLayer" call BIS_fnc_rscLayer) cutRsc ["CO_ThreatHUD", "PLAIN", 0, false];
        _disp = uiNamespace getVariable ["CO_ThreatHUD_display", displayNull];
        if (!isNull _disp) then {
            private _ctrl = _disp displayCtrl 9401;
            _ctrl ctrlSetPosition [
                safezoneX + safezoneW - 0.36,
                safezoneY + 0.30,
                0.34,
                0.24
            ];
            _ctrl ctrlCommit 0;
        };
        CO_heatHudLastText = "";   // force a redraw into the fresh control
    };
    if (isNull _disp) exitWith {};
    private _ctrl = _disp displayCtrl 9401;
    if (isNull _ctrl) exitWith {};

    // ---- Gather state -------------------------------------------------
    private _wanted = player getVariable ["CO_wantedLevel", 0];
    private _heat = player getVariable ["CO_heatLevel", 0];
    private _state = [player] call co_main_fnc_getEscalationState;
    private _inspecting = player getVariable ["CO_policeInspecting", false];

    // ---- Wanted stars (wanted ONLY — heat is the chip's job) ----------
    private _stars = (floor (_wanted / 20)) max 0 min 5;
    private _starText = "";
    for "_i" from 1 to 5 do {
        _starText = _starText + (if (_i <= _stars) then { "*" } else { "-" });
    };
    private _starColor = switch (true) do {
        case (_stars >= 4): { "#FF4040" };
        case (_stars >= 2): { "#FF9A3C" };
        case (_stars >= 1): { "#FFD34D" };
        default             { "#9AA7B0" };
    };

    // ---- State chip ----------------------------------------------------
    private _chip = switch (true) do {
        case (_inspecting):            { ["ID CHECK — STAND STILL", "#FFD34D"] };
        case (_state == "LETHAL"):     { ["SHOOT TO KILL", "#FF1010"] };
        case (_state == "WEAPONS"):    { ["WEAPONS FREE", "#FF4040"] };
        case (_state == "PURSUIT"):    { ["PURSUIT", "#FF7A2F"] };
        case (_state == "SEARCH"):     { ["HUNTED — HIDE", "#66B7FF"] };
        case (_state == "SUSPICIOUS"): { ["WATCHED", "#FFD34D"] };
        case (_heat > 25):             { ["COOLING", "#9FB6C8"] };
        default                        { ["CALM", "#8C8C8C"] };
    };
    _chip params ["_chipText", "_chipColor"];

    private _stamina = missionNamespace getVariable ["CO_enduranceHudText", ""];

    private _line = format [
        "<t align='right' size='0.85'>%1</t><br/><t align='right' size='1.0' color='%2'>WANTED [%3]</t><br/><t align='right' size='1.05' color='%4'>%5</t>",
        _stamina,
        _starColor,
        _starText,
        _chipColor,
        _chipText
    ];

    if (_line != CO_heatHudLastText) then {
        CO_heatHudLastText = _line;
        _ctrl ctrlSetStructuredText parseText _line;
    };
}, 0.5, []] call CBA_fnc_addPerFrameHandler;
