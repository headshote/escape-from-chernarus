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
_drillGrp setVariable ["CO_faction", "CRN_ENF", true];
_drillGrp setVariable ["CO_isDrillInstructor", true, true];

private _instructor = _drillGrp createUnit ["B_Soldier_TL_F", CO_trainingFieldPos, [], 0, "FORM"];
[_instructor] call co_main_fnc_initHostileUnit;
_instructor setRank "SERGEANT";
_instructor setName "Drill Instructor";
_instructor setDir 180;
_instructor disableAI "MOVE"; // stay at podium
_instructor setVariable ["CO_drillInstructor", true, true];

// Whistle-shout loop so the parade ground reads as live
[_instructor] spawn {
    params ["_inst"];
    while { alive _inst } do {
        sleep (20 + random 30);
        if (alive _inst) then {
            [_inst, "GestureGo"] remoteExec ["playActionNow", 0];
        };
    };
};

// --- Recruit formation NPCs (visual flavour) ---
// Spawn three rows of "recruit" props that drill in place.
private _recruitGrp = createGroup west;
_recruitGrp setVariable ["CO_faction", "CRN_ENF", true];

for "_row" from 0 to 2 do {
    for "_col" from 0 to 4 do {
        private _rPos = CO_trainingFieldPos vectorAdd [
            -8 - (_row * 3),
            -6 + (_col * 3),
            0
        ];
        private _r = _recruitGrp createUnit ["B_Soldier_F", _rPos, [], 0, "FORM"];
        _r setVariable ["CO_faction", "CRN_ENF", true];
        removeAllWeapons _r;
        removeAllAssignedItems _r;
        _r setDir 90;
        _r disableAI "MOVE";
        _r disableAI "AUTOTARGET";
        _r disableAI "TARGET";
        _r allowFleeing 0;
        _r setVariable ["CO_isRecruitDummy", true, true];

        // Idle drill: switchMove between attention and parade rest
        [_r] spawn {
            params ["_u"];
            while { alive _u } do {
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

// Range firing line (sandbags)
for "_b" from 0 to 3 do {
    private _bagPos = CO_trainingFieldPos vectorAdd [10, -20 + (_b * 4), 0];
    private _bag = "Land_BagFence_Long_F" createVehicle _bagPos;
    _bag setDir 0;
};

// --- Inner perimeter trainers / minders so recruits can't just sprint out ---
private _minderRadius = 70;
for "_i" from 0 to 3 do {
    private _angle = _i * 90;
    private _minderPos = CO_trainingFieldPos getPos [_minderRadius, _angle];
    private _grp = createGroup west;
    _grp setVariable ["CO_faction", "CRN_ENF", true];
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
