// ============================================================
// fn_buildRoadGraph.sqf
// Builds a connectivity list between all defined settlements.
// Run ONCE on server at init, result cached in CO_roadGraph.
// ============================================================

CO_settlements = [
    // [name, pos, type]   type: "large" | "medium" | "small"
    ["Chernogorsk",    [6400,  2400,  0], "large"],
    ["Elektrozavodsk", [10200, 2300,  0], "large"],
    ["Berezino",       [12300, 9700,  0], "large"],
    ["Balota",         [4500,  2200,  0], "medium"],
    ["Komarovo",       [3600,  2300,  0], "small"],
    ["Kamyshovo",      [11100, 2700,  0], "small"],
    ["Solnichniy",     [12200, 5600,  0], "small"],
    ["Staroye",        [9000,  6100,  0], "small"],
    ["Stary Sobor",    [7300,  7900,  0], "medium"],
    ["Novy Sobor",     [7600,  9200,  0], "small"],
    ["Kabanino",       [6000,  9100,  0], "small"],
    ["Vybor",          [5100,  10100, 0], "small"],
    ["Zelenogorsk",    [3900,  7200,  0], "medium"],
    ["Pavlovo",        [4400,  5600,  0], "small"],
    ["Myshkino",       [3300,  6900,  0], "small"],
    ["Lopatino",       [3700,  9700,  0], "small"],
    ["Tulga",          [9700,  9800,  0], "small"],
    ["Polana",         [9500,  8700,  0], "small"],
    ["Mogilevka",      [8500,  8100,  0], "small"]
];

// Build unique road-linked pairs between nearby settlements.
CO_roadGraph = [];
for "_aIndex" from 0 to ((count CO_settlements) - 2) do {
    private _a = CO_settlements select _aIndex;
    private _aPosATL = _a select 1;

    for "_bIndex" from (_aIndex + 1) to ((count CO_settlements) - 1) do {
        private _b = CO_settlements select _bIndex;
        private _bPosATL = _b select 1;
        private _dist = _aPosATL distance _bPosATL;

        if (_dist <= 400 || _dist >= 4500) then { continue };

        private _mid = [
            ((_aPosATL select 0) + (_bPosATL select 0)) * 0.5,
            ((_aPosATL select 1) + (_bPosATL select 1)) * 0.5,
            0
        ];
        private _midRoads = _mid nearRoads 250;
        if (_midRoads isEqualTo []) then { continue };

        private _roadPos = getPosATL (_midRoads select 0);
        CO_roadGraph pushBack [_a select 0, _b select 0, _roadPos, _a select 2, _b select 2];
    };
};

diag_log format ["[CO] Road graph built with %1 links across %2 settlements.", count CO_roadGraph, count CO_settlements];