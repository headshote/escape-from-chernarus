// ============================================================
// fn_installNonLethalDamage.sqf
// Installs a HandleDamage event handler on a unit (civilian NPC or
// player) so that incoming fire from hostile factions
// (CRN_ENF / POLICE) is converted into stun damage capped well
// below death. When the accumulated stun crosses a threshold the
// target is knocked out and a nearby hostile transport is
// dispatched to drag them to detention.
//
// Engine note: HandleDamage runs on the unit's locality. For
// AI civilians the server owns them; for players it's the player
// client. We therefore remoteExec the dispatch helper to the
// server when running on a player.
//
// Per gameplay spec point 1: TCK bullets should knock players
// and civilians unconscious rather than kill them outright.
// ============================================================
params [["_unit", objNull]];

if (isNull _unit) exitWith {};
if (!alive _unit) exitWith {};
if (_unit getVariable ["CO_nonLethalInstalled", false]) exitWith {};
_unit setVariable ["CO_nonLethalInstalled", true, true];

_unit addEventHandler ["HandleDamage", {
    params [
        "_target","_selection","_damage","_source","_projectile",
        "_hitIndex","_instigator","_hitPoint"
    ];

    if (isNull _target) exitWith { _damage };

    // Find the shooter we care about (driver of vehicle if vehicle-mounted)
    private _shooter = if (!isNull _instigator) then { _instigator } else { _source };
    if (isNull _shooter) exitWith { _damage };
    if (_shooter == _target) exitWith { _damage };

    private _shooterFac = group _shooter getVariable ["CO_faction", ""];
    private _isTCK = _shooterFac in ["CRN_ENF","POLICE"];

    // Russians (RUS_ADV) and CRN_FRONT keep lethal behavior so the
    // war on the east side stays a real combat zone.
    if (!_isTCK) exitWith { _damage };

    // Already knocked out — let downstream code keep them alive but
    // pinned. Cap incoming damage well below the lethal threshold so
    // a missed follow-up shot doesn't accidentally kill a downed body.
    if (_target getVariable ["CO_knockedOut", false]) exitWith {
        (_damage min 0.85)
    };

    // Cap per-hit damage to a non-lethal value
    private _capped = _damage min 0.55;

    // Aggregate stun separately; once 3+ hits have landed, drop them
    // and dispatch transport
    private _stun = _target getVariable ["CO_stunDamage", 0];
    private _stunHits = _target getVariable ["CO_stunHits", 0];

    _stun = _stun + (_capped * 0.4);
    _stunHits = _stunHits + 1;
    _target setVariable ["CO_stunDamage", _stun, true];
    _target setVariable ["CO_stunHits", _stunHits, true];

    if (_stunHits >= 3 || _stun >= 0.7) then {
        // Reset and trigger the dispatch helper server-side
        _target setVariable ["CO_stunDamage", 0, true];
        _target setVariable ["CO_stunHits", 0, true];

        if (isServer) then {
            [_shooter, _target] spawn co_main_fnc_dispatchCaptureTransport;
        } else {
            [_shooter, _target] remoteExec ["co_main_fnc_dispatchCaptureTransport", 2];
        };
    };

    // For "HitHead" the engine multiplies; clamp head damage low so
    // a stray accurate AI shot doesn't ragdoll-kill the target.
    if (_hitPoint == "HitHead" || _selection == "head") exitWith { (_capped min 0.4) };

    _capped
}];
