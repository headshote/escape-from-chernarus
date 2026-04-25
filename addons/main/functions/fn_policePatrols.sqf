// ============================================================
// fn_policePatrols.sqf
// Spawns police car patrols in major towns.
// Police are passive unless player/civilian has fought back
// (CO_wantedLevel > 50 triggers recognition → pursuit).
// Runs on server.
// ============================================================

CO_policeTownPosts = [
    // [town pos, patrol radius]
    [[6400,  2400, 0], 600],   // Chernogorsk
    [[10200, 2300, 0], 500],   // Elektrozavodsk
    [[11600, 7800, 0], 500],   // Berezino
    [[3900,  7200, 0], 400],   // Zelenogorsk
    [[7300,  7900, 0], 350],   // Stary Sobor
];

{
    private _center = _x select 0;
    private _radius = _x select 1;

    // Spawn 2 police cars per town
    for "_c" from 0 to 1 do {
        private _spawnPos = _center getPos [30 + random 60, random 360];
        private _car  = "C_Offroad_01_F" createVehicle _spawnPos;
        private _grp  = createGroup west;
        _grp setVariable ["CO_faction", "POLICE"];

        private _driver = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
        _driver moveInDriver _car;
        private _partner = _grp createUnit ["B_Soldier_F", _spawnPos, [], 0, "CARGO"];
        _partner moveInCargo _car;

        // Give police look: uniform only, pistol
        {
            removeAllWeapons _x;
            removeAllItems _x;
            removeUniform _x;
            removeVest _x;
            removeHeadgear _x;
            _x addUniform "U_B_GendarmerieSuit_01_F";
            _x addVest "V_HarnessOGL_ghex_F";
            _x addHeadgear "H_Cap_blk_Raven";
            _x addWeapon "hgun_P07_F";
            _x addMagazine "16Rnd_9x21_Mag";
            _x addMagazine "16Rnd_9x21_Mag";
            _x setCombatMode "YELLOW";
            _x setBehaviour "SAFE";
            _x allowFleeing 0;
        } forEach [_driver, _partner];

        // Cruise patrol loop around town
        for "_w" from 0 to 5 do {
            private _wPos = _center getPos [_radius * (0.4 + random 0.6), random 360];
            private _wp = _grp addWaypoint [_wPos, 30];
            _wp setWaypointSpeed "LIMITED";
            _wp setWaypointType "MOVE";
        };
        private _cycleWp = _grp addWaypoint [_center getPos [_radius * 0.3, random 360], 20];
        _cycleWp setWaypointType "CYCLE";

        // Behaviour loop: check all players for wanted status
        [_grp, _car, _center, _radius] spawn {
            params ["_grp", "_car", "_center", "_radius"];
            while { alive _car } do {
                sleep 5;
                if (!CO_police_active) then { continue };
                {
                    private _p = _x;
                    if (!alive _p || captive _p) then { continue };
                    if ((leader _grp) distance _p > 120) then { continue };

                    private _wantedLvl = _p getVariable ["CO_wantedLevel", 0];
                    if (_wantedLvl < 50) then { continue };

                    if ([leader _grp, _p] call co_main_fnc_policeRecognise) then {
                        // Demand stop: switch to combat, pursue
                        { _x setCombatMode "RED"; _x doTarget _p; _x doMove getPosATL _p; } forEach units _grp;
                        // Capture check same as enforcer
                        [_p, _grp] spawn {
                            params ["_target","_grp"];
                            while { alive _target && !captive _target } do {
                                private _nearest = [units _grp select { alive _x }, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
                                if (count _nearest > 0 && (_nearest select 0) distance _target < 2.5) then {
                                    [_target] remoteExecCall ["co_main_fnc_wrangleMinigame", _target];
                                    waitUntil { !isNil { _target getVariable "CO_wrangleResult" } };
                                    private _r = _target getVariable ["CO_wrangleResult","captured"];
                                    _target setVariable ["CO_wrangleResult", nil, true];
                                    if (_r == "captured") then {
                                        _target setCaptive true;
                                        [_target, _grp] call co_main_fnc_transportToDetention;
                                    };
                                };
                                sleep 0.5;
                            };
                        };
                    };
                } forEach allPlayers;
            };
        };
    };
} forEach CO_policeTownPosts;
