// ============================================================
// fn_getEscalationState.sqf
// Returns a suspect's current doctrine state, expiring stale states.
// params: [_target]
// ============================================================
params [["_target", objNull]];
if (isNull _target) exitWith { "UNAWARE" };

private _state = _target getVariable ["CO_escalationState", "UNAWARE"];
private _until = _target getVariable ["CO_escalationUntil", 0];
if (_state != "UNAWARE" && _state != "CLEAR" && time > _until) then {
    _state = "CLEAR";
    _target setVariable ["CO_escalationState", _state, true];
};

if (_state in ["UNAWARE", "CLEAR"]) then {
    private _lastDecayAt = _target getVariable ["CO_heatLastDecayAt", time];
    if ((time - _lastDecayAt) > 5) then {
        private _heat = _target getVariable ["CO_heatLevel", 0];
        private _decay = (missionNamespace getVariable ["CO_heat_decayPerMinute", 5]) * ((time - _lastDecayAt) / 60);
        _target setVariable ["CO_heatLevel", (_heat - _decay) max 0, true];
        _target setVariable ["CO_heatLastDecayAt", time, false];
    };
};
_state
