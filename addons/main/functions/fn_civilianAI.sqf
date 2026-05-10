// fn_civilianAI.sqf
// Spawns civilian NPCs that walk, react to hostiles, comply or flee.

// Use settlement positions as spawn zones
private _totalCivs = missionNamespace getVariable ["CO_civilian_totalPopulation", 150];
// Read once at the top so both the planning loop and the spawn loop can see it.
// Previously this was scoped to the planning forEach which broke gender selection.
private _femaleOnlyTowns = missionNamespace getVariable ["CO_westBorderFemaleOnlyTowns", []];
private _settlementPlan = [];
private _weightedSettlements = [];

{
    private _townName = _x select 0;
    private _townType = _x select 2;
    private _guaranteed = switch (_townType) do {
        case "large":  { 18 };
        case "medium": { 8 };
        default         { 2 };
    };
    private _weight = switch (_townType) do {
        case "large":  { 5 };
        case "medium": { 3 };
        default         { 1 };
    };

    for "_slot" from 1 to _guaranteed do {
        _settlementPlan pushBack _x;
    };

    for "_weightIndex" from 1 to _weight do {
        _weightedSettlements pushBack _x;
    };
} forEach CO_settlements;

if (_weightedSettlements isEqualTo []) then {
    _weightedSettlements = +CO_settlements;
};

while { count _settlementPlan < _totalCivs } do {
    _settlementPlan pushBack (selectRandom _weightedSettlements);
};

if (count _settlementPlan > _totalCivs) then {
    _settlementPlan resize _totalCivs;
};

{
    private _townName = _x select 0;
    private _townType = _x select 2;
    private _basePos = _x select 1;
    private _townHotspots = switch (_townName) do {
        case "Chernogorsk":    { [[6400, 2400, 0], [6575, 2510, 0], [6240, 2285, 0]] };
        case "Elektrozavodsk": { [[10200, 2300, 0], [10370, 2440, 0], [10035, 2175, 0]] };
        case "Berezino":       { [[11600, 7800, 0], [11810, 7705, 0], [11420, 7920, 0]] };
        case "Stary Sobor":    { [[7300, 7900, 0], [7190, 8045, 0]] };
        case "Zelenogorsk":    { [[3900, 7200, 0], [4040, 7340, 0]] };
        default                 { [_basePos] };
    };
    private _spawnRadius = switch (_townType) do {
        case "large":  { 140 };
        case "medium": { 100 };
        default         { 55 };
    };

    private _anchorPos = (selectRandom _townHotspots) getPos [random _spawnRadius, random 360];
    private _nearRoads = _anchorPos nearRoads 60;
    if !(_nearRoads isEqualTo []) then {
        _anchorPos = getPosATL (selectRandom _nearRoads);
    };

    private _emptyPos = _anchorPos findEmptyPosition [0, 20, "C_man_1"];
    private _pos = if (_emptyPos isEqualTo []) then { _anchorPos } else { _emptyPos };
    private _grp = createGroup civilian;
    private _genderPool = if (_townName in _femaleOnlyTowns) then {
        ["C_Woman_casual_F"]
    } else {
        [
            "C_man_polo_1_F",
            "C_man_polo_2_F",
            "C_man_casual_4_F",
            "C_Man_casual_6_F",
            "C_man_hunter_1_F",
            "C_Woman_casual_F"
        ]
    };
    private _gender = selectRandom _genderPool;
    private _civ = _grp createUnit [_gender, _pos, [], 5, "NONE"];

    _civ setVariable ["CO_isFemale", (_gender == "C_Woman_casual_F")];
    _civ setVariable ["CO_civState", "walking"]; // walking | fleeing | compliant | fighting
    _civ setVariable ["CO_civAlertUntil", 0, false];
    _civ setVariable ["CO_homePos", _anchorPos, false];
    _civ setVariable ["CO_wanderRadius", switch (_townType) do { case "large": { 85 }; case "medium": { 60 }; default { 35 } }, false];
    _civ setBehaviour "CARELESS";
    _civ setSpeedMode "LIMITED";

    // Wander behavior
    [_civ] spawn {
        params ["_civ"];
        while { alive _civ } do {
            private _state = _civ getVariable ["CO_civState", "walking"];
            if (_state isEqualTo "walking") then {
                _civ setBehaviour "CARELESS";
                _civ setSpeedMode "LIMITED";

                if (random 1 < 0.3) then {
                    sleep (4 + random 7);
                };

                private _homePos = _civ getVariable ["CO_homePos", getPosATL _civ];
                private _wanderRadius = _civ getVariable ["CO_wanderRadius", 45];
                private _dest = _homePos getPos [random _wanderRadius, random 360];
                private _destRoads = _dest nearRoads 25;
                if !(_destRoads isEqualTo []) then {
                    _dest = getPosATL (selectRandom _destRoads);
                };

                _civ doMove _dest;
                waitUntil {
                    sleep 1;
                    !alive _civ ||
                    _civ distance _dest < 5 ||
                    (_civ getVariable ["CO_civState", "walking"]) != "walking"
                };
            };

            if (_state isEqualTo "fleeing") then {
                _civ setBehaviour "AWARE";
                _civ setSpeedMode "FULL";
                private _away = getPosATL _civ vectorAdd [random 100 - 50, random 100 - 50, 0];
                _civ doMove _away;
                sleep (5 + random 4);

                if (time > (_civ getVariable ["CO_civAlertUntil", 0])) then {
                    _civ setVariable ["CO_civState", "walking", false];
                };
            };

            if (_state isEqualTo "compliant") then {
                _civ setBehaviour "SAFE";
                _civ setSpeedMode "LIMITED";
                _civ playMoveNow "AmovPercMstpSrasWrflDnon"; // surrender anim
                sleep (5 + random 4);

                if (time > (_civ getVariable ["CO_civAlertUntil", 0])) then {
                    _civ switchMove "";
                    _civ setVariable ["CO_civState", "walking", false];
                };
            };

            if (_state isEqualTo "fighting") then {
                // Civilians that choose to fight try to get close enough to punch the nearest hostile.
                private _nearThreats = _civ nearEntities [["Man"], 10] select {
                    alive _x && side _x in [west, east] && !(captive _x)
                };
                private _hostile = if (_nearThreats isEqualTo []) then { objNull } else {
                    ([_nearThreats, [], { _x distance _civ }, "ASCEND"] call BIS_fnc_sortBy) select 0
                };

                if (!isNull _hostile) then {
                    _civ setBehaviour "AWARE";
                    _civ setCombatMode "RED";
                    _civ doTarget _hostile;
                    _civ doMove (getPosATL _hostile);

                    if ((_civ distance _hostile) < 2.4) then {
                        [_civ, _hostile] call co_main_fnc_applyMeleeHit;
                    };
                } else {
                    if (time > (_civ getVariable ["CO_civAlertUntil", 0])) then {
                        _civ setVariable ["CO_civState", "walking", false];
                    };
                };
                sleep 3;
            };
            sleep 0.5;
        };
    };

    // React to nearby hostiles
    [_civ] spawn {
        params ["_civ"];
        while { alive _civ } do {
            private _nearHostiles = _civ nearEntities [["Man"], 40] select {
                private _unit = _x;
                if (!alive _unit || _unit == _civ || captive _unit) exitWith { false };
                if !(side _unit in [west, east]) exitWith { false };

                private _threatObject = vehicle _unit;
                private _distance = _civ distance _threatObject;
                if (_distance < 12) exitWith { true };

                if (_threatObject != _unit) exitWith {
                    _distance < 20 && speed _threatObject > 4
                };

                private _losBlocks = lineIntersectsSurfaces [
                    AGLToASL eyePos _civ,
                    AGLToASL eyePos _unit,
                    _civ,
                    _unit,
                    true,
                    1,
                    "VIEW",
                    "FIRE"
                ];
                _losBlocks isEqualTo []
            };

            if (_nearHostiles isEqualTo []) then {
                if (time > (_civ getVariable ["CO_civAlertUntil", 0])) then {
                    private _state = _civ getVariable ["CO_civState", "walking"];
                    if (_state != "walking") then {
                        _civ setVariable ["CO_civState", "walking", false];
                    };
                };
            } else {
                _civ setVariable ["CO_civAlertUntil", time + 14, false];

                if ((_civ getVariable ["CO_civState", "walking"]) == "walking") then {
                    private _isFemale = _civ getVariable ["CO_isFemale", false];
                    private _roll = random 1;
                    private _newState = "fleeing";

                    if (_isFemale) then {
                        if (_roll < 0.7) then {
                            _newState = "compliant";
                        };
                    } else {
                        if (_roll >= 0.55 && _roll < 0.88) then {
                            _newState = "compliant";
                        } else {
                            if (_roll >= 0.88) then {
                                _newState = "fighting";
                            };
                        };
                    };

                    _civ setVariable ["CO_civState", _newState, false];
                };
            };
            sleep 3;
        };
    };

    // Yield every batch so we don't lock the server scheduler creating
    // hundreds of civilians on one frame. With ~150-220 civilians a 0.15s
    // sleep every 8 spawns keeps the cost spread across ~3-5 seconds.
    if (_forEachIndex % 8 == 7) then { sleep 0.15; };
} forEach _settlementPlan;

diag_log format ["[CO] Civilian AI spawned: %1 civilians across %2 settlements.", count _settlementPlan, count CO_settlements];