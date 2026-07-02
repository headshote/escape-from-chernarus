// ============================================================
// fn_policePatrols.sqf
// Spawns police car patrols and runs server-authoritative
// suspicion, ID checks, foot pursuit, vehicle pursuit, backup,
// and lockdown escalation.
// ============================================================

CO_policeTownPosts = [
    [[6400,  2400, 0], 600, 3],
    [[10200, 2300, 0], 500, 3],
    [[12300, 9700, 0], 550, 3],
    [[3900,  7200, 0], 400, 2],
    [[7300,  7900, 0], 350, 2]
];
CO_policePatrolGroups = [];

private _spawnPolicePatrol = {
    params ["_center", "_radius"];

    private _spawnPos = _center getPos [30 + random 60, random 360];
    private _car = "C_Offroad_01_F" createVehicle _spawnPos;
    private _grp = createGroup west;
    _grp setVariable ["CO_faction", "POLICE", true];
    _grp setVariable ["CO_policeTownCenter", _center, false];
    _grp setVariable ["CO_policeTownRadius", _radius, false];
    CO_policePatrolGroups pushBack _grp;

    private _driver = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
    _driver moveInDriver _car;
    private _partner = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
    _partner moveInCargo _car;

    {
        removeAllWeapons _x;
        removeAllItems _x;
        removeUniform _x;
        removeVest _x;
        removeHeadgear _x;
        _x forceAddUniform "U_B_GendarmerieSuit_01_F";
        _x addVest "V_HarnessOGL_ghex_F";
        _x addHeadgear "H_Cap_blk_Raven";
        _x addWeapon "hgun_P07_F";
        _x addMagazine "16Rnd_9x21_Mag";
        _x addMagazine "16Rnd_9x21_Mag";
        _x setCombatMode "YELLOW";
        _x setBehaviour "SAFE";
        _x allowFleeing 0;
        _x disableAI "AUTOTARGET";
        _x disableAI "TARGET";
    } forEach [_driver, _partner];

    _driver setVariable ["CO_isPoliceDriver", true, true];
    _partner setVariable ["CO_isPoliceDriver", false, true];

    _grp setBehaviour "SAFE";
    _grp setSpeedMode "LIMITED";
    for "_w" from 0 to 5 do {
        private _wPos = _center getPos [_radius * (0.4 + random 0.6), random 360];
        private _wp = _grp addWaypoint [_wPos, 30];
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCombatMode "BLUE";
        _wp setWaypointType "MOVE";
    };
    private _cycleWp = _grp addWaypoint [_center getPos [_radius * 0.3, random 360], 20];
    _cycleWp setWaypointType "CYCLE";

    _car setVariable ["CO_policePatrolCar", _grp, true];
    _grp setVariable ["CO_policePatrolCar", _car, true];

    [_grp, _car, _center, _radius] spawn {
        params ["_grp", "_car", "_center", "_radius"];
        private _nextFootStop = time + 70 + random 50;

        while { alive _car } do {
            sleep 5;
            if (!CO_police_active) then { continue };
            if (_grp getVariable ["CO_policeFootChaseActive", false]) then { continue };
            if (_grp getVariable ["CO_vehiclePursuitActive", false]) then { continue };

            {
                private _p = _x;
                if (!alive _p || captive _p) then { continue };
                if (_p getVariable ["CO_isCleared", false] && !(_p getVariable ["CO_isAWOL", false])) then { continue };

                private _dist = (leader _grp) distance2D _p;
                private _key = format ["CO_suspicion_%1", netId _p];
                private _sus = _grp getVariable [_key, 0];

                if (_dist > 190) then {
                    _grp setVariable [_key, (_sus - 10) max 0, false];
                    continue;
                };

                private _wanted = _p getVariable ["CO_wantedLevel", 0];
                private _hasFired = _p getVariable ["CO_hasFiredWeapon", false];
                private _hardTrigger = _wanted >= 75 || _hasFired || (_p getVariable ["CO_isAWOL", false]);
                private _visible = false;
                if (_dist < 150) then {
                    private _vis = [vehicle (leader _grp), "VIEW"] checkVisibility [eyePos (leader _grp), eyePos _p];
                    _visible = _vis > 0.12 || _dist < 25;
                };

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
                    _sus = (_sus + _rate) min 100;
                } else {
                    _sus = (_sus - 15) max 0;
                };
                _grp setVariable [_key, _sus, false];

                if (_sus > 30 && _sus < 60 && time > (_p getVariable ["CO_nextPoliceHailAt", 0])) then {
                    _p setVariable ["CO_nextPoliceHailAt", time + 18, true];
                    [_p, "SUSPICIOUS", "police_hail", 25, _grp] call co_main_fnc_setEscalationState;
                    if (isPlayer _p) then { ["Police: Stop. Documents."] remoteExecCall ["systemChat", _p] };
                };

                if (_sus >= 60 || _hardTrigger) then {
                    if (vehicle _p != _p) then {
                        [_grp, _car, _p, "police_vehicle"] spawn co_main_fnc_policeVehiclePursuit;
                    } else {
                        private _canInspect = !_hardTrigger && abs (speed _p) < 2 && _wanted < 75;
                        if (_canInspect && !(_p getVariable ["CO_policeInspecting", false])) then {
                            _p setVariable ["CO_policeInspecting", true, true];
                            [_grp, _car, _p, _key] spawn {
                                params ["_grp", "_car", "_p", "_key"];
                                if (isPlayer _p) then { ["Police are checking your papers. Stay still."] remoteExecCall ["systemChat", _p] };
                                sleep (10 + random 5);
                                _p setVariable ["CO_policeInspecting", false, true];
                                if (!alive _p || captive _p) exitWith {};
                                if ((leader _grp) distance2D _p > 45 || abs (speed _p) > 4) exitWith {
                                    _p setVariable ["CO_wantedLevel", ((_p getVariable ["CO_wantedLevel", 0]) + 20) min 100, true];
                                    [_p, "PURSUIT", "police_fled_id", 65, _grp] call co_main_fnc_setEscalationState;
                                    [_grp, _car, _p] spawn co_main_fnc_policeFootChase;
                                };
                                private _wanted = _p getVariable ["CO_wantedLevel", 0];
                                private _disguise = _p getVariable ["CO_disguiseLevel", 0];
                                if ((_wanted - (_disguise * 10) + random 20) < 50) then {
                                    _grp setVariable [_key, 0, false];
                                    [_p, "CLEAR", "police_id_pass", 0, _grp] call co_main_fnc_setEscalationState;
                                    if (isPlayer _p) then { ["Police: Move along."] remoteExecCall ["systemChat", _p] };
                                } else {
                                    [_p, "PURSUIT", "police_id_fail", 70, _grp] call co_main_fnc_setEscalationState;
                                    [_grp, _car, _p] spawn co_main_fnc_policeFootChase;
                                };
                            };
                        } else {
                            [_grp, _car, _p] spawn co_main_fnc_policeFootChase;
                        };
                    };
                };
            } forEach allPlayers;

            if ((random 1) < 0.04 && time > _nextFootStop) then {
                private _civCandidates = ((leader _grp) nearEntities [["Man"], 100]) select {
                    alive _x &&
                    side _x == civilian &&
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
                _nextFootStop = time + 80 + random 60;
            };
        };
    };
};

{
    private _center = _x select 0;
    private _radius = _x select 1;
    private _carCount = _x select 2;
    for "_c" from 0 to (_carCount - 1) do {
        [_center, _radius] call _spawnPolicePatrol;
    };
} forEach CO_policeTownPosts;
