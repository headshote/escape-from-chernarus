// ============================================================
// fn_claimUnit.sqf — engagement arbiter (server-side)
//
// Root-cause fix for "distracted AI": five independent server
// loops (police, tck global aggression, guard aggro, bus escorts,
// border responses) used to issue doMove/setBehaviour to the SAME
// units on 2-5 s ticks, so a unit mid-chase was constantly yanked
// toward a different target. From now on a unit may be commanded
// by exactly one controller at a time.
//
// Contract: every controller loop MUST claim a unit before
// ordering it, and must skip units it failed to claim.
//
// Claim record (server-local, never broadcast):
//   unit var "CO_claim" = [token, priority, expiresAt]
//
// Claims expire automatically so a dead controller thread can
// never deadlock a unit. Re-claiming with the same token always
// succeeds and refreshes the TTL. A higher priority steals the
// unit; the losing controller notices on its next tick because
// its token no longer matches.
//
// Priority doctrine:
//   10 ambient patrol   30 proactive stop   40 global failsafe
//   50 chase NPC        70 chase player     90 retaliation/lethal
//
// params: [_unit, _token, _priority (50), _ttl (60)]
// returns: BOOL — true if the claim is now held by _token
// ============================================================
params [
    ["_unit", objNull],
    ["_token", ""],
    ["_priority", 50],
    ["_ttl", 60]
];

if (isNull _unit || _token == "") exitWith { false };

private _cur = _unit getVariable ["CO_claim", []];

private _free =
    (_cur isEqualTo []) ||
    { (_cur select 2) < time } ||
    { (_cur select 0) == _token } ||
    { _priority > (_cur select 1) };

if (!_free) exitWith { false };

if (_priority >= 50) then {
    if (isNil "CO_activeChaseTokens") then { CO_activeChaseTokens = createHashMap };

    {
        if ((CO_activeChaseTokens getOrDefault [_x, 0]) < time) then {
            CO_activeChaseTokens deleteAt _x;
        };
    } forEach (keys CO_activeChaseTokens);

    private _existingToken = !isNil { CO_activeChaseTokens get _token };
    private _maxChases = missionNamespace getVariable ["CO_maxSimultaneousChases", 6];
    if (!_existingToken && _priority < 75 && { (count (keys CO_activeChaseTokens)) >= _maxChases }) exitWith {
        false
    };

    CO_activeChaseTokens set [_token, time + _ttl];
};

_unit setVariable ["CO_claim", [_token, _priority, time + _ttl], false];
true
