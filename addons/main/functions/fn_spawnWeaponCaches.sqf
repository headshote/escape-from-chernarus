// ============================================================
// fn_spawnWeaponCaches.sqf
// Hides weapon caches in apartments/buildings of large towns
// and at random rural locations.  Very sparse by design.
// Runs once on server.
// ============================================================

CO_weaponCaches = [];

// Cache definitions: [pos, loot table]
private _cacheDefs = [
    // Chernogorsk apartments / industrial
    [[6350, 2460, 0], "pistol"],
    [[6510, 2350, 0], "rifle"],
    [[6290, 2600, 0], "melee"],
    // Elektrozavodsk
    [[10250, 2310, 0], "pistol"],
    [[10150, 2450, 0], "melee"],
    // Berezino
    [[11580, 7850, 0], "rifle"],
    [[11700, 7720, 0], "pistol"],
    // Rural / forest caches (well hidden)
    [[8200,  4800, 0], "rifle"],
    [[5800,  8400, 0], "pistol"],
    [[9300, 10200, 0], "melee"],
    [[4100,  6900, 0], "rifle"],
    [[12500, 6100, 0], "melee"]
];

private _lootTables = [
    ["pistol",  ["hgun_P07_F"],           ["16Rnd_9x21_Mag",   "16Rnd_9x21_Mag"]],
    ["rifle",   ["arifle_AKM_F"],         ["30Rnd_762x39_Mag_F","30Rnd_762x39_Mag_F","30Rnd_762x39_Mag_F"]],
    ["melee",   [],                       []]   // melee-only cache: crowbar item + medkits
];

{
    private _pos     = _x select 0;
    private _type    = _x select 1;

    // Snap to nearby building floor if possible
    private _nearBuildings = nearestObjects [_pos, ["Building"], 30];
    private _finalPos = _pos;
    if (count _nearBuildings > 0) then {
        private _bldg = _nearBuildings select 0;
        private _positions = [_bldg] call BIS_fnc_buildingPositions;
        if (count _positions > 0) then {
            _finalPos = selectRandom _positions;
        };
    };

    // Create a concealed box
    private _box = "B_supplyCrate_F" createVehicle _finalPos;
    _box setPos _finalPos;
    clearItemCargoGlobal _box;
    clearWeaponCargoGlobal _box;
    clearMagazineCargoGlobal _box;

    // Find matching loot table
    private _table = _lootTables select { (_x select 0) == _type };
    if (count _table > 0) then {
        _table = _table select 0;
        private _weapons   = _table select 1;
        private _magazines = _table select 2;
        { _box addWeaponCargoGlobal [_x, 1]; } forEach _weapons;
        { _box addMagazineCargoGlobal [_x, 1]; } forEach _magazines;
    };

    // Always add some useful items
    _box addItemCargoGlobal ["FirstAidKit", 1 + floor (random 2)];
    if (_type == "melee") then {
        _box addItemCargoGlobal ["ToolKit", 1]; // represents crowbar/improvised melee
    };

    // Mark as cache for interaction system
    _box setVariable ["CO_isWeaponCache", true, false];
    CO_weaponCaches pushBack _box;
} forEach _cacheDefs;
