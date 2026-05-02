// ============================================================
// fn_spawnResistanceBike.sqf
// Server-side convenience transport for resistance-side or civilian-start
// players. Falls back to a quadbike if no bicycle class exists.
// ============================================================
params ["_player", ["_anchorPos", []]];

if (!isServer) exitWith {
    [_player, _anchorPos] remoteExecCall ["co_main_fnc_spawnResistanceBike", 2];
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

private _spawnOrigin = if (_anchorPos isEqualTo []) then { getPosATL _player } else { +_anchorPos };
_spawnOrigin set [2, 0];

private _spawnPos = +_spawnOrigin;
private _preferredOffsets = [
    [3.5,  1.8, 0],
    [3.5, -1.8, 0],
    [-3.5,  1.8, 0],
    [-3.5, -1.8, 0],
    [0,    3.5, 0],
    [0,   -3.5, 0]
];

{
    private _candidatePos = _spawnOrigin vectorAdd _x;
    private _emptyPos = _candidatePos findEmptyPosition [0, 8, _vehicleClass];
    if !(_emptyPos isEqualTo []) exitWith {
        _spawnPos = _emptyPos;
    };
} forEach _preferredOffsets;

private _bike = _vehicleClass createVehicle _spawnPos;
_bike setDir (getDir _player);
_bike setPosATL _spawnPos;
_bike setVectorUp (surfaceNormal _spawnPos);
_bike setVariable ["CO_spawnedForUID", getPlayerUID _player, false];
_player setVariable ["CO_supportBike", _bike, true];