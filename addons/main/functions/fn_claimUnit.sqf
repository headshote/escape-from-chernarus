// ============================================================
// fn_claimUnit.sqf — engagement arbiter (server-side)
//
// A unit may be commanded by exactly one controller at a time.
// Every controller loop MUST claim a unit before ordering it and
// must skip units it failed to claim.
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
// Chase cap: at most CO_maxSimultaneousChases *distinct tokens*
// with priority in [50, 70) may hold claims at once — this bounds
// NPC-vs-NPC chase load. Player chases (priority >= 70) and
// retaliation are NEVER capped.
//
// NOTE the fixed bug (R2-13): the old cap used `exitWith` inside a
// then{} block, which only exits that block — the claim was granted
// anyway. The cap decision is now made at function scope.
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

// ---- Chase-cap bookkeeping (NPC-target chases only) ---------------
private _capBlocked = false;
if (_priority >= 50) then {
    if (isNil "CO_activeChaseTokens") then { CO_activeChaseTokens = createHashMap };

    {
        if ((CO_activeChaseTokens getOrDefault [_x, 0]) < time) then {
            CO_activeChaseTokens deleteAt _x;
        };
    } forEach (keys CO_activeChaseTokens);

    private _existingToken = !isNil { CO_activeChaseTokens get _token };
    private _maxChases = missionNamespace getVariable ["CO_maxSimultaneousChases", 6];
    if (!_existingToken && _priority < 70 &&
        { (count (keys CO_activeChaseTokens)) >= _maxChases }) then {
        _capBlocked = true;
    } else {
        CO_activeChaseTokens set [_token, time + _ttl];
    };
};
if (_capBlocked) exitWith { false };

_unit setVariable ["CO_claim", [_token, _priority, time + _ttl], false];
true
