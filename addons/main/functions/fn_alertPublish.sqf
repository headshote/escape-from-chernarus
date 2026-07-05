// ============================================================
// fn_alertPublish.sqf — alert network blackboard, write side
// (server-side)
//
// The security apparatus previously had no memory: every escape
// was a total reset. CO_alertNet gives every subsystem a shared
// last-known-position (LKP) board. Publishers: any detection or
// chase (police, checkpoints, buses, border). Consumers: search
// behaviour (Phase 0), converge/backup dispatch (Phase 1+).
//
// Entry: key = netId of suspect
//        value = [suspect, lkpPos, timestamp, source, heat]
//
// Heat only ever rises for a live entry (max-merge) so one calm
// sighting can't launder a hot fugitive. Entries expire by age at
// read time and are pruned lazily on write (at most once/60 s).
//
// params: [_target, _pos, _source, _heat (20)]
// ============================================================
params [
    ["_target", objNull],
    ["_pos", [0,0,0]],
    ["_source", "unknown"],
    ["_heat", 20]
];

if (!isServer) exitWith {};
if (isNull _target) exitWith {};

if (isNil "CO_alertNet") then { CO_alertNet = createHashMap };

private _key = netId _target;
if (_key == "") then { _key = str _target };

private _old = CO_alertNet getOrDefault [_key, []];
if !(_old isEqualTo []) then {
    _heat = _heat max (_old select 4);
};

CO_alertNet set [_key, [_target, _pos, time, _source, _heat]];

// Lazy prune: cheap, at most once a minute.
if (time > (missionNamespace getVariable ["CO_alertNetNextPrune", 0])) then {
    CO_alertNetNextPrune = time + 60;
    private _stale = [];
    {
        private _t = _y param [0, objNull];
        private _ts = _y param [2, 0];
        if (isNull _t || !alive _t || (time - _ts) > 300) then {
            _stale pushBack _x;
        };
    } forEach CO_alertNet;
    { CO_alertNet deleteAt _x } forEach _stale;
};
