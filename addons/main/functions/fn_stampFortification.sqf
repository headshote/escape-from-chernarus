// ============================================================
// fn_stampFortification.sqf
// General fortification placement engine.
// _template: "trench_line" | "bunker_pair" | "watchtower_post"
//            "airfield_gate" | "border_outpost" | "border_tower"
//            "eastern_front_defense" | "eastern_trench_line"
// Returns list of created objects.
// ============================================================

params ["_pos", "_dir", "_template"];
private _objects = [];

// Helper: create object at offset from _pos
private _fnc_obj = {
    params ["_class", "_fwdDist", "_sideOffset", "_objDir"];
    private _p = _pos getPos [_fwdDist, _dir];
    _p = _p getPos [abs _sideOffset, _dir + (if (_sideOffset >= 0) then {90} else {270})];
    private _o = _class createVehicle _p;
    _o setDir (_dir + _objDir);
    _o setPos _p; // force exact pos after createVehicle randomization
    _objects pushBack _o;
    _o
};

switch (_template) do {

    // ── Checkpoint enhancement: two HESCOs + razorwire ──────────────
    case "checkpoint_light": {
        ["Land_HBarrier_Big_F",       4,  8,  90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       4, -8,  90] call _fnc_obj;
        ["Land_Razorwire_F",          0,  5,   0] call _fnc_obj;
        ["Land_Razorwire_F",          0, -5,   0] call _fnc_obj;
    };

    // ── Checkpoint heavy: full blockade ─────────────────────────────
    case "checkpoint_heavy": {
        ["Land_HBarrier_Big_F",       4,  10, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       4,   0, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       4, -10, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",      -4,  10, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",      -4, -10, 90] call _fnc_obj;
        ["Land_BagFence_Long_F",      6,   6,  0] call _fnc_obj;
        ["Land_BagFence_Long_F",      6,  -6,  0] call _fnc_obj;
        ["Land_Razorwire_F",          8,   8,  0] call _fnc_obj;
        ["Land_Razorwire_F",          8,  -8,  0] call _fnc_obj;
        ["Land_Fortified_nest_big_F", 8,   9,  0] call _fnc_obj;
        ["Land_Fortified_nest_big_F", 8,  -9,  0] call _fnc_obj;
        ["Land_WatchTower_F",        12,  11,  0] call _fnc_obj;
    };

    // ── Border outpost: single tower + razorwire line ────────────────
    case "border_outpost": {
        ["Land_WatchTower_F",         0,   0,  0] call _fnc_obj;
        ["Land_Razorwire_F",          0,  10,  0] call _fnc_obj;
        ["Land_Razorwire_F",          0,  20,  0] call _fnc_obj;
        ["Land_Razorwire_F",          0,  -10, 0] call _fnc_obj;
        ["Land_Razorwire_F",          0,  -20, 0] call _fnc_obj;
        ["Land_BagFence_Long_F",      4,   5,  0] call _fnc_obj;
        ["Land_BagFence_Long_F",      4,  -5,  0] call _fnc_obj;
        ["Land_Fortified_nest_big_F", 6,   0,  0] call _fnc_obj;
    };

    // ── Border tower: elevated observation only ───────────────────────
    case "border_tower": {
        ["Land_WatchTower_F",         0,   0,  0] call _fnc_obj;
        ["Land_BagFence_Long_F",      5,   6, 90] call _fnc_obj;
        ["Land_BagFence_Long_F",      5,  -6, 90] call _fnc_obj;
        ["Land_Razorwire_F",          8,   0,  0] call _fnc_obj;
    };

    // ── Airfield gate: heavy guarded entry ───────────────────────────
    case "airfield_gate": {
        ["Land_HBarrier_Big_F",       0,  16, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       0,   8, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       0,  -8, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       0, -16, 90] call _fnc_obj;
        // S-bend obstruction
        ["Land_CncBarrierMedium4_F",  4,   4, 45] call _fnc_obj;
        ["Land_CncBarrierMedium4_F",  8,  -4, 45] call _fnc_obj;
        ["Land_Fortified_nest_big_F",10,  10,  0] call _fnc_obj;
        ["Land_Fortified_nest_big_F",10, -10,  0] call _fnc_obj;
        ["Land_WatchTower_F",        14,  14,  0] call _fnc_obj;
        ["Land_WatchTower_F",        14, -14,  0] call _fnc_obj;
        ["Land_BagFence_Long_F",      6,   7, 90] call _fnc_obj;
        ["Land_BagFence_Long_F",      6,  -7, 90] call _fnc_obj;
        ["Land_Razorwire_F",         12,   8,  0] call _fnc_obj;
        ["Land_Razorwire_F",         12,  -8,  0] call _fnc_obj;
    };

    // ── Airfield perimeter section ────────────────────────────────────
    case "airfield_perimeter": {
        ["Land_HBarrier_Big_F",       0,   0, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       0,   6, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       0,  12, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       0,  -6, 90] call _fnc_obj;
        ["Land_HBarrier_Big_F",       0, -12, 90] call _fnc_obj;
        ["Land_Razorwire_F",          5,   0,  0] call _fnc_obj;
    };

    // ── Eastern front: forward trench with MG nest ───────────────────
    case "eastern_front_defense": {
        ["Land_BagFence_Long_F",      0,  12,  0] call _fnc_obj;
        ["Land_BagFence_Long_F",      0,   6,  0] call _fnc_obj;
        ["Land_BagFence_Long_F",      0,   0,  0] call _fnc_obj;
        ["Land_BagFence_Long_F",      0,  -6,  0] call _fnc_obj;
        ["Land_BagFence_Long_F",      0, -12,  0] call _fnc_obj;
        ["Land_Fortified_nest_big_F", -4,  6,  0] call _fnc_obj;
        ["Land_Fortified_nest_big_F", -4, -6,  0] call _fnc_obj;
        ["Land_Razorwire_F",           6, 10,  0] call _fnc_obj;
        ["Land_Razorwire_F",           6,  0,  0] call _fnc_obj;
        ["Land_Razorwire_F",           6,-10,  0] call _fnc_obj;
        // Static MG
        private _mg = "B_HMG_01_high_F" createVehicle (_pos getPos [6, _dir + 180]);
        _mg setDir _dir;
        _objects pushBack _mg;
    };

    // ── Eastern trench line: long horizontal wall facing east ─────────
    case "eastern_trench_line": {
        for "_s" from -4 to 4 do {
            ["Land_BagFence_Long_F", 0, _s * 8, 0] call _fnc_obj;
        };
        // MG nests every 24m
        [-6,  12, 0] call _fnc_obj; // placeholder, use nest below
        private _nest1 = "Land_Fortified_nest_big_F" createVehicle (_pos getPos [6, _dir + 180]);
        _nest1 setDir _dir; _objects pushBack _nest1;
        private _nest2 = "Land_Fortified_nest_big_F" createVehicle (_pos getPos [6, _dir + 180] getPos [24, _dir + 90]);
        _nest2 setDir _dir; _objects pushBack _nest2;
    };
};

_objects // return all created objects