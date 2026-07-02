// ============================================================
// fn_chaseStinger.sqf — client feedback for threat-state changes
// (repair R2-b)
//
// Called by fn_setEscalationState ONLY when the state actually
// transitions, so every toast corresponds to something the player
// caused or needs to react to. Two channels:
//   - a short toast on a dedicated title layer (auto-fades ~4 s);
//   - a music stinger, throttled so rapid transitions don't
//     restart the track every second.
//
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

// ---- Toast (always, per transition) --------------------------------
private _toast = switch (_state) do {
    case "SUSPICIOUS": { "You are being watched." };
    case "PURSUIT":    { "PURSUIT — run or hide!" };
    case "SEARCH":     { "You've broken contact — stay out of sight." };
    case "WEAPONS":    { "They are authorized to open fire." };
    case "LETHAL":     { "Shoot-to-kill order issued." };
    case "CLEAR":      { "The heat has died down." };
    default            { "" };
};
if (_toast != "") then {
    private _layer = "CO_ToastLayer" call BIS_fnc_rscLayer;
    _layer cutText [_toast, "PLAIN DOWN", 0.4];
    // Serial guard: an older fade thread must not hide a newer toast.
    private _serial = (missionNamespace getVariable ["CO_toastSerial", 0]) + 1;
    missionNamespace setVariable ["CO_toastSerial", _serial, false];
    [_layer, _serial] spawn {
        params ["_layer", "_serial"];
        sleep 4;
        if ((missionNamespace getVariable ["CO_toastSerial", 0]) == _serial) then {
            _layer cutFadeOut 1;
        };
    };
};

// ---- Music stinger (throttled) --------------------------------------
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
