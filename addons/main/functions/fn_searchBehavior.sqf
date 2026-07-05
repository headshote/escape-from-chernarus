// ============================================================
// fn_searchBehavior.sqf — search-after-lost (server-side)
//
// When a chase loses line-of-sight, the pursuers no longer shrug
// and reboard. They convert to a timed SEARCH around the last
// known position: an expanding ring of sweep points mixed with
// nearby building doors and bushes (the places a player actually
// hides). Being re-spotted resumes the chase at full alert.
//
// BLOCKING: run this from inside a scheduled thread (the pursuit
// controller). It returns the target object if re-spotted, or
// objNull if the search timed out.
//
// Re-spot rule is deliberately NOT knowsAbout-based — knowsAbout
// stays high for minutes after the chase, which would make hiding
// impossible. A searcher re-spots only on real geometry: within
// 25 m AND a positive checkVisibility ray, or within 8 m flat
// (you cannot crouch next to a man searching for you).
//
// While searching, units are kept claimed under the caller's
// token (fn_claimUnit refresh) so no other loop steals them.
//
// If the alert net receives a FRESHER position for this suspect
// mid-search (someone else saw him), the search recenters there.
//
// params: [_units, _lkp, _duration, _target, _token, _priority]
// returns: OBJECT — _target if re-spotted, objNull otherwise
// ============================================================
params [
    ["_units", []],
    ["_lkp", [0,0,0]],
    ["_duration", 120],
    ["_target", objNull],
    ["_token", "search"],
    ["_priority", 50]
];

if (isNull _target || _units isEqualTo []) exitWith { objNull };

// ---- Build sweep points around a center --------------------------
private _buildPoints = {
    params ["_center"];
    private _pts = [];

    // Building entrances near the LKP — where players actually hide.
    private _houses = _center nearObjects ["House", 45];
    {
        private _bps = _x buildingPos -1;
        if !(_bps isEqualTo []) then {
            _pts pushBack (_bps select 0);
            if (count _bps > 2) then { _pts pushBack (_bps select (count _bps - 1)) };
        };
        if (count _pts > 8) exitWith {};
    } forEach _houses;

    // Bush/hide cover positions.
    private _covers = nearestTerrainObjects [_center, ["BUSH", "HIDE"], 45, false];
    {
        _pts pushBack (getPosATL _x);
        if (_forEachIndex >= 3) exitWith {};
    } forEach _covers;

    // Expanding ring fallback so open ground still gets swept.
    for "_i" from 0 to 5 do {
        _pts pushBack (_center getPos [12 + random 40, _i * 60 + random 40]);
    };

    _pts call BIS_fnc_arrayShuffle
};

private _points = [_lkp] call _buildPoints;
private _found = objNull;
private _endAt = time + _duration;
private _searchStartedAt = time;

// Tell the hunted player the state flipped — tension needs feedback.
if (isPlayer _target) then {
    ["You've broken contact — stay out of sight, they are searching."] remoteExecCall ["systemChat", _target];
};

// Assign initial points round-robin.
private _assign = {
    params ["_u", "_points"];
    if (_points isEqualTo []) exitWith {};
    private _idx = _u getVariable ["CO_searchPtIdx", floor random (count _points)];
    _idx = (_idx + 1) mod (count _points);
    _u setVariable ["CO_searchPtIdx", _idx, false];
    _u doMove (_points select _idx);
    _u setVariable ["CO_searchMoveAt", time, false];
};

{
    if (alive _x && vehicle _x == _x) then {
        _x setBehaviour "AWARE";
        _x setCombatMode "YELLOW";
        _x setUnitPos "UP";
        [_x, _points] call _assign;
    };
} forEach _units;

while { time < _endAt && isNull _found } do {
    sleep 2;

    if (isNull _target || !alive _target) exitWith {};
    if (captive _target || (_target getVariable ["CO_knockedOut", false])) exitWith {};

    private _live = _units select { alive _x && vehicle _x == _x };
    if (_live isEqualTo []) exitWith {};

    {
        private _u = _x;

        // Keep the claim fresh so nothing steals searchers.
        [_u, _token, _priority, 30] call co_main_fnc_claimUnit;

        // Re-spot check: hard geometry only.
        private _d = _u distance _target;
        if (_d < 8) exitWith { _found = _target };
        if (_d < 25 && vehicle _target == _target) then {
            private _vis = ([vehicle _u, "VIEW"] checkVisibility [eyePos _u, eyePos _target]);
            if (_vis > 0.2) then { _found = _target };
        };

        // Next sweep point when arrived or lingering.
        private _movedAt = _u getVariable ["CO_searchMoveAt", 0];
        if ((_u distance2D (expectedDestination _u select 0)) < 4 || (time - _movedAt) > 18) then {
            [_u, _points] call _assign;
        };
    } forEach _live;

    // Fresher LKP from the alert net? Recenter the search there.
    if (isNull _found) then {
        private _fresh = [(_points param [0, _lkp]), 600, 60, _target] call co_main_fnc_alertQuery;
        if !(_fresh isEqualTo []) then {
            private _e = _fresh select 0;
            private _newPos = _e param [1, _lkp];
            private _ts = _e param [2, 0];
            if (_ts > _searchStartedAt && (_newPos distance2D _lkp) > 50) then {
                _lkp = _newPos;
                _searchStartedAt = _ts;
                _points = [_lkp] call _buildPoints;
                { [_x, _points] call _assign } forEach _live;
            };
        };
    };
};

// Clean up per-unit search state.
{
    _x setVariable ["CO_searchPtIdx", nil, false];
    _x setVariable ["CO_searchMoveAt", nil, false];
} forEach _units;

if (isNull _found && isPlayer _target && alive _target) then {
    ["The search has moved on."] remoteExecCall ["systemChat", _target];
};

_found
