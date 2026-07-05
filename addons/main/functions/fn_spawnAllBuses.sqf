// ============================================================
// fn_spawnAllBuses.sqf
// Distributes bus count from admin panel across routes
// weighted by priority. Guarantees minimums for large towns.
// ============================================================

params [
    ["_totalBuses",     CO_bus_totalCruising],
    ["_hostilesPerBus", CO_bus_hostilesPerBus]
];

// No routes → nothing to spawn. Guards against selectRandom [] later, which
// would return nil and crash the weighted-allocation pass.
if (isNil "CO_busRoutes" || { CO_busRoutes isEqualTo [] }) exitWith {
    diag_log "[CO] spawnAllBuses: CO_busRoutes empty — no buses spawned.";
};

// Sort routes by priority descending
private _sorted = [CO_busRoutes, [], { _x select 1 }, "DESCEND"] call BIS_fnc_sortBy;
private _guaranteedPerLargeTown = missionNamespace getVariable ["CO_bus_townGuaranteed", 3];
private _allocations = _sorted apply { [_x, 0] };

// First pass: guarantee at least CO_bus_townGuaranteed on priority-4 routes (intra-town large)
private _busesAllocated = 0;
{
    if ((_x select 1) == 4 && _busesAllocated < _totalBuses) then {
        for "_g" from 1 to _guaranteedPerLargeTown do {
            if (_busesAllocated >= _totalBuses) then { break };
            private _entry = _allocations select _forEachIndex;
            _entry set [1, (_entry select 1) + 1];
            _busesAllocated = _busesAllocated + 1;
        };
    };
} forEach _sorted;

// Second pass: fill remaining quota weighted by priority
private _remaining = (_totalBuses - _busesAllocated) max 0;
private _weightedRouteIndexes = [];
{
    private _weight = (_x select 1) max 1;
    for "_i" from 1 to _weight do {
        _weightedRouteIndexes pushBack _forEachIndex;
    };
} forEach _sorted;

for "_i" from 1 to _remaining do {
    private _routeIndex = selectRandom _weightedRouteIndexes;
    private _entry = _allocations select _routeIndex;
    _entry set [1, (_entry select 1) + 1];
};

{
    private _routeEntry = _x select 0;
    private _route = _routeEntry select 0;
    private _priority = _routeEntry param [1, 1];
    private _count = _x select 1;
    private _n = count _route;
    for "_spawnIndex" from 1 to _count do {
        // Rotate the route per bus so trucks sharing one route start at
        // DIFFERENT waypoints and cruise staggered segments — the old
        // behavior seeded every bus at waypoint 0, so the 3 guaranteed
        // town trucks spawned nose-to-tail on the same street and
        // gridlocked each other into permanent idling.
        private _wps = _route;
        if (_count > 1 && _n > 1) then {
            private _rot = ((_spawnIndex - 1) * ((_n / _count) max 1)) mod _n;
            _rot = floor _rot;
            if (_rot > 0) then {
                _wps = (_route select [_rot, _n - _rot]) + (_route select [0, _rot]);
            };
        };
        // The FIRST bus on each intra-town (priority 4) route becomes the
        // town garrison: it parks at spawn and dumps its squad as a
        // permanent foot-harassment patrol (driver stays at the wheel).
        private _garrison = (_priority == 4 && _spawnIndex == 1);
        [_wps, _hostilesPerBus, _garrison] call co_main_fnc_spawnBusOnRoute;
        // Yield between spawns so the engine registers each vehicle
        // before the next findEmptyPosition runs. Without this, multiple
        // trucks on the same route pick overlapping road candidates and
        // detonate against each other on the same frame.
        sleep 0.4;
    };
} forEach _allocations;

diag_log format ["[CO] Spawned %1 hostile buses across %2 routes.", _totalBuses, count _sorted];