// ============================================================
// fn_heatHud.sqf — situational threat HUD (client)
//
// The display adapts to the player's arc instead of always
// showing police stars:
//
//   FREE CIVILIAN  : two tiles —
//     POLICE       : presence + WANTED stars + police posture chip.
//                    Stars = persistent legal standing; only the
//                    police care about it.
//     TCK/BORDER   : presence + occupation posture chip. TCK
//                    snatch-squads do NOT care about wanted — what
//                    matters is whether they are around and whether
//                    they are on you ("TARGETED").
//   DETAINED       : single status tile (detention / in transport),
//                    lockpick hint while in a cell. No threat tiles —
//                    they already have you.
//   TRAINING       : boot-camp tile with the current drill stage
//                    (CO_bootCampStage, broadcast by fn_bootCampQuest);
//                    if the camp guards go active on you (escape
//                    attempt), a GUARDS ALERTED / WEAPONS FREE line
//                    appears.
//   FRONTLINE      : minimal tag only — you are a soldier now,
//                    wanted levels are meaningless until you desert.
//   AWOL           : red deserter banner + BOTH threat tiles return
//                    (police and occupation hunt deserters).
//
// Escalation is split into two channels by CO_escalationSource:
// sources starting with "police" drive the police chip; everything
// else (checkpoint_, bus_, crime_, qa_) drives the occupation chip.
// Presence distances come from CO_threatNear, broadcast every 4 s
// by fn_threatInfoLoop on the server.
//
// Rendered on the persistent CO_ThreatHUD cutRsc layer (R2-a) —
// re-cut automatically if lost (respawn/load), redrawn only when
// the text actually changes.
// ============================================================
if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["CO_heatHudRunning", false]) exitWith {};
missionNamespace setVariable ["CO_heatHudRunning", true, false];

CO_heatHudLastText = "";

// state → [label, color]; "" when the state carries no chip.
CO_fnc_hudChip = {
    params ["_state"];
    switch (_state) do {
        case "LETHAL":     { ["SHOOT TO KILL", "#FF1010"] };
        case "WEAPONS":    { ["WEAPONS FREE", "#FF4040"] };
        case "PURSUIT":    { ["PURSUIT", "#FF7A2F"] };
        case "SEARCH":     { ["HUNTED — HIDE", "#66B7FF"] };
        case "SUSPICIOUS": { ["WATCHED", "#FFD34D"] };
        default            { ["", ""] };
    };
};

// distance → [presenceText, color]
CO_fnc_hudPresence = {
    params ["_dist"];
    switch (true) do {
        case (_dist <= 150):  { [format ["CLOSE — %1 m", _dist], "#FFB35C"] };
        case (_dist <= 450):  { ["in the area", "#C8D2D8"] };
        case (_dist <= 9000): { ["distant", "#7F98A8"] };
        default               { ["none nearby", "#7F98A8"] };
    };
};

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
                0.30
            ];
            _ctrl ctrlCommit 0;
        };
        CO_heatHudLastText = "";
    };
    if (isNull _disp) exitWith {};
    private _ctrl = _disp displayCtrl 9401;
    if (isNull _ctrl) exitWith {};

    // ---- Resolve the player's arc phase ------------------------------
    private _detain = player getVariable ["CO_detainPhase", ""];
    private _awol = player getVariable ["CO_isAWOL", false];
    private _cleared = player getVariable ["CO_isCleared", false];
    private _phase = switch (true) do {
        case (_awol):                              { "awol" };
        case (_detain in ["detention", "transport"]): { "detained" };
        case (_detain == "training" ||
              player getVariable ["CO_bootCampActive", false]): { "training" };
        case (_cleared && _detain == "deployed"):  { "front" };
        default                                     { "free" };
    };

    // ---- Shared inputs ------------------------------------------------
    private _wanted = player getVariable ["CO_wantedLevel", 0];
    private _heat = player getVariable ["CO_heatLevel", 0];
    private _state = [player] call co_main_fnc_getEscalationState;
    private _stateActive = !(_state in ["UNAWARE", "CLEAR"]);
    private _src = player getVariable ["CO_escalationSource", ""];
    private _srcIsPolice = (_src select [0, 6]) == "police";
    private _inspecting = player getVariable ["CO_policeInspecting", false];
    private _targeted = (player getVariable ["CO_captureInProgress", false]) && !captive player;
    (player getVariable ["CO_threatNear", [99999, 99999]]) params [
        ["_policeDist", 99999], ["_occDist", 99999]
    ];

    private _stamina = missionNamespace getVariable ["CO_enduranceHudText", ""];
    private _lines = [];
    if (_stamina != "") then {
        _lines pushBack format ["<t align='right' size='0.85'>%1</t>", _stamina];
    };

    // ---- Tile builders --------------------------------------------------
    private _pushPoliceTile = {
        ([_policeDist] call CO_fnc_hudPresence) params ["_presTxt", "_presCol"];
        _lines pushBack format [
            "<t align='right' size='0.75' color='%1'>POLICE — %2</t>", _presCol, _presTxt
        ];

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
        _lines pushBack format [
            "<t align='right' size='1.0' color='%1'>WANTED [%2]</t>", _starColor, _starText
        ];

        private _chip = ["", ""];
        if (_inspecting) then {
            _chip = ["ID CHECK — STAND STILL", "#FFD34D"];
        } else {
            if (_stateActive && _srcIsPolice) then {
                _chip = [_state] call CO_fnc_hudChip;
            } else {
                if (_heat > 25) then { _chip = ["COOLING", "#9FB6C8"] };
            };
        };
        if ((_chip select 0) != "") then {
            _lines pushBack format [
                "<t align='right' size='0.95' color='%1'>%2</t>", _chip select 1, _chip select 0
            ];
        };
    };

    private _pushOccupationTile = {
        ([_occDist] call CO_fnc_hudPresence) params ["_presTxt", "_presCol"];
        _lines pushBack format [
            "<t align='right' size='0.75' color='%1'>TCK / BORDER — %2</t>", _presCol, _presTxt
        ];

        private _chip = ["", ""];
        if (_targeted) then {
            _chip = ["TARGETED — RUN OR HIDE", "#FF5030"];
        } else {
            if (_stateActive && !_srcIsPolice) then {
                _chip = [_state] call CO_fnc_hudChip;
            };
        };
        if ((_chip select 0) != "") then {
            _lines pushBack format [
                "<t align='right' size='0.95' color='%1'>%2</t>", _chip select 1, _chip select 0
            ];
        };
    };

    // ---- Compose per phase ----------------------------------------------
    switch (_phase) do {
        case "detained": {
            private _label = if (_detain == "transport") then {
                "DETAINED — IN TRANSPORT"
            } else {
                "DETAINED"
            };
            _lines pushBack format ["<t align='right' size='1.05' color='#FF6A5A'>%1</t>", _label];
            if (_detain == "detention") then {
                _lines pushBack "<t align='right' size='0.75' color='#C8D2D8'>Cell locks can be picked — look for the action.</t>";
            };
        };
        case "training": {
            _lines pushBack "<t align='right' size='1.0' color='#E8C558'>CONSCRIPT TRAINING</t>";
            private _stage = player getVariable ["CO_bootCampStage", ""];
            if (_stage != "") then {
                _lines pushBack format ["<t align='right' size='0.8' color='#C8D2D8'>Drill %1</t>", _stage];
            };
            // Camp guards going active on you = your escape was noticed.
            if (_stateActive || _targeted) then {
                private _warn = if (_state in ["WEAPONS", "LETHAL"]) then {
                    ["GUARDS WEAPONS FREE", "#FF4040"]
                } else {
                    ["GUARDS ALERTED", "#FF9A3C"]
                };
                _lines pushBack format [
                    "<t align='right' size='0.95' color='%1'>%2</t>", _warn select 1, _warn select 0
                ];
            };
        };
        case "front": {
            _lines pushBack "<t align='right' size='0.85' color='#9AA7B0'>FRONTLINE — Krasnostav sector</t>";
        };
        case "awol": {
            _lines pushBack "<t align='right' size='1.05' color='#FF2020'>AWOL — DESERTER</t>";
            _lines pushBack "<t align='right' size='0.75' color='#FF9A3C'>Every force is authorized to hunt you.</t>";
            call _pushPoliceTile;
            call _pushOccupationTile;
        };
        default {  // free civilian
            call _pushPoliceTile;
            call _pushOccupationTile;
        };
    };

    private _line = _lines joinString "<br/>";
    if (_line != CO_heatHudLastText) then {
        CO_heatHudLastText = _line;
        _ctrl ctrlSetStructuredText parseText _line;
    };
}, 0.5, []] call CBA_fnc_addPerFrameHandler;
