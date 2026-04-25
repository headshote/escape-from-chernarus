// ============================================================
// fn_spawnAllBuses.sqf
// Distributes bus count from admin panel across routes
// weighted by priority. Guarantees minimums for large towns.
// ============================================================

params [
    ["_totalBuses",     CO_bus_totalCruising],
    ["_hostilesPerBus", CO_bus_hostilesPerBus]
];

// Sort routes by priority descending
private _sorted = [CO_busRoutes, [], { _x select 1 }, "DESCEND"] call BIS_fnc_sortBy;

// First pass: guarantee at least CO_bus_townGuaranteed on priority-4 routes (intra-town large)
private _busesAllocated = 0;
{
    if ((_x select 1) == 4 && _busesAllocated < _totalBuses) then {
        for "_g" from 1 to CO_bus_townGuaranteed do {
            [_x select 0, _hostilesPerBus] call co_main_fnc_spawnBusOnRoute;
            _busesAllocated = _busesAllocated + 1;
        };
    };
} forEach _sorted;

// Second pass: fill remaining quota weighted by priority
private _remaining = _totalBuses - _busesAllocated;
private _totalWeight = 0;
{ _totalWeight = _totalWeight + (_x select 1); } forEach _sorted;

{
    private _share = round ((_x select 1 / _totalWeight) * _remaining);
    for "_s" from 1 to _share do {
        [_x select 0, _hostilesPerBus] call co_main_fnc_spawnBusOnRoute;
    };
} forEach _sorted;