// fn_buses.sqf
// Buses cruise between towns. Hostiles dismount and chase on sight.

CO_townWaypoints = [
    // [name, positions to cruise]
    ["Chernogorsk",    [[6400,2400,0],[6100,2700,0],[6700,2200,0]]],
    ["Elektrozavodsk", [[10200,2300,0],[10500,2600,0],[9900,2100,0]]],
    ["Berezino",       [[11600,7800,0],[11900,8100,0],[11300,7600,0]]],
    // inter-town highway points ...
];

// Guarantee minimum buses per major town
{ [_x, CO_bus_townGuaranteed] call co_main_fnc_spawnBusRoute; } forEach CO_townWaypoints;

// Spawn remaining as inter-town
for "_i" from 1 to (CO_bus_totalCruising - (count CO_townWaypoints * CO_bus_townGuaranteed)) do {
    private _wps = CO_townWaypoints call BIS_fnc_selectRandom;
    [_wps, 1] call co_main_fnc_spawnBusRoute;
};