// ============================================================
// fn_getEscalationState.sqf — READ-ONLY doctrine-state accessor
//
// Returns a suspect's current escalation state, treating an
// expired state as CLEAR *without writing anything*.
//
// Repair R2-a / audit R2-17: the old version decayed heat and
// broadcast state changes from whoever happened to call it —
// which in practice was only the local player's HUD loop, so NPC
// states never expired and heat never decayed on a dedicated
// server unless a client was staring at its own HUD. Expiry and
// heat decay are now owned by the server maintenance loop in
// fn_stateWatchdog; this accessor is safe to call from anywhere.
//
// params: [_target]
// returns: STRING state
// ============================================================
params [["_target", objNull]];
if (isNull _target) exitWith { "UNAWARE" };

private _state = _target getVariable ["CO_escalationState", "UNAWARE"];
private _until = _target getVariable ["CO_escalationUntil", 0];
if (!(_state in ["UNAWARE", "CLEAR"]) && time > _until) then {
    _state = "CLEAR";
};

_state
