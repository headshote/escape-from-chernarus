// fn_civilianAI.sqf
// Spawns civilian NPCs that walk, react to hostiles, comply or flee.

CO_civilianSpawnPoints = getMarkerPos "civ_spawn_zone"; // or explicit list

for "_i" from 1 to 40 do {
    private _pos = [CO_civilianSpawnPoints, 300] call BIS_fnc_randomPosByGrid;
    private _grp = createGroup civilian;
    private _gender = selectRandom ["C_man_polo_1_F", "C_man_polo_2_F", "C_Woman_casual_F"];
    private _civ = _grp createUnit [_gender, _pos, [], 5, "NONE"];

    _civ setVariable ["CO_isFemale", (_gender == "C_Woman_casual_F")];
    _civ setVariable ["CO_civState", "walking"]; // walking | fleeing | compliant | fighting

    // Wander behavior
    [_civ] spawn {
        params ["_civ"];
        while { alive _civ } do {
            private _state = _civ getVariable ["CO_civState", "walking"];
            switch (_state) do {
                case "walking": {
                    private _dest = getPosATL _civ vectorAdd [random 80 - 40, random 80 - 40, 0];
                    _civ doMove _dest;
                    waitUntil { sleep 1; !(_civ isFormationLeader) || _civ distance _dest < 5 || _civ getVariable "CO_civState" != "walking" };
                };
                case "fleeing": {
                    private _away = getPosATL _civ vectorAdd [random 100 - 50, random 100 - 50, 0];
                    _civ doMove _away;
                    _civ setSpeedMode "FULL";
                    sleep 5;
                    _civ setVariable ["CO_civState", "walking"];
                };
                case "compliant": {
                    sleep 8; // stays put, hands up (setCaptive or animation)
                    _civ playMoveNow "AmovPercMstpSrasWrflDnon"; // surrender anim
                };
                case "fighting": {
                    // Cheap melee: civilian runs at nearest hostile and triggers setCombatMode
                    private _hostile = nearestEnemy _civ;
                    if (!isNull _hostile) then {
                        _civ setCombatMode "RED";
                        _civ doTarget _hostile;
                    };
                    sleep 3;
                };
            };
            sleep 0.5;
        };
    };

    // React to nearby hostiles
    [_civ] spawn {
        params ["_civ"];
        while { alive _civ } do {
            private _nearHostiles = _civ nearEntities [["O_Soldier_F"], 40];
            if (count _nearHostiles > 0 && _civ getVariable "CO_civState" == "walking") then {
                private _isFemale = _civ getVariable ["CO_isFemale", false];
                if (_isFemale) then {
                    // Women not targeted — only react if nearby male is being grabbed
                    sleep 5;
                } else {
                    private _roll = random 1;
                    _civ setVariable ["CO_civState",
                        [["fleeing", "compliant", "fighting"], [0.5, 0.35, 0.15]] call BIS_fnc_randomIndex,
                    false];
                };
            };
            sleep 2;
        };
    };
};