// ============================================================
// fn_tckAcquireTarget.sqf — shared TCK hunt-target selector with
// commitment hysteresis (server-side).
//
// The problem this solves: TCK escorts and foot patrols used to
// re-pick "whichever valid civilian is nearest right now" on a short
// timer, so a pack would thrash between victims — abandoning a runner
// it was about to catch for a fractionally-closer bystander, and
// never committing to anyone. This selector LOCKS onto one victim
// (players always preferred over NPCs) and keeps chasing them,
// breaking the lock only when one of these holds:
//
//   * the current target is no longer huntable (dead / captive /
//     knocked out / already being captured by someone else / left
//     the scan range) — take the best fresh candidate; OR
//   * the current target is an NPC and a PLAYER is now in range —
//     players always win; OR
//   * ALL THREE at once: a candidate is closer than the current
//     target by more than CO_tck_switchMargin metres, the pursuit
//     has been fruitless for CO_tck_fruitlessTime seconds, and the
//     current target has been steadily opening the gap (we are
//     losing ground). This is the "stop chasing the one that's
//     getting away when there's an easier catch" rule.
//
// Per-hunter lock state (server-local, stored on the hunter unit):
//   CO_huntForId       netId the timers below belong to
//   CO_huntMinDist     closest we have gotten to the current target
//   CO_huntProgressAt  time we last made progress (shrank min dist)
//
// params:
//   _hunter      the pursuing unit
//   _current     its current target (objNull if none yet)
//   _radius      scan radius in metres
//   _extraCands  optional extra candidate array (e.g. alert-net hits)
// returns: the unit to pursue this tick (objNull if none in range)
// ============================================================
params [
    ["_hunter", objNull],
    ["_current", objNull],
    ["_radius", 80],
    ["_extraCands", []]
];

if (!isServer) exitWith { objNull };
if (isNull _hunter || !alive _hunter) exitWith { objNull };

private _switchMargin  = missionNamespace getVariable ["CO_tck_switchMargin", 18];
private _fruitlessTime = missionNamespace getVariable ["CO_tck_fruitlessTime", 20];
private _loseGroundGap = missionNamespace getVariable ["CO_tck_loseGroundGap", 8];

// ---- Shared "is this a legal victim right now?" test --------------
private _isHuntable = {
    params ["_t"];
    !isNull _t && alive _t && vehicle _t == _t &&
    !(captive _t) &&
    !(_t getVariable ["CO_knockedOut", false]) &&
    // captureInProgress is set by whoever is grabbing them (and stays
    // set through the kneel/transport); it is the map-wide "hands off"
    // flag that stops a pack piling onto an already-caught victim.
    !(_t getVariable ["CO_captureInProgress", false]) &&
    !(_t getVariable ["CO_isFemale", false]) &&
    (isPlayer _t || side _t == civilian) &&
    !(((group _t) getVariable ["CO_faction", ""]) in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) &&
    // cleared conscripts (deployed military) are off-limits unless AWOL
    (!(_t getVariable ["CO_isCleared", false]) || (_t getVariable ["CO_isAWOL", false])) &&
    // training recruits inside the airfield safe zone are off-limits
    (
        isNil "CO_airfieldCenter" ||
        (_t getVariable ["CO_isAWOL", false]) ||
        {
            private _afr = missionNamespace getVariable ["CO_airfieldRadius", 350];
            (getPosATL _t) distance2D CO_airfieldCenter >= (_afr + 20)
        }
    )
};

// ---- Build & rank candidates --------------------------------------
private _raw = (getPosATL _hunter) nearEntities [["Man"], _radius];
{ _raw pushBackUnique _x } forEach _extraCands;
private _cands = _raw select { _x != _hunter && { [_x] call _isHuntable } };

// Ranking score: players sort ahead of every NPC, then by distance,
// with hot / armed suspects nudged up. Only used to choose among
// fresh candidates — the switch DISTANCE test below uses raw metres.
private _scoreOf = {
    params ["_t"];
    private _score = _hunter distance2D _t;
    if (isPlayer _t) then { _score = _score - 100000 };
    _score = _score - (((_t getVariable ["CO_heatLevel", 0]) * 0.5) min 40);
    if (primaryWeapon _t != "" || handgunWeapon _t != "") then { _score = _score - 25 };
    _score
};

private _best = objNull;
if (count _cands > 0) then {
    _best = ([_cands, [], { [_x] call _scoreOf }, "ASCEND"] call BIS_fnc_sortBy) select 0;
};

// ---- Lock-state helpers -------------------------------------------
private _resetLock = {
    params ["_t"];
    _hunter setVariable ["CO_huntForId", netId _t, false];
    _hunter setVariable ["CO_huntMinDist", _hunter distance2D _t, false];
    _hunter setVariable ["CO_huntProgressAt", time, false];
};

// ---- Current target still valid? ----------------------------------
// A small range grace keeps us from dropping a victim who is one step
// past the scan edge mid-stride.
private _currentValid =
    !isNull _current &&
    { [_current] call _isHuntable } &&
    { (_hunter distance2D _current) <= (_radius + 25) };

if (!_currentValid) exitWith {
    if (isNull _best) then {
        _hunter setVariable ["CO_huntForId", "", false];
        objNull
    } else {
        [_best] call _resetLock;
        _best
    };
};

// Current is valid; if there is somehow no candidate, keep chasing it.
if (isNull _best) exitWith { _current };

// Make sure the lock timers belong to the current target.
if ((_hunter getVariable ["CO_huntForId", ""]) != (netId _current)) then {
    [_current] call _resetLock;
};

private _curDist  = _hunter distance2D _current;
private _bestDist = _hunter distance2D _best;

// Progress tracking: every time we get closer than we ever have to THIS
// target, record it and reset the fruitless clock.
private _minDist = _hunter getVariable ["CO_huntMinDist", _curDist];
if (_curDist < _minDist) then {
    _hunter setVariable ["CO_huntMinDist", _curDist, false];
    _hunter setVariable ["CO_huntProgressAt", time, false];
    _minDist = _curDist;
};

// Player preference is absolute: never keep an NPC while a player is in
// reach, and never abandon a player for an NPC.
if (!(isPlayer _current) && (isPlayer _best)) exitWith { [_best] call _resetLock; _best };
if ((isPlayer _current) && !(isPlayer _best)) exitWith { _current };

// Like-for-like (player→player or NPC→NPC): only switch when the catch
// is genuinely easier AND this pursuit has gone cold AND we are losing
// ground on the current one.
private _muchCloser    = (_curDist - _bestDist) > _switchMargin;
private _fruitless     = (time - (_hunter getVariable ["CO_huntProgressAt", time])) > _fruitlessTime;
private _losingGround  = _curDist > (_minDist + _loseGroundGap);

if (!(_best isEqualTo _current) && _muchCloser && _fruitless && _losingGround) exitWith {
    [_best] call _resetLock;
    _best
};

_current
