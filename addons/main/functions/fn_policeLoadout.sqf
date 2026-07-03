// ============================================================
// fn_policeLoadout.sqf — shared police gear applicator
//
// Fixes the "cops in underwear" bug: the previous classname
// "U_B_GendarmerieSuit_01_F" does not exist in vanilla A3 (the
// Malden DLC Gendarmerie uniform is "U_B_GEN_Soldier_F"), so
// forceAddUniform silently failed on all three police spawners.
// Every candidate is now validated against the config before use
// and the result is verified afterwards, with a guaranteed-vanilla
// fallback — a cop can never spawn nude again.
//
// Used by fn_policePatrols, fn_spawnUrbanFootPatrols, and
// fn_spawnLockdownPatrol so the look stays consistent.
//
// params: [_unit]
// ============================================================
params [["_unit", objNull]];
if (isNull _unit) exitWith {};

// Resolve once per session.
if (isNil "CO_policeUniformClass") then {
    CO_policeUniformClass = "";
    {
        if (isClass (configFile >> "CfgWeapons" >> _x)) exitWith {
            CO_policeUniformClass = _x;
        };
    } forEach [
        "U_B_GEN_Soldier_F",          // Malden DLC Gendarmerie (correct class)
        "U_B_GendarmerieSuit_01_F",   // legacy name, kept in case a mod provides it
        "U_BG_Guerilla2_1"            // vanilla fallback — never underwear
    ];
    diag_log format ["[CO] Police uniform resolved to '%1'.", CO_policeUniformClass];
};

removeAllWeapons _unit;
removeAllItems _unit;
removeUniform _unit;
removeVest _unit;
removeHeadgear _unit;

if (CO_policeUniformClass != "") then {
    _unit forceAddUniform CO_policeUniformClass;
};
// Belt and braces: verify it actually stuck.
if (uniform _unit == "") then {
    _unit forceAddUniform "U_BG_Guerilla2_1";
};

_unit addVest "V_HarnessOGL_ghex_F";
if (vest _unit == "") then { _unit addVest "V_TacVest_blk" };
_unit addHeadgear "H_Cap_blk_Raven";

_unit addWeapon "hgun_P07_F";
_unit addMagazine "16Rnd_9x21_Mag";
_unit addMagazine "16Rnd_9x21_Mag";
_unit allowFleeing 0;

// Officers witness crimes and feed fn_reportCrime.
[_unit] call co_main_fnc_installCrimeWitness;
