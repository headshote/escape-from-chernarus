// fn_deployToFront.sqf
params ["_conscript"];

// Prevent double-deploy (boot camp grad path + 10-min timeout could both fire)
if (_conscript getVariable ["CO_deployToFrontDone", false]) exitWith {};
_conscript setVariable ["CO_deployToFrontDone", true, true];

// ---- Full military loadout (cleared conscript) -----------------
// Inventory operations must run where the unit is local, especially for
// players. The helper also validates weapon/ammo pairs so deployment cannot
// leave a recruit with a rifle and the wrong magazines.
[_conscript] call co_main_fnc_applyFrontLoadout;

_conscript setCaptive false;
_conscript setVariable ["CO_isCleared", true, true];
_conscript setVariable ["CO_isAWOL", false, true];
_conscript setVariable ["CO_faction", "CRN_FRONT", true];

// ---- Teleport to Krasnostav north (front-line jump-off) ----
private _krasnostav = [11200, 12300, 0];
private _deployPos = _krasnostav vectorAdd [(random 200) - 100, 220 + random 80, 0];
_conscript setPos _deployPos;

// Assign to a Chernarus Front group
private _frontGroups = allGroups select { _x getVariable ["CO_faction", ""] == "CRN_FRONT" && count units _x < 8 };
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
    diag_log format ["[CO] deployToFront: %1 could not join %2 because sides differ.", _conscript, side _assignedGroup];
};

if (isPlayer _conscript) then {
    [_conscript] remoteExecCall ["co_main_fnc_showFrontDeployHUD", _conscript];
    [["KRASNOSTAV FRONT\nHold the line. Deserters will be hunted by every faction."]] remoteExec ["hint", _conscript];
    // AWOL monitor: if the cleared conscript wanders > 1.2 km from
    // Krasnostav for more than 60 s, flag them AWOL and every
    // faction (TCK, border, police, RUS_ADV) becomes lethal.
    [_conscript, _krasnostav] spawn co_main_fnc_awolMonitor;

    // Engine sides cannot be changed at runtime (the player's mission
    // slot binds them to "civilian"). joinSilent above silently no-ops
    // on side mismatch, leaving the deployed conscript civilian-coded,
    // which means Russian invaders (east) and Chernarus army (west)
    // both ignore them by default. Resolve via a scripted hostility
    // tick: any RUS_ADV unit within 350 m of a CO_isCleared player
    // gets a direct reveal/fireAtTarget order, bypassing engine side
    // relations.
    [_conscript] spawn co_main_fnc_russianHostilityTick;
};
