// ============================================================
// fn_policeBrain.sqf — shared police controller (server-side)
//
// Repair plan R1-f. One brain for BOTH car patrols and foot
// patrols (pass objNull as _car for foot groups — the urban
// gendarmerie pairs previously had no controller at all after
// POLICE was removed from tckGlobalAggression).
//
// What it does every 5 s tick:
//   1. Responds to alert-net entries (crimes, chases published by
//      other systems) within radio range — cars 700 m, foot 400 m.
//   2. Runs the suspicion sweep over players: visibility-gated
//      accumulation, hails at 30+, engagement at 60+ or on hard
//      triggers (wanted >= 75, weapon fired, AWOL). Suspicion and
//      random-stop pressure scale with the town alert level set
//      by fn_reportCrime.
//   3. Random ID checks on players (restores the baseline police
//      presence that made the city feel policed at wanted 0 —
//      a compliant check is a 15-second tension beat, not a
//      capture; fleeing one is +20 wanted and a chase).
//   4. Occasional random stops of NPC civilian men (flavor).
//   5. AWOL conscripts: always engaged, lethal.
//
// params: [_grp, _car (objNull for foot), _center, _radius]
// ============================================================
params [
    ["_grp", grpNull],
    ["_car", objNull],
    ["_center", [0,0,0]],
    ["_radius", 400]
];

if (!isServer || isNull _grp) exitWith {};
if (_grp getVariable ["CO_policeBrainRunning", false]) exitWith {};
_grp setVariable ["CO_policeBrainRunning", true, false];

private _isCar = !isNull _car;

// Resolve which town-alert bucket this patrol belongs to.
private _townIdx = -1;
if (!isNil "CO_policeTownPosts") then {
    private _bestD = 900;
    {
        private _d = _center distance2D (_x select 0);
        if (_d < _bestD) then { _bestD = _d; _townIdx = _forEachIndex };
    } forEach CO_policeTownPosts;
};

// --------------------------------------------------------------
// Inspection beat, spawned per target. Hail → wait for compliance
// → papers check → pass / move-along / detain. Fleeing at any
// point = wanted +20 + foot chase.
// --------------------------------------------------------------
CO_fnc_policeInspection = missionNamespace getVariable ["CO_fnc_policeInspection", {
    params ["_grp", "_car", "_p", "_susKey", "_townAlert"];

    if (_p getVariable ["CO_policeInspecting", false]) exitWith {};
    _p setVariable ["CO_policeInspecting", true, true];

    private _cleanup = {
        params ["_p"];
        _p setVariable ["CO_policeInspecting", false, true];
    };

    [_p, "SUSPICIOUS", "police_id_check", 30, _grp] call co_main_fnc_setEscalationState;
    if (isPlayer _p) then {
        ["Police: STOP. Document check — stand still."] remoteExecCall ["systemChat", _p];
    };

    // Compliance window: 8 s to stop near the patrol.
    private _complyEnd = time + 8;
    waitUntil {
        sleep 0.5;
        !alive _p || captive _p || time > _complyEnd ||
        ((abs (speed _p)) < 2 && ((leader _grp) distance2D _p) < 50)
    };
    if (!alive _p || captive _p) exitWith { [_p] call _cleanup };

    private _fled = (abs (speed _p)) > 4 || ((leader _grp) distance2D _p) > 60;
    if (_fled) exitWith {
        [_p] call _cleanup;
        private _wl = ((_p getVariable ["CO_wantedLevel", 0]) + 20) min 100;
        _p setVariable ["CO_wantedLevel", _wl, true];
        [_p, "PURSUIT", "police_fled_id", 65, _grp] call co_main_fnc_setEscalationState;
        ["police_id_fled"] call co_main_fnc_kpi;
        [_grp, _car, _p] spawn co_main_fnc_policeFootChase;
    };

    if (isPlayer _p) then {
        ["Police are checking your papers. Stay still."] remoteExecCall ["systemChat", _p];
    };
    sleep (8 + random 5);
    if (!alive _p || captive _p) exitWith { [_p] call _cleanup };

    // Walked off mid-check = fled.
    if ((abs (speed _p)) > 4 || ((leader _grp) distance2D _p) > 60) exitWith {
        [_p] call _cleanup;
        private _wl = ((_p getVariable ["CO_wantedLevel", 0]) + 20) min 100;
        _p setVariable ["CO_wantedLevel", _wl, true];
        [_p, "PURSUIT", "police_fled_id", 65, _grp] call co_main_fnc_setEscalationState;
        [_grp, _car, _p] spawn co_main_fnc_policeFootChase;
    };

    private _wanted = _p getVariable ["CO_wantedLevel", 0];
    private _disguise = _p getVariable ["CO_disguiseLevel", 0];
    private _risk = _wanted - (_disguise * 12) + random 20 + (_townAlert * 5);

    [_p] call _cleanup;

    if (_risk < 45 && _wanted < 50) exitWith {
        _grp setVariable [_susKey, 0, false];
        [_p, "CLEAR", "police_id_pass", 0, _grp] call co_main_fnc_setEscalationState;
        ["police_id_pass"] call co_main_fnc_kpi;
        if (isPlayer _p) then { ["Police: Documents in order. Move along."] remoteExecCall ["systemChat", _p] };
    };

    if (_risk < 65 && _wanted < 50) exitWith {
        _grp setVariable [_susKey, 25, false];
        [_p, "SUSPICIOUS", "police_id_warned", 30, _grp] call co_main_fnc_setEscalationState;
        if (isPlayer _p) then { ["Police: We're watching you. Move along."] remoteExecCall ["systemChat", _p] };
    };

    // Detain.
    [_p, "PURSUIT", "police_id_fail", 70, _grp] call co_main_fnc_setEscalationState;
    ["police_id_detain"] call co_main_fnc_kpi;
    [_grp, _car, _p] spawn co_main_fnc_policeFootChase;
}];

[_grp, _car, _center, _radius, _isCar, _townIdx] spawn {
    params ["_grp", "_car", "_center", "_radius", "_isCar", "_townIdx"];

    private _nextCivStop = time + 70 + random 50;
    private _nextInvestigateAt = 0;

    while {
        ({ alive _x } count units _grp) > 0 &&
        { isNull _car || alive _car || ({ alive _x && vehicle _x == _x } count units _grp) > 0 }
    } do {
        sleep 5;
        if (!CO_police_active) then { continue };
        if (_grp getVariable ["CO_policeFootChaseActive", false]) then { continue };
        if (_grp getVariable ["CO_vehiclePursuitActive", false]) then { continue };
        if (_grp getVariable ["CO_policeInspectionActive", false]) then { continue };

        // Car destroyed mid-session → keep working as a foot patrol.
        private _carAlive = _isCar && { !isNull _car && alive _car };

        // ---- Town alert level (decays via expiry) --------------------
        private _townAlert = 0;
        if (_townIdx >= 0 && !isNil "CO_townAlertLevels") then {
            private _rec = CO_townAlertLevels getOrDefault [_townIdx, [0, 0]];
            if ((_rec select 1) > time) then { _townAlert = _rec select 0 };
        };

        private _leadPos = getPosATL (leader _grp);

        // ---- 1. Alert-net response -----------------------------------
        private _radioRange = if (_carAlive) then { 700 } else { 400 };
        private _alerts = [_leadPos, _radioRange, 90] call co_main_fnc_alertQuery;
        private _responded = false;
        {
            _x params ["_t", "_lkp", "_ts", "_src", "_heat"];
            if (_heat >= 55 && !isNull _t && alive _t && !captive _t &&
                !(_t getVariable ["CO_knockedOut", false]) &&
                !(_t getVariable ["CO_captureInProgress", false])) exitWith {
                _responded = true;
                private _tDist = (leader _grp) distance2D _t;
                if (_carAlive) then {
                    if (vehicle _t != _t || _tDist > 220) then {
                        [_grp, _car, _t, "police_alert_response"] spawn co_main_fnc_policeVehiclePursuit;
                    } else {
                        [_grp, _car, _t] spawn co_main_fnc_policeFootChase;
                    };
                } else {
                    if (_tDist < 300) then {
                        [_grp, objNull, _t] spawn co_main_fnc_policeFootChase;
                    } else {
                        // Too far to chase on foot — walk toward the LKP.
                        if (time > _nextInvestigateAt) then {
                            _nextInvestigateAt = time + 30;
                            { if (alive _x && vehicle _x == _x) then { _x doMove _lkp } } forEach units _grp;
                        };
                        _responded = false;
                    };
                };
            };
        } forEach _alerts;
        if (_responded) then { continue };

        // ---- 2/3. Player sweep ----------------------------------------
        {
            private _p = _x;
            if (!alive _p || captive _p) then { continue };
            if (_p getVariable ["CO_isCleared", false] && !(_p getVariable ["CO_isAWOL", false])) then { continue };
            if (_p getVariable ["CO_captureInProgress", false]) then { continue };
            if (_p getVariable ["CO_policeInspecting", false]) then { continue };

            private _dist = (leader _grp) distance2D _p;
            private _key = format ["CO_suspicion_%1", netId _p];
            private _sus = _grp getVariable [_key, 0];

            // ---- AWOL conscripts: always engage, lethal --------------
            if (_p getVariable ["CO_isAWOL", false] && _dist < 220) then {
                {
                    _x reveal [_p, 4];
                    _x doTarget _p;
                    _x fireAtTarget [_p];
                    _x setCombatMode "RED";
                    _x setBehaviour "COMBAT";
                } forEach (units _grp select { alive _x });
                continue;
            };

            if (_dist > 190) then {
                _grp setVariable [_key, (_sus - 10) max 0, false];
                continue;
            };

            private _wanted = _p getVariable ["CO_wantedLevel", 0];
            private _hasFired = _p getVariable ["CO_hasFiredWeapon", false];
            private _hardTrigger = _wanted >= 75 || _hasFired;

            private _visible = false;
            if (_dist < 150) then {
                private _vis = [vehicle (leader _grp), "VIEW"] checkVisibility [eyePos (leader _grp), eyePos _p];
                _visible = _vis > 0.12 || _dist < 25;
            };

            // Known fugitive recognition: wanted players don't need the
            // slow suspicion ramp, they need to not be SEEN. Disguise is
            // honored by fn_policeRecognise.
            private _recognised = _visible && _wanted >= 60 &&
                { _dist < 65 || { [leader _grp, _p] call co_main_fnc_policeRecognise } };

                if (_visible) then {
                private _base = missionNamespace getVariable ["CO_suspicion_baseRate", 12];
                private _disguise = _p getVariable ["CO_disguiseLevel", 0];
                private _armed = (primaryWeapon _p != "") || (handgunWeapon _p != "");
                private _running = abs (speed _p) > 12;
                private _night = dayTime < 5 || dayTime > 20;
                private _rate = _base + (_wanted * 0.35) - (_disguise * 8);
                if (_running) then { _rate = _rate + 12 };
                if (_armed) then { _rate = _rate + 18 };
                if (_hasFired) then { _rate = _rate + 35 };
                if (_night) then { _rate = _rate * 0.65 };
                _rate = _rate * (1 - ((_dist min 150) / 220));
                _rate = _rate * (1 + (_townAlert * 0.35));
                _sus = (_sus + (_rate max 0)) min 100;
                if (_wanted >= 60 && _dist < 90) then {
                    _sus = _sus max 65;
                };
            } else {
                _sus = (_sus - 15) max 0;
            };
            _grp setVariable [_key, _sus, false];

            // Hail once suspicion is climbing.
            if (_sus > 30 && _sus < 60 && time > (_p getVariable ["CO_nextPoliceHailAt", 0])) then {
                _p setVariable ["CO_nextPoliceHailAt", time + 18, true];
                [_p, "SUSPICIOUS", "police_hail", 25, _grp] call co_main_fnc_setEscalationState;
                if (isPlayer _p) then { ["Police are eyeing you."] remoteExecCall ["systemChat", _p] };
            };

            // ---- Engagement decision ---------------------------------
            if (_sus >= 60 || _hardTrigger || _recognised) then {
                if (vehicle _p != _p) then {
                    if (_carAlive) then {
                        [_grp, _car, _p, "police_vehicle"] spawn co_main_fnc_policeVehiclePursuit;
                    } else {
                        // Foot cops can't chase a car — call it in.
                        [_p, getPosATL (vehicle _p), "police_foot_spotted", 60] call co_main_fnc_alertPublish;
                        [_p, "SUSPICIOUS", "police_foot_spotted", 45, _grp] call co_main_fnc_setEscalationState;
                    };
                } else {
                    private _canInspect = !_hardTrigger && !_recognised && abs (speed _p) < 2 && _wanted < 75;
                    if (_canInspect) then {
                        [_grp, _car, _p, _key, _townAlert] spawn co_main_fnc_policeOrderInspection;
                    } else {
                        [_grp, _car, _p] spawn co_main_fnc_policeFootChase;
                    };
                };
                continue;
            };

            // ---- Random ID check (baseline police pressure) ----------
            if (_visible && _dist < 60 && vehicle _p == _p &&
                time > (_p getVariable ["CO_nextRandomIdAt", 0])) then {
                private _chance = (missionNamespace getVariable ["CO_police_carStopChance", 0.05]) * (1 + _townAlert);
                if ((random 1) < _chance) then {
                    _p setVariable ["CO_nextRandomIdAt", time + 240, true];
                    [_grp, _car, _p, _key, _townAlert] spawn co_main_fnc_policeOrderInspection;
                };
            };
        } forEach allPlayers;

        // ---- 4. Random NPC-civilian stop (flavor) ----------------------
        if ((random 1) < 0.04 && time > _nextCivStop) then {
            private _civCandidates = ((leader _grp) nearEntities [["Man"], 100]) select {
                alive _x &&
                side _x == civilian &&
                !isPlayer _x &&
                !captive _x &&
                !(_x getVariable ["CO_isFemale", false]) &&
                !(_x getVariable ["CO_captureInProgress", false]) &&
                (group _x getVariable ["CO_faction", ""] == "")
            };
            if (!(_civCandidates isEqualTo [])) then {
                private _civ = selectRandom _civCandidates;
                [_civ, "SUSPICIOUS", "police_random_stop", 25, _grp] call co_main_fnc_setEscalationState;
                [_grp, _car, _civ] spawn co_main_fnc_policeFootChase;
            };
            _nextCivStop = time + 80 + random 60;
        };
    };

    _grp setVariable ["CO_policeBrainRunning", false, false];
};
