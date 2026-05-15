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

    // Hard ceiling: this target can NEVER cross 0.85 cumulative damage
    // from TCK fire. We compute headroom and clamp the per-hit return
    // value below it so chained shots don't accidentally kill.
    private _existing = damage _target;
    private _ceiling  = 0.85;
    private _headroom = (_ceiling - _existing) max 0;

    // Already knocked out — keep them pinned but alive
    if (_target getVariable ["CO_knockedOut", false]) exitWith {
        (_damage min _headroom)
    };

    // Cap per-hit damage to a non-lethal value (and never above headroom)
    private _capped = (_damage min 0.35) min _headroom;

    // Aggregate stun separately; once 3+ hits have landed, drop them
    // and dispatch transport
    private _stun = _target getVariable ["CO_stunDamage", 0];
    private _stunHits = _target getVariable ["CO_stunHits", 0];

    _stun = _stun + ((_damage min 0.55) * 0.4);
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

    // For "HitHead" the engine multiplies; clamp head damage hard.
    if (_hitPoint == "HitHead" || _selection == "head") exitWith {
        ((_capped min 0.25) min _headroom)
    };

    _capped
}];

// Belt-and-braces: even with HandleDamage clamping each shot, accumulated
// damage from rapid bursts can creep up on the engine. A Hit handler runs
// AFTER damage is applied and forcibly caps total damage at 0.85 when the
// source was TCK, then triggers the dispatch flow if not already running.
_unit addEventHandler ["Hit", {
    params ["_target", "_source", "_damage", "_instigator"];
    if (isNull _target || !alive _target) exitWith {};
    private _src = if (!isNull _instigator) then { _instigator } else { _source };
    if (isNull _src || _src == _target) exitWith {};
    private _fac = group _src getVariable ["CO_faction", ""];
    if !(_fac in ["CRN_ENF","POLICE"]) exitWith {};

    if ((damage _target) > 0.85) then {
        _target setDamage 0.85;
    };

    if (!(_target getVariable ["CO_knockedOut", false]) &&
        !(_target getVariable ["CO_captureInProgress", false])) then {
        private _stunHits = (_target getVariable ["CO_stunHits", 0]) + 1;
        _target setVariable ["CO_stunHits", _stunHits, true];
        if (_stunHits >= 2) then {
            _target setVariable ["CO_stunHits", 0, true];
            if (isServer) then {
                [_src, _target] spawn co_main_fnc_dispatchCaptureTransport;
            } else {
                [_src, _target] remoteExec ["co_main_fnc_dispatchCaptureTransport", 2];
            };
        };
    };
}];
