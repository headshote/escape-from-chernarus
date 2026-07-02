// ============================================================
// fn_heatHud.sqf
// Client-side threat HUD. Combines wanted/heat/escalation with the
// stamina text prepared by fn_enduranceBar so hintSilent is not
// fighting two independent UI loops.
// ============================================================
if (!hasInterface) exitWith {};
if (missionNamespace getVariable ["CO_heatHudRunning", false]) exitWith {};
missionNamespace setVariable ["CO_heatHudRunning", true, false];

CO_heatHudLastText = "";

[{
    params ["_args", "_handle"];
    if (isNull player || !alive player) exitWith {};

    private _wanted = player getVariable ["CO_wantedLevel", 0];
    private _state = [player] call co_main_fnc_getEscalationState;
    private _heat = player getVariable ["CO_heatLevel", 0];

    private _stars = (floor ((_wanted max _heat) / 20)) max 0 min 5;
    private _starText = "";
    for "_i" from 1 to 5 do {
        _starText = _starText + (if (_i <= _stars) then { "*" } else { "-" });
    };
    private _stateColor = switch (_state) do {
        case "SUSPICIOUS": {"#FFD34D"};
        case "PURSUIT": {"#FF7A2F"};
        case "SEARCH": {"#66B7FF"};
        case "WEAPONS": {"#FF4040"};
        case "LETHAL": {"#FF1010"};
        default {"#CCCCCC"};
    };
    private _stamina = missionNamespace getVariable ["CO_enduranceHudText", ""];
    private _line = format [
        "<t size='0.9' color='%4'>Heat [%1] %2</t><br/><t size='0.8'>Wanted %3</t>",
        _starText,
        _state,
        round _wanted,
        _stateColor
    ];
    if (_stamina != "") then {
        _line = _stamina + "<br/>" + _line;
    };

    if (_line != CO_heatHudLastText) then {
        CO_heatHudLastText = _line;
        hintSilent parseText _line;
    };
}, 0.5, []] call CBA_fnc_addPerFrameHandler;
