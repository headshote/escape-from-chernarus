// ============================================================
// fn_alertQuery.sqf — alert network blackboard, read side
// (server-side)
//
// Returns fresh alert entries near a position, newest first.
// See fn_alertPublish for the entry format:
//   [suspect, lkpPos, timestamp, source, heat]
//
// params: [_pos, _radius, _maxAge (120), _suspect (objNull)]
//   _suspect: when non-null, only return the entry for that
//   specific suspect (used by search behaviour to pick up a
//   fresher LKP for the man it is already hunting).
// returns: ARRAY of entries
// ============================================================
params [
    ["_pos", [0,0,0]],
    ["_radius", 800],
    ["_maxAge", 120],
    ["_suspect", objNull]
];

if (!isServer) exitWith { [] };
if (isNil "CO_alertNet") exitWith { [] };

private _out = [];

if (!isNull _suspect) then {
    private _key = netId _suspect;
    if (_key == "") then { _key = str _suspect };
    private _e = CO_alertNet getOrDefault [_key, []];
    if (!(_e isEqualTo []) &&
        { (time - (_e select 2)) <= _maxAge } &&
        { ((_e select 1) distance2D _pos) <= _radius }) then {
        _out pushBack _e;
    };
} else {
    {
        private _t = _y param [0, objNull];
        private _lkp = _y param [1, [0,0,0]];
        private _ts = _y param [2, 0];
        if (!isNull _t && alive _t &&
            (time - _ts) <= _maxAge &&
            (_lkp distance2D _pos) <= _radius) then {
            _out pushBack _y;
        };
    } forEach CO_alertNet;
    _out = [_out, [], { -(_x select 2) }, "ASCEND"] call BIS_fnc_sortBy;
};

_out
