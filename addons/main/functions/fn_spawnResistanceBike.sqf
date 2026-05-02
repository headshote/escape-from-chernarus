// ============================================================
// fn_spawnResistanceBike.sqf
// Server-side convenience transport for resistance-side or resistance-spawn
// players. Falls back to a quadbike if no bicycle class exists.
// ============================================================
params ["_player"];

if (!isServer) exitWith {
    [_player] remoteExecCall ["co_main_fnc_spawnResistanceBike", 2];
};

if (isNull _player || !isPlayer _player || !alive _player) exitWith {};

private _existingVehicle = _player getVariable ["CO_supportBike", objNull];
if (!isNull _existingVehicle && { alive _existingVehicle }) then {
    deleteVehicle _existingVehicle;
};

private _vehicleClass = "C_Quadbike_01_F";
{
    if (isClass (configFile >> "CfgVehicles" >> _x)) exitWith {
        _vehicleClass = _x;
    };
} forEach ["C_Bicycle_01_F", "C_Bike_01_F", "C_Quadbike_01_F"];

private _spawnPos = (getPosATL _player) getPos [4, getDir _player + 45];
private _nearRoads = _spawnPos nearRoads 12;
if !(_nearRoads isEqualTo []) then {
    _spawnPos = getPosATL (_nearRoads select 0);
};

private _bike = _vehicleClass createVehicle _spawnPos;
_bike setDir (getDir _player);
_bike setPosATL _spawnPos;
_bike setVariable ["CO_spawnedForUID", getPlayerUID _player, false];
_player setVariable ["CO_supportBike", _bike, true];