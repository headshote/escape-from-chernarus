// ============================================================
// fn_initHostileUnit.sqf
// Initialises a hostile NPC: faction tag, combat stance, gear.
// ============================================================
params ["_unit"];

// Tag faction so scripts can distinguish ENF from FRONT/RUS
if (isNil { _unit getVariable "CO_faction" }) then {
    _unit setVariable ["CO_faction", "CRN_ENF"];
};

// Strip default loadout and equip occupation-style gear
removeAllWeapons _unit;
removeAllItems _unit;
removeAllAssignedItems _unit;
removeUniform _unit;
removeVest _unit;
removeBackpack _unit;
removeHeadgear _unit;

_unit addUniform (selectRandom ["U_B_CombatUniform_mcam", "U_B_CombatUniform_mcam_worn"]);
_unit addVest    (selectRandom ["V_PlateCarrierL_CSAT", "V_PlateCarrier1_rig"]);
_unit addHeadgear (selectRandom ["H_HelmetB", "H_HelmetB_light"]);

private _rifle = selectRandom ["arifle_AKM_F","arifle_AK12_F","arifle_AKS_F"];
_unit addWeapon _rifle;
_unit addMagazine "30Rnd_762x39_Mag_F";
_unit addMagazine "30Rnd_762x39_Mag_F";
_unit addMagazine "30Rnd_762x39_Mag_F";
_unit addItem "FirstAidKit";

// Combat posture — AWARE/YELLOW so guards actually engage once a target
// is identified. SAFE made them never raise their weapons at civilians.
_unit setUnitPos "UP";
_unit setBehaviour "AWARE";
_unit setCombatMode "YELLOW";
_unit allowFleeing 0;
_unit setSkill ["aimingAccuracy", 0.25];
_unit setSkill ["aimingShake", 0.45];
_unit setSkill ["spotDistance", 0.7];
_unit setSkill ["spotTime", 0.6];
_unit setSkill ["courage", 0.9];

// On killed — decrement front counter if applicable
_unit addEventHandler ["Killed", {
    params ["_killed"];
    if (_killed getVariable ["CO_faction",""] == "CRN_FRONT") then {
        CO_front_unitsRemaining = (CO_front_unitsRemaining - 1) max 0;
        publicVariable "CO_front_unitsRemaining";
        if (CO_front_unitsRemaining <= 10) then {
            [] call co_main_fnc_frontCollapse;
        };
    };
}];