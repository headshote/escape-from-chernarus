// fn_civilianAI.sqf
// Spawns civilian NPCs that walk, react to hostiles, comply or flee.

// Use settlement positions as spawn zones
private _totalCivs = 40;
private _settlementPlan = [];

{
    private _guaranteed = switch (_x select 2) do {
        case "large":  { 4 };
        case "medium": { 2 };
        default         { 1 };
    };

    for "_slot" from 1 to _guaranteed do {
        _settlementPlan pushBack _x;
    };
} forEach CO_settlements;

private _prioritySettlements = CO_settlements select { (_x select 2) in ["large", "medium"] };
while { count _settlementPlan < _totalCivs } do {
    _settlementPlan pushBack (selectRandom _prioritySettlements);
};

if (count _settlementPlan > _totalCivs) then {
    _settlementPlan resize _totalCivs;
};

{
    // Pick a random settlement, offset within it
    private _basePos = _x select 1;
    private _pos = _basePos vectorAdd [random 200 - 100, random 200 - 100, 0];
    private _grp = createGroup civilian;
    private _gender = selectRandom ["C_man_polo_1_F", "C_man_polo_2_F", "C_man_casual_4_F", "C_Woman_casual_F"];
    private _civ = _grp createUnit [_gender, _pos, [], 5, "NONE"];

    _civ setVariable ["CO_isFemale", (_gender == "C_Woman_casual_F")];
    _civ setVariable ["CO_civState", "walking"]; // walking | fleeing | compliant | fighting

    // Wander behavior
    [_civ] spawn {
        params ["_civ"];
        while { alive _civ } do {
            private _state = _civ getVariable ["CO_civState", "walking"];
            if (_state isEqualTo "walking") then {
                private _dest = getPosATL _civ vectorAdd [random 80 - 40, random 80 - 40, 0];
                _civ doMove _dest;
                waitUntil {
                    sleep 1;
                    !alive _civ ||
                    _civ distance _dest < 5 ||
                    (_civ getVariable ["CO_civState", "walking"]) != "walking"
                };
            };

            if (_state isEqualTo "fleeing") then {
                private _away = getPosATL _civ vectorAdd [random 100 - 50, random 100 - 50, 0];
                _civ doMove _away;
                _civ setSpeedMode "FULL";
                sleep 5;
                _civ setVariable ["CO_civState", "walking"];
            };

            if (_state isEqualTo "compliant") then {
                sleep 8; // stays put, hands up (setCaptive or animation)
                _civ playMoveNow "AmovPercMstpSrasWrflDnon"; // surrender anim
            };

            if (_state isEqualTo "fighting") then {
                // Cheap melee: civilian runs at nearest hostile and targets them.
                private _hostile = _civ findNearestEnemy _civ;
                if (!isNull _hostile) then {
                    _civ setCombatMode "RED";
                    _civ doTarget _hostile;
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
                side _x in [west, east] && !(isPlayer _x) && !(captive _x)
            };
            if (count _nearHostiles > 0 && (_civ getVariable ["CO_civState", "walking"]) == "walking") then {
                private _isFemale = _civ getVariable ["CO_isFemale", false];
                if (_isFemale) then {
                    // Women are not targeted; only react if nearby male is being grabbed.
                    sleep 5;
                } else {
                    private _roll = random 1;
                    private _newState = "fighting";
                    if (_roll < 0.5) then {
                        _newState = "fleeing";
                    } else {
                        if (_roll < 0.85) then {
                            _newState = "compliant";
                        };
                    };
                    _civ setVariable ["CO_civState", _newState, false];
                };
            };
            sleep 2;
        };
    };
} forEach _settlementPlan;

diag_log format ["[CO] Civilian AI spawned: %1 civilians across %2 settlements.", count _settlementPlan, count CO_settlements];