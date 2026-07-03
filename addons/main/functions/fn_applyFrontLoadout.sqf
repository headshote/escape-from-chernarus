// ============================================================
// fn_applyFrontLoadout.sqf
// Locality-safe conscript deployment kit.
// ============================================================
params [["_unit", objNull]];

if (isNull _unit) exitWith { false };

if (!local _unit) exitWith {
    [_unit] remoteExecCall ["co_main_fnc_applyFrontLoadout", _unit];
    false
};

private _hasWeapon = {
    params ["_class"];
    isClass (configFile >> "CfgWeapons" >> _class)
};
private _hasMagazine = {
    params ["_class"];
    isClass (configFile >> "CfgMagazines" >> _class)
};
private _firstExisting = {
    params ["_classes", "_cfg"];
    private _found = "";
    {
        if (_found == "" && { isClass (configFile >> _cfg >> _x) }) then {
            _found = _x;
        };
    } forEach _classes;
    _found
};

removeAllWeapons _unit;
removeAllItems _unit;
removeAllAssignedItems _unit;
removeUniform _unit;
removeVest _unit;
removeBackpack _unit;
removeHeadgear _unit;

private _uniform = [["U_O_CombatUniform_ocamo", "U_BG_Guerilla2_1", "U_BG_Guerilla1_1"], "CfgWeapons"] call _firstExisting;
private _vest = [["V_HarnessOGL_brn", "V_TacChestrig_grn_F", "V_TacVest_oli", "V_TacVest_blk"], "CfgWeapons"] call _firstExisting;
private _backpack = [["B_Carryall_oli", "B_Kitbag_rgr", "B_AssaultPack_rgr"], "CfgVehicles"] call _firstExisting;
private _helmet = [["H_HelmetO_ocamo", "H_HelmetB", "H_HelmetIA"], "CfgWeapons"] call _firstExisting;

if (_uniform != "") then { _unit forceAddUniform _uniform };
if (uniform _unit == "") then { _unit forceAddUniform "U_BG_Guerilla1_1" };
if (_vest != "") then { _unit addVest _vest };
if (vest _unit == "" && { ["V_TacVest_blk"] call _hasWeapon }) then { _unit addVest "V_TacVest_blk" };
if (_backpack != "") then { _unit addBackpack _backpack };
if (_helmet != "") then { _unit addHeadgear _helmet };

private _addMagazines = {
    params ["_mag", "_count"];
    private _added = 0;
    for "_i" from 1 to _count do {
        if (_unit canAdd _mag) then {
            _unit addMagazine _mag;
            _added = _added + 1;
        };
    };
    _added
};

private _primaryCandidates = [
    ["arifle_AKM_F", "30Rnd_762x39_Mag_F", 8],
    ["arifle_AK12_F", "30Rnd_762x39_AK12_Mag_F", 8],
    ["arifle_AK12U_F", "30Rnd_762x39_AK12_Mag_F", 8]
];
private _primaryWeapon = "";
private _primaryMag = "";
private _primaryMagCount = 0;
{
    _x params ["_weapon", "_mag", "_count"];
    if (_primaryWeapon == "" && { [_weapon] call _hasWeapon && [_mag] call _hasMagazine }) then {
        _primaryWeapon = _weapon;
        _primaryMag = _mag;
        _primaryMagCount = _count;
    };
} forEach _primaryCandidates;

if (_primaryWeapon != "") then {
    [_primaryMag, 1] call _addMagazines;
    _unit addWeapon _primaryWeapon;
    [_primaryMag, (_primaryMagCount - 1) max 0] call _addMagazines;
    _unit selectWeapon _primaryWeapon;
};

private _launcherCandidates = [
    ["launch_I_Titan_short_F", "Titan_AT", 3],
    ["launch_B_Titan_short_F", "Titan_AT", 3],
    ["launch_O_Titan_short_F", "Titan_AT", 3],
    ["launch_RPG32_F", "RPG32_F", 5],
    ["launch_NLAW_F", "NLAW_F", 4],
    ["launch_RPG7_F", "RPG7_F", 6]
];
private _launcher = "";
private _rocket = "";
private _rocketCount = 0;
{
    _x params ["_weapon", "_mag", "_count"];
    if (_launcher == "" && { [_weapon] call _hasWeapon && [_mag] call _hasMagazine }) then {
        _launcher = _weapon;
        _rocket = _mag;
        _rocketCount = _count;
    };
} forEach _launcherCandidates;

if (_launcher != "") then {
    [_rocket, 1] call _addMagazines;
    _unit addWeapon _launcher;
    [_rocket, (_rocketCount - 1) max 0] call _addMagazines;
};

["HandGrenade", 2] call _addMagazines;
["SmokeShell", 2] call _addMagazines;
{
    if (_unit canAdd _x) then { _unit addItem _x };
} forEach ["FirstAidKit", "FirstAidKit", "FirstAidKit"];
{
    if ([_x] call _hasWeapon) then { _unit linkItem _x };
} forEach ["ItemMap", "ItemCompass", "ItemWatch", "ItemRadio"];
if (["Binocular"] call _hasWeapon) then { _unit addWeapon "Binocular" };

_unit setVariable ["CO_frontLoadoutIssued", [
    primaryWeapon _unit,
    secondaryWeapon _unit,
    vest _unit,
    backpack _unit,
    headgear _unit,
    magazines _unit
], true];

diag_log format [
    "[CO] Front loadout issued to %1: primary=%2 mags=%3 launcher=%4 rockets=%5 vest=%6 backpack=%7 helmet=%8.",
    _unit,
    primaryWeapon _unit,
    { _x == _primaryMag } count magazines _unit,
    secondaryWeapon _unit,
    { _x == _rocket } count magazines _unit,
    vest _unit,
    backpack _unit,
    headgear _unit
];

true
