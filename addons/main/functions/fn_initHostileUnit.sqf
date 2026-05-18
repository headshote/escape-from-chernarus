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

// Use forceAddUniform — plain addUniform silently fails when the engine
// thinks the unit's prototype can't wear the chosen item (the uniform
// ends up in inventory instead of on the body, leaving the AI running
// around in underwear). This was the source of the "TCK in underwear"
// bug: V_PlateCarrierL_CSAT is CSAT/OPFOR-side and the unit is a BLUFOR
// B_Soldier_F, so addVest dropped the vest to the ground. Same with
// some uniform combos. forceAddUniform bypasses the side check.
private _uniformCls = selectRandom ["U_BG_Guerilla1_1", "U_BG_Guerilla2_1", "U_BG_Guerilla3_1", "U_I_C_Soldier_Para_4_F"];
private _vestCls    = selectRandom ["V_TacVest_blk", "V_TacChestrig_grn_F", "V_HarnessO_brn", "V_HarnessOGL_brn"];
private _headCls    = selectRandom ["H_HelmetB", "H_HelmetB_light", "H_HelmetIA"];
_unit forceAddUniform _uniformCls;
_unit addVest    _vestCls;
_unit addHeadgear _headCls;
// Safety net: if forceAddUniform somehow still failed (mod conflict,
// missing class), drop a guaranteed-universal uniform on them so they
// never appear nude on the battlefield.
if (uniform _unit == "") then {
    _unit forceAddUniform "U_BG_Guerilla1_1";
};
if (vest _unit == "") then {
    _unit addVest "V_TacVest_blk";
};

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

// On killed — decrement front counter if applicable, replenish russians 1:1
_unit addEventHandler ["Killed", {
    params ["_killed"];
    private _fac = _killed getVariable ["CO_faction",""];
    if (_fac == "CRN_FRONT") then {
        CO_front_unitsRemaining = (CO_front_unitsRemaining - 1) max 0;
        publicVariable "CO_front_unitsRemaining";
        if (CO_front_unitsRemaining <= 10) then {
            [] call co_main_fnc_frontCollapse;
        };
    };
    // Russian advance: every dead OPFOR triggers a fresh replacement
    // from the northern Krasnostav-axis spawn, so the assault never
    // thins out. Spawned async to avoid blocking the kill handler.
    if (_fac == "RUS_ADV") then {
        [_killed] spawn {
            params ["_dead"];
            sleep (3 + random 5);
            [_dead] call co_main_fnc_spawnRussianReplacement;
        };
    };
}];