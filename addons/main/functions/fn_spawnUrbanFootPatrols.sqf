// ============================================================
// fn_spawnUrbanFootPatrols.sqf
//
// Adds persistent pedestrian pressure in major towns so TCK/Police
// are not only seen in vehicles. These groups rely on existing
// aggression systems (tckGlobalAggression + checkpointAlert) for
// detain/chase behavior.
// ============================================================
if (!isServer) exitWith {};

private _towns = [
    // [center, radius, policeGroups, tckGroups]
    [[6400,  2400, 0], 550, 2, 2],   // Chernogorsk
    [[10200, 2300, 0], 500, 2, 2],   // Elektrozavodsk
    [[12300, 9700, 0], 520, 2, 2],   // Berezino
    [[3900,  7200, 0], 380, 1, 1],   // Zelenogorsk
    [[7300,  7900, 0], 340, 1, 1]    // Stary Sobor
];

private _mkPoliceFoot = {
    params ["_pos", "_center", "_radius"];
    private _grp = createGroup [west, true];
    _grp setVariable ["CO_faction", "POLICE", true];
    _grp setBehaviour "SAFE";
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode "LIMITED";

    for "_i" from 1 to 2 do {
        private _u = _grp createUnit ["B_Soldier_F", _pos, [], 0, "FORM"];
        removeAllWeapons _u;
        removeAllItems _u;
        removeUniform _u;
        removeVest _u;
        removeHeadgear _u;
        _u forceAddUniform "U_B_GendarmerieSuit_01_F";
        _u addVest "V_HarnessOGL_ghex_F";
        _u addHeadgear "H_Cap_blk_Raven";
        _u addWeapon "hgun_P07_F";
        _u addMagazine "16Rnd_9x21_Mag";
        _u addMagazine "16Rnd_9x21_Mag";
        _u setBehaviour "SAFE";
        _u setCombatMode "YELLOW";
        _u allowFleeing 0;
    };

    for "_w" from 0 to 5 do {
        private _wpPos = _center getPos [_radius * (0.3 + random 0.7), random 360];
        private _wp = _grp addWaypoint [_wpPos, 15];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "LIMITED";
        _wp setWaypointBehaviour "SAFE";
        _wp setWaypointCombatMode "BLUE";
    };
    private _cycle = _grp addWaypoint [_center getPos [_radius * 0.2, random 360], 15];
    _cycle setWaypointType "CYCLE";
    _grp
};

private _mkTckFoot = {
    params ["_pos", "_center", "_radius"];
    private _grp = createGroup [west, true];
    _grp setVariable ["CO_faction", "CRN_ENF", true];
    _grp setBehaviour "AWARE";
    _grp setCombatMode "YELLOW";
    _grp setSpeedMode "NORMAL";

    for "_i" from 1 to 3 do {
        private _u = _grp createUnit ["B_Soldier_F", _pos, [], 0, "FORM"];
        [_u] call co_main_fnc_initHostileUnit;
        _u setBehaviour "AWARE";
        _u setCombatMode "YELLOW";
        _u allowFleeing 0;
    };

    for "_w" from 0 to 6 do {
        private _wpPos = _center getPos [_radius * (0.25 + random 0.75), random 360];
        private _wp = _grp addWaypoint [_wpPos, 20];
        _wp setWaypointType "MOVE";
        _wp setWaypointSpeed "NORMAL";
        _wp setWaypointBehaviour "AWARE";
        _wp setWaypointCombatMode "YELLOW";
    };
    private _cycle = _grp addWaypoint [_center getPos [_radius * 0.2, random 360], 20];
    _cycle setWaypointType "CYCLE";
    _grp
};

private _policeCount = 0;
private _tckCount = 0;
{
    private _center = _x select 0;
    private _radius = _x select 1;
    private _pGroups = _x select 2;
    private _tGroups = _x select 3;

    for "_i" from 1 to _pGroups do {
        private _spawn = _center getPos [20 + random 60, random 360];
        [_spawn, _center, _radius] call _mkPoliceFoot;
        _policeCount = _policeCount + 1;
    };

    for "_i" from 1 to _tGroups do {
        private _spawn = _center getPos [30 + random 90, random 360];
        [_spawn, _center, _radius] call _mkTckFoot;
        _tckCount = _tckCount + 1;
    };

    sleep 0.2;
} forEach _towns;

diag_log format ["[CO] Urban foot patrols spawned: policeGroups=%1 tckGroups=%2.", _policeCount, _tckCount];
