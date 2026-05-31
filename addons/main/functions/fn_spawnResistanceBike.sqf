// ============================================================
// fn_spawnResistanceBike.sqf
// Server-side support vehicle spawn for resistance-side or civilian-start
// players. Prefers a CUP Apache-style attack helicopter when available,
// otherwise falls back to a vanilla armed attack helicopter.
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

private _vehicleClass = "B_Heli_Attack_01_dynamicLoadout_F";
{
    if (isClass (configFile >> "CfgVehicles" >> _x)) exitWith {
        _vehicleClass = _x;
    };
} forEach [
    "CUP_B_AH64D_DL_USA",
    "CUP_B_AH64D_USA",
    "CUP_B_AH1Z_Dynamic_USMC",
    "B_Heli_Attack_01_dynamicLoadout_F",
    "B_Heli_Attack_01_F"
];

private _spawnOrigin = if (_anchorPos isEqualTo []) then { getPosATL _player } else { +_anchorPos };
_spawnOrigin set [2, 0];

private _spawnPos = +_spawnOrigin;
private _preferredOffsets = [
    [22,   0, 0],
    [0,   22, 0],
    [-22,  0, 0],
    [0,  -22, 0],
    [30,  12, 0],
    [30, -12, 0],
    [-30, 12, 0],
    [-30,-12, 0]
];

{
    private _candidatePos = _spawnOrigin vectorAdd _x;
    private _emptyPos = _candidatePos findEmptyPosition [0, 35, _vehicleClass];
    if !(_emptyPos isEqualTo []) exitWith {
        _spawnPos = _emptyPos;
    };
} forEach _preferredOffsets;

private _vehicle = _vehicleClass createVehicle _spawnPos;
_vehicle setDir (getDir _player);
_vehicle setPosATL _spawnPos;
_vehicle setVectorUp (surfaceNormal _spawnPos);
_vehicle setFuel 1;
_vehicle setDamage 0;
_vehicle setVehicleAmmo 1;
_vehicle lock 0;
_vehicle engineOn false;
_vehicle setVariable ["CO_spawnedForUID", getPlayerUID _player, false];
_player setVariable ["CO_supportBike", _vehicle, true];