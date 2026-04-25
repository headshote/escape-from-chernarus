// ============================================================
// fn_buildRoadGraph.sqf
// Builds a connectivity list between all defined settlements.
// Run ONCE on server at init, result cached in CO_roadGraph.
// ============================================================

CO_settlements = [
    // [name, pos, type]   type: "large" | "medium" | "small"
    ["Chernogorsk",    [6400,  2400,  0], "large"],
    ["Elektrozavodsk", [10200, 2300,  0], "large"],
    ["Berezino",       [11600, 7800,  0], "large"],
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
    ["Tulga",          [9700,  9800,  0], "small"],
    ["Polana",         [9500,  8700,  0], "small"],
    ["Mogilevka",      [8500,  8100,  0], "small"],
];

// Build pairs: for every settlement, connect to those within 3800m
CO_roadGraph = [];
{
    private _a = _x;
    {
        private _b = _x;
        if ((_a select 0) == (_b select 0)) then { continue };
        private _aPosATL = _a select 1;
        private _bPosATL = _b select 1;
        private _dist = _aPosATL distance _bPosATL;
        if (_dist < 3800 && _dist > 400) then {
            // Check a road exists between them (sample midpoint)
            private _mid = _aPosATL vectorMultiply 0.5 vectorAdd (_bPosATL vectorMultiply 0.5);
            private _road = roadAt _mid;
            if (!isNull _road) then {
                CO_roadGraph pushBackUnique [[_a select 0, _b select 0, _mid, _a select 2, _b select 2]];
            };
        };
    } forEach CO_settlements;
} forEach CO_settlements;