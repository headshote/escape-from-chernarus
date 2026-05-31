// ============================================================
// fn_policePatrols.sqf
// Spawns police car patrols in major towns.
// Police are passive unless player/civilian has fought back
// (CO_wantedLevel > 50 triggers recognition → pursuit).
// Runs on server.
// ============================================================

CO_policeTownPosts = [
    // [town pos, patrol radius, car count]
    [[6400,  2400, 0], 600, 3],   // Chernogorsk
    [[10200, 2300, 0], 500, 3],   // Elektrozavodsk
    [[12300, 9700, 0], 550, 3],   // Berezino
    [[3900,  7200, 0], 400, 2],   // Zelenogorsk
    [[7300,  7900, 0], 350, 2]    // Stary Sobor
];

{
    private _center = _x select 0;
    private _radius = _x select 1;
    private _carCount = _x select 2;

    // Spawn N police cars per town (more than before so they're actually visible)
    for "_c" from 0 to (_carCount - 1) do {
        private _spawnPos = _center getPos [30 + random 60, random 360];
        private _car  = "C_Offroad_01_F" createVehicle _spawnPos;
        private _grp  = createGroup west;
        _grp setVariable ["CO_faction", "POLICE"];

        private _driver = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
        _driver moveInDriver _car;
        private _partner = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
        _partner moveInCargo _car;

        // Give police look: uniform + helmet/cap, sidearm.
        // forceAddUniform avoids the "underwear" failure mode where
        // addUniform silently drops the item on the ground.
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
            // Driver must never autonomously engage — caused fast
            // pursuit + ramming when civilians were nearby; the
            // partner couldn't disembark because the driver kept
            // racing past targets.
            _x disableAI "AUTOTARGET";
            _x disableAI "TARGET";
        } forEach [_driver, _partner];

        // Mark the driver so the dismount-pursuit code can pick the
        // passenger as the on-foot chaser.
        _driver setVariable ["CO_isPoliceDriver", true, true];
        _partner setVariable ["CO_isPoliceDriver", false, true];

        // Cruise patrol loop around town. Slow LIMITED speed + SAFE
        // behaviour so they actually look around at civilians rather
        // than rocketing past them.
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

        // Mark the patrol car so dismount logic can reach it.
        _car setVariable ["CO_policePatrolCar", _grp, true];
        _grp setVariable ["CO_policePatrolCar", _car, true];

        // Behaviour loop: check all players for wanted status
        [_grp, _car, _center, _radius] spawn {
            params ["_grp", "_car", "_center", "_radius"];
            private _nextFootStop = time + 50 + random 40;
            while { alive _car } do {
                sleep 5;
                if (!CO_police_active) then { continue };

                // ----- AWOL conscripts: ALWAYS engage lethal -----
                {
                    private _awol = _x;
                    if (alive _awol && (_awol getVariable ["CO_isAWOL", false])) then {
                        if ((leader _grp) distance _awol < 220) then {
                            {
                                _x reveal [_awol, 4];
                                _x doWatch _awol;
                                _x doTarget _awol;
                                _x fireAtTarget [_awol];
                                _x setCombatMode "RED";
                                _x setBehaviour "COMBAT";
                            } forEach units _grp;
                        };
                    };
                } forEach allPlayers;

                // ----- Standard wanted-level / armed-civilian sweep -----
                {
                    private _p = _x;
                    if (!alive _p || captive _p) then { continue };
                    if ((leader _grp) distance _p > 150) then { continue };
                    if (_p getVariable ["CO_isCleared", false] &&
                        !(_p getVariable ["CO_isAWOL", false])) then { continue };

                    private _wantedLvl = _p getVariable ["CO_wantedLevel", 0];
                    private _hasFired  = _p getVariable ["CO_hasFiredWeapon", false];

                    // Engage at lower threshold if they've fired a weapon recently
                    private _trigger = _wantedLvl >= 50 ||
                                       _hasFired ||
                                       (_p getVariable ["CO_isAWOL", false]);
                    if (!_trigger) then { continue };

                    if ([leader _grp, _p] call co_main_fnc_policeRecognise) then {
                        // Stop the car and dismount both officers so
                        // they can actually chase on foot. Previously
                        // the driver kept cruising past targets at
                        // LIMITED speed and the partner never had a
                        // chance to engage. doStop + forceSpeed 0 +
                        // unassignVehicle + moveOut is the reliable
                        // chain — engine-level disembark commands
                        // ("GetOut") are best-effort while AI is
                        // mounted in a moving vehicle.
                        [_grp, _car, _p] spawn co_main_fnc_policeFootChase;
                    };
                } forEach allPlayers;

                // ----- Low-chance civilian-male intervention -----
                // Per the design: police should occasionally hassle
                // random civilian men. Each tick, with low probability,
                // attempt to detain one nearby civ male.
                if ((random 1) < 0.08) then {
                    private _civCandidates = ((leader _grp) nearEntities [["Man"], 80]) select {
                        alive _x &&
                        side _x == civilian &&
                        !captive _x &&
                        !(_x getVariable ["CO_isFemale", false]) &&
                        !(_x getVariable ["CO_captureInProgress", false]) &&
                        (group _x getVariable ["CO_faction", ""] == "")
                    };
                    if (count _civCandidates > 0) then {
                        private _civ = selectRandom _civCandidates;
                        _civ setVariable ["CO_captureInProgress", true, true];
                        [_civ] call co_main_fnc_installNonLethalDamage;
                        diag_log format ["[CO] Police random stop: %1 by patrol near %2.", _civ, mapGridPosition (leader _grp)];
                        // Use the shared foot-chase routine: stop car,
                        // dismount both officers, melee-knockout-capture.
                        [_grp, _car, _civ] spawn co_main_fnc_policeFootChase;
                    };
                };

                // ----- Periodic proactive foot stop -----
                // Even without a hard trigger, cars periodically pull over,
                // dismount, and attempt an on-foot intervention to keep town
                // pressure/tension high and avoid purely drive-by policing.
                if (
                    time >= _nextFootStop &&
                    !(_grp getVariable ["CO_policeFootChaseActive", false])
                ) then {
                    private _cand = ((leader _grp) nearEntities [["Man"], 140]) select {
                        alive _x &&
                        !captive _x &&
                        !(_x getVariable ["CO_knockedOut", false]) &&
                        !(_x getVariable ["CO_captureInProgress", false]) &&
                        (isPlayer _x || side _x == civilian) &&
                        !(_x getVariable ["CO_isFemale", false]) &&
                        ((group _x) getVariable ["CO_faction", ""] == "")
                    };

                    if (count _cand > 0) then {
                        _cand = [_cand, [], { _x distance2D (leader _grp) }, "ASCEND"] call BIS_fnc_sortBy;
                        private _target = _cand select 0;
                        [_target] call co_main_fnc_installNonLethalDamage;
                        _target setVariable ["CO_captureInProgress", true, true];
                        [_grp, _car, _target] spawn co_main_fnc_policeFootChase;
                        diag_log format ["[CO] Police proactive foot stop near %1 targeting %2.", mapGridPosition (leader _grp), _target];
                    };
                    _nextFootStop = time + 65 + random 45;
                };
            };
        };
    };
} forEach CO_policeTownPosts;
