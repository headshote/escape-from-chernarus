// fn_transportToDetention.sqf
params ["_captive", "_capturingGrp"];

// Predefined detention centers
CO_detentionCenters = [
    [4800, 9600, 0],  // NW camp
    [12000, 5000, 0], // East facility
    [7400, 3100, 0]   // Central
];

// Find or create transport bus
private _bus = vehicle (leader _capturingGrp);
if (typeOf _bus == "Man") then {
    _bus = "C_Van_01_transport_F" createVehicle (getPosATL _captive);
};

// Load captive into bus
_captive moveInCargo _bus;
_captive setCaptive true;

// Optionally cruise for other players (30s) then drive to detention
[_bus, _captive] spawn {
    params ["_bus", "_captive"];

    // Cruise for co-op targets briefly
    sleep 30;

    // Pick nearest detention center
    private _dest = [CO_detentionCenters, [], { _x distance _bus }, "ASCEND"] call BIS_fnc_sortBy;
    _dest = _dest select 0;

    (driver _bus) doMove _dest;
    waitUntil { sleep 1; (driver _bus) distance _dest < 20 };

    // Unload at detention
    _captive leaveVehicle _bus;
    _captive setPos (_dest vectorAdd [5,0,0]);

    // Spawn detention guards
    [_dest] call co_main_fnc_spawnDetentionGuards;
    [_captive] call co_main_fnc_prisonSequence;
};