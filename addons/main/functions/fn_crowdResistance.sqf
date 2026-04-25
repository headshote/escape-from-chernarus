// fn_crowdResistance.sqf
// Called when a kidnapping attempt occurs in a crowd.
params ["_pos", "_hostileGrp", "_target"];

private _nearCivs = _pos nearEntities [["Man"], 30] select { side _x == civilian && !(_x getVariable ["CO_isFemale", false]) };
private _crowdSize = count _nearCivs;
private _hostileCount = count units _hostileGrp;

private _resistChance = ((_crowdSize - _hostileCount * 2) / 10) max 0 min 1;

if (random 1 < _resistChance) then {
    hint "[CROWD RISING]"; // debug; replace with subtle audio cue

    // Some civs attack
    private _attackers = _nearCivs select { random 1 < 0.4 };
    { _x setVariable ["CO_civState", "fighting"]; } forEach _attackers;

    // Hostiles either flee or open fire
    if (random 1 < 0.4) then {
        // Flee — abort kidnapping
        {
            _x doMove (getPosATL (leader _hostileGrp) vectorAdd [random 60 - 30, random 60 - 30, 0]);
            _x setBehaviour "STEALTH";
        } forEach units _hostileGrp;
        // Victim not captured
    } else {
        // Open fire — some civs die, survivor become wanted
        { _x setCombatMode "RED"; } forEach units _hostileGrp;
        // After fight settles, mark aggressive civs
        {
            private _civ = _x;
            [{ alive _civ && _civ distance vehicle (leader _hostileGrp) > 60 }, {
                params ["_c"];
                _c setVariable ["CO_wantedLevel", 60, true]; // now police target
            }, [_civ]] call CBA_fnc_waitUntilAndExecute;
        } forEach _attackers;
    };
};