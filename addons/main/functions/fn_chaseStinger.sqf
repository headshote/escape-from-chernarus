// ============================================================
// fn_chaseStinger.sqf
// Client music/audio cue for threat state changes.
// params: [_state, _target]
// ============================================================
params [
    ["_state", "PURSUIT"],
    ["_target", objNull]
];

if (!hasInterface) exitWith {
    if (!isNull _target && isPlayer _target) then {
        [_state, _target] remoteExecCall ["co_main_fnc_chaseStinger", _target];
    };
};

if (!isNull _target && _target != player) exitWith {};

private _last = missionNamespace getVariable ["CO_lastStingerAt", 0];
if ((time - _last) < 10) exitWith {};
missionNamespace setVariable ["CO_lastStingerAt", time, false];

switch (_state) do {
    case "PURSUIT": { playMusic "LeadTrack01_F"; };
    case "SEARCH":  { playMusic "AmbientTrack01_F"; };
    case "WEAPONS": { playMusic "LeadTrack03_F"; };
    case "LETHAL":  { playMusic "LeadTrack04_F"; };
    case "CLEAR":   { playMusic ""; };
    default {};
};
