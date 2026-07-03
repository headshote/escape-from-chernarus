// ============================================================
// fn_buildTrainingGround.sqf
// Populates the NW airfield (CO_airfieldCenter) with a usable
// training ground: drill instructor, recruit formation NPCs,
// pop-up shooting targets, parade ground markers, and a final
// briefing station. Called by fn_buildAirfieldCamp after the
// perimeter is established.
// ============================================================

if (isNil "CO_airfieldCenter") then {
    CO_airfieldCenter = [2100, 12800, 0];
};

// Drill parade ground is offset inside the perimeter
CO_trainingFieldPos = (CO_airfieldCenter vectorAdd [60, 0, 0]);
publicVariable "CO_trainingFieldPos";

// --- Drill instructor group ---
private _drillGrp = createGroup west;
_drillGrp setVariable ["CO_faction", "CRN_ENF"];
_drillGrp setVariable ["CO_isDrillInstructor", true, true];

private _instructor = _drillGrp createUnit ["B_Soldier_TL_F", CO_trainingFieldPos, [], 0, "FORM"];
[_instructor] call co_main_fnc_initHostileUnit;
_instructor setRank "SERGEANT";
_instructor setName "Drill Instructor";
_instructor setDir 180;
_instructor disableAI "MOVE"; // stay at podium
_instructor setVariable ["CO_drillInstructor", true, true];

// Whistle-shout loop so the parade ground reads as live. Also
// self-heals the podium pose: if any aggression loop re-enabled
// his movement AI, he walks back and plants himself again.
[_instructor, CO_trainingFieldPos] spawn {
    params ["_inst", "_podium"];
    while { alive _inst } do {
        sleep (20 + random 30);
        if (alive _inst) then {
            if ((_inst distance2D _podium) > 8) then {
                _inst enableAI "MOVE";
                _inst doMove _podium;
            } else {
                _inst disableAI "MOVE";
                _inst setDir 180;
            };
            [_inst, "GestureGo"] remoteExec ["playActionNow", 0];
        };
    };
};

// --- Recruit formation NPCs (visual flavour) ---
// Spawn three rows of "recruit" props that drill in place.
private _recruitGrp = createGroup west;
_recruitGrp setVariable ["CO_faction", "CRN_ENF"];

for "_row" from 0 to 2 do {
    for "_col" from 0 to 4 do {
        private _rPos = CO_trainingFieldPos vectorAdd [
            -8 - (_row * 3),
            -6 + (_col * 3),
            0
        ];
        private _r = _recruitGrp createUnit ["B_Soldier_F", _rPos, [], 0, "FORM"];
        removeAllWeapons _r;
        removeAllAssignedItems _r;
        _r setDir 90;
        _r disableAI "MOVE";
        _r disableAI "AUTOTARGET";
        _r disableAI "TARGET";
        _r allowFleeing 0;
        _r setVariable ["CO_isRecruitDummy", true, true];

        // Idle drill: switchMove between attention and parade rest.
        // Re-asserts disableAI MOVE + formation spot every cycle so no
        // aggression loop can permanently march the dummy away.
        [_r, _rPos] spawn {
            params ["_u", "_spot"];
            while { alive _u } do {
                if ((_u distance2D _spot) > 5) then {
                    _u enableAI "MOVE";
                    _u doMove _spot;
                    sleep 6;
                };
                _u disableAI "MOVE";
                _u setDir 90;
                _u playMoveNow "AmovPercMstpSnonWnonDnon_Salute";
                sleep (4 + random 3);
                if (!alive _u) exitWith {};
                _u playMoveNow "Acts_AidlPercMstpSloWnonDnon01";
                sleep (5 + random 4);
            };
        };
    };
};

// --- Pop-up target range (4 stationary targets east of parade ground) ---
private _rangeStart = CO_trainingFieldPos vectorAdd [25, -20, 0];
for "_i" from 0 to 3 do {
    private _tPos = _rangeStart vectorAdd [_i * 4, 0, 0];
    private _target = "Target_PopUp_Moving_Acc_F" createVehicle _tPos;
    _target setDir 0;
};

// Range firing line (sandbags). Targets are EAST (+x), so the wall's
// long axis must run north-south (dir 90) — parallel to the target
// line — with shooters firing east over it. The old dir 0 left the
// bags pointing downrange like little fences to nowhere.
for "_b" from 0 to 3 do {
    private _bagPos = CO_trainingFieldPos vectorAdd [10, -20 + (_b * 4), 0];
    private _bag = "Land_BagFence_Long_F" createVehicle _bagPos;
    _bag setDir 90;
};

// ---------------------------------------------------------------
// PERSISTENT range props (was: spawned/deleted per quest run by
// fn_bootCampQuest, at coordinates INSIDE the sandbag line — the
// crate clipped a sandbag on spawn, physics blew it up (the smoke),
// and it vanished whenever the quest stage ended).
// ---------------------------------------------------------------

// Weapon rack: behind the south end of the firing line, clear of
// every sandbag, indestructible, never deleted.
private _rackPos = CO_trainingFieldPos vectorAdd [6, -28, 0];
private _rack = createVehicle ["Box_NATO_WpsSpecial_F", _rackPos, [], 0, "CAN_COLLIDE"];
_rack setPos _rackPos;
_rack setDir 90;
_rack allowDamage false;
clearWeaponCargoGlobal _rack;
clearMagazineCargoGlobal _rack;
clearItemCargoGlobal _rack;
clearBackpackCargoGlobal _rack;
_rack addWeaponCargoGlobal   ["arifle_AKM_F", 900];
_rack addMagazineCargoGlobal ["30Rnd_762x39_Mag_F", 100000];
_rack addBackpackCargoGlobal ["B_AssaultPack_rgr", 1000];
_rack addItemCargoGlobal     ["V_HarnessO_brn", 1000];
missionNamespace setVariable ["CO_bootCampRack", _rack, true];
missionNamespace setVariable ["CO_bootCampRackPos", _rackPos, true];

// One persistent JIP action — condition gates it to active recruits.
[
    _rack,
    [
        "<t color='#00ff00'>Pick up training rifle</t>",
        {
            params ["_target", "_caller"];
            if (!(_caller getVariable ["CO_bootCampActive", false])) exitWith {};
            if ("arifle_AKM_F" in (weapons _caller)) exitWith {
                hint "You already have the training rifle.";
            };
            _caller addWeapon "arifle_AKM_F";
            _caller addMagazine "30Rnd_762x39_Mag_F";
            _caller addMagazine "30Rnd_762x39_Mag_F";
            _caller addMagazine "30Rnd_762x39_Mag_F";
            _caller selectWeapon "arifle_AKM_F";
            hint "Training rifle issued.\nDestroy the three wooden targets downrange.";
        },
        nil, 1.5, true, true, "",
        "_this distance _target < 3 && (_this getVariable ['CO_bootCampActive', false])"
    ]
] remoteExec ["addAction", 0, true];

// Grenade pit: crate behind the throwing line + visible targets at
// the impact area so the stage-3 marker points at something real.
private _grenadeCratePos = CO_trainingFieldPos vectorAdd [-30, 52, 0];
private _gCrate = createVehicle ["Box_East_AmmoOrd_F", _grenadeCratePos, [], 0, "CAN_COLLIDE"];
_gCrate setPos _grenadeCratePos;
_gCrate allowDamage false;
clearWeaponCargoGlobal _gCrate;
clearMagazineCargoGlobal _gCrate;
clearItemCargoGlobal _gCrate;
clearBackpackCargoGlobal _gCrate;
_gCrate addMagazineCargoGlobal ["HandGrenade", 500];
missionNamespace setVariable ["CO_bootCampGrenadeCrate", _gCrate, true];

[
    _gCrate,
    [
        "<t color='#00ff00'>Take grenades (x3)</t>",
        {
            params ["_target", "_caller"];
            if (!(_caller getVariable ["CO_bootCampActive", false])) exitWith {};
            _caller addMagazine "HandGrenade";
            _caller addMagazine "HandGrenade";
            _caller addMagazine "HandGrenade";
            hint "Grenades issued.\nDetonate TWO inside the marked pit.";
        },
        nil, 1.5, true, true, "",
        "_this distance _target < 3 && (_this getVariable ['CO_bootCampActive', false])"
    ]
] remoteExec ["addAction", 0, true];

// Impact-area dressing: a wreck plus barrels — durable static props.
private _pitCenter = CO_trainingFieldPos vectorAdd [-30, 90, 0];
private _wreck = createVehicle ["Land_Wreck_Skodovka_F", _pitCenter, [], 0, "CAN_COLLIDE"];
_wreck setPos _pitCenter;
_wreck setDir (random 360);
{
    private _barrel = createVehicle ["Land_MetalBarrel_F", _pitCenter getPos [4 + random 3, _x], [], 0, "CAN_COLLIDE"];
    _barrel setDir (random 360);
} forEach [0, 90, 180, 270];

// ---------------------------------------------------------------
// Range wardens: two armed guards physically AT the range/pit so an
// escape attempt meets resistance immediately instead of only at the
// distant perimeter (the sentinel in fn_trainingPhase issues their
// fire orders — they just need to exist nearby).
// ---------------------------------------------------------------
{
    _x params ["_gPos", "_patrolTo"];
    private _wGrp = createGroup west;
    _wGrp setVariable ["CO_faction", "CRN_ENF"];
    private _w = _wGrp createUnit ["B_Soldier_TL_F", _gPos, [], 0, "FORM"];
    [_w] call co_main_fnc_initHostileUnit;
    private _wp1 = _wGrp addWaypoint [_gPos, 4];
    _wp1 setWaypointType "MOVE";
    _wp1 setWaypointSpeed "LIMITED";
    private _wp2 = _wGrp addWaypoint [_patrolTo, 4];
    _wp2 setWaypointType "MOVE";
    _wp2 setWaypointSpeed "LIMITED";
    private _wpC = _wGrp addWaypoint [_gPos, 4];
    _wpC setWaypointType "CYCLE";
} forEach [
    [CO_trainingFieldPos vectorAdd [16, -32, 0], CO_trainingFieldPos vectorAdd [16, 0, 0]],   // firing line
    [CO_trainingFieldPos vectorAdd [-38, 48, 0], CO_trainingFieldPos vectorAdd [-20, 70, 0]]  // grenade pit
];

// --- Inner perimeter trainers / minders so recruits can't just sprint out ---
private _minderRadius = 70;
for "_i" from 0 to 3 do {
    private _angle = _i * 90;
    private _minderPos = CO_trainingFieldPos getPos [_minderRadius, _angle];
    private _grp = createGroup west;
    _grp setVariable ["CO_faction", "CRN_ENF"];
    private _u = _grp createUnit ["B_Soldier_TL_F", _minderPos, [], 0, "FORM"];
    [_u] call co_main_fnc_initHostileUnit;
    // Wider scan radius so they intercept escaping conscripts
    [_grp, _minderPos, 55, "CRN_ENF"] call co_main_fnc_guardAggroLoop;
};

// --- Briefing flag + marker on map for admins ---
private _flag = "Flag_NATO_F" createVehicle CO_trainingFieldPos;
private _drillMarker = createMarker ["co_training_field", CO_trainingFieldPos];
_drillMarker setMarkerType "mil_objective";
_drillMarker setMarkerColor "ColorBLUFOR";
_drillMarker setMarkerText "Conscript Training";

diag_log "[CO] Training ground built at NW airfield.";
