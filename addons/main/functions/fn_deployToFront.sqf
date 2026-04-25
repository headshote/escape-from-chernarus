// fn_deployToFront.sqf
params ["_conscript"];

// Basic military loadout — poor quality (conscript fodder)
_conscript addUniform "U_O_CombatUniform_ocamo";
_conscript addVest "V_PlateCarrierGL_oli";
_conscript addWeapon "arifle_AK12_F";
_conscript addMagazine "30Rnd_762x39_Mag_F";
_conscript addMagazine "30Rnd_762x39_Mag_F";
_conscript setCaptive false;

// Deploy position: west of current Russian front line
private _deployX = (CO_rus_advanceFront + 800) max 10000; // always slightly behind front
private _deployPos = [_deployX, 5000 + random 3000, 0];
_conscript setPos _deployPos;

// Assign to a Chernarus Front group
private _frontGrp = allGroups select { _x getVariable ["CO_faction",""] == "CRN_FRONT" && count units _x < 8 };
if (count _frontGrp > 0) then {
    [_conscript] joinGroup (_frontGrp select 0);
} else {
    private _newGrp = createGroup west;
    _newGrp setVariable ["CO_faction", "CRN_FRONT"];
    [_conscript] joinGroup _newGrp;
};

// If player — give them a hint about their situation
if (isPlayer _conscript) then {
    [_conscript] remoteExecCall ["co_main_fnc_showFrontDeployHUD", _conscript];
};

// Player can now fight or try to desert (run west, away from front — which triggers
// Enforcer response if caught behind lines again)