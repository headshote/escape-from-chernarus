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
private _frontGroups = allGroups select { _x getVariable ["CO_faction",""] == "CRN_FRONT" && count units _x < 8 };
private _assignedGroup = if (count _frontGroups > 0) then {
    _frontGroups select 0
} else {
    private _newGrp = createGroup west;
    _newGrp setVariable ["CO_faction", "CRN_FRONT"];
    _newGrp
};

if (side _conscript == side _assignedGroup) then {
    [_conscript] joinSilent _assignedGroup;
} else {
    _conscript setVariable ["CO_faction", "CRN_FRONT", true];
    diag_log format ["[CO] deployToFront: %1 could not join %2 because sides differ.", _conscript, side _assignedGroup];
};

// If player — give them a hint about their situation
if (isPlayer _conscript) then {
    [_conscript] remoteExecCall ["co_main_fnc_showFrontDeployHUD", _conscript];
};

// Player can now fight or try to desert (run west, away from front — which triggers
// Enforcer response if caught behind lines again)