// ============================================================
// fn_buildAirfieldCamp.sqf
// NW Airfield: Balota-equivalent in Chernarus NW corner.
// Wraps perimeter, stamps gates, spawns interior guards.
// ============================================================

CO_airfieldCenter  = [2100, 12800, 0];  // NW Airfield center
CO_airfieldRadius  = 350;               // approx camp perimeter radius
CO_airfieldGates   = [                  // road entry angles
    [180, "Road from Vybor south"],     // south road
    [90,  "Road from east"]
];

// --- Perimeter walls (8-point polygon around airfield) ---
private _perimeterAngles = [0, 45, 90, 135, 180, 225, 270, 315];
{
    private _angle    = _x;
    private _pos      = CO_airfieldCenter getPos [CO_airfieldRadius, _angle];
    private _facing   = _angle + 90; // walls face outward tangentially
    [_pos, _facing, "airfield_perimeter"] call co_main_fnc_stampFortification;
} forEach _perimeterAngles;

// --- Gates at road entry points ---
{
    private _gateDir = _x select 0;
    private _gatePos = CO_airfieldCenter getPos [CO_airfieldRadius, _gateDir];
    [_gatePos, _gateDir + 180, "airfield_gate"] call co_main_fnc_stampFortification;
    // Gate guards
    [_gatePos, _gateDir + 180, "CRN_ENF"] call co_main_fnc_spawnFortGuards;
} forEach CO_airfieldGates;

// --- Interior guard towers (4 corners of airfield interior) ---
{
    private _pos = CO_airfieldCenter getPos [CO_airfieldRadius * 0.7, _x];
    ["Land_WatchTower_F", 0, 0, _x + 180] params ["_cls","_f","_s","_d"]; // inline override
    private _tower = "Land_WatchTower_F" createVehicle _pos;
    _tower setDir _x;
    // Guard on each tower
    private _tGrp = createGroup west;
    _tGrp setVariable ["CO_faction", "CRN_ENF"];
    private _guard = _tGrp createUnit ["B_Soldier_F", _pos vectorAdd [0,0,6], [], 1, "FORM"];
    _guard setPos (_pos vectorAdd [0, 0, 6]); // top of tower approx
} forEach [0, 90, 180, 270];

// --- Roving interior guards ---
[CO_airfieldCenter, 200, missionNamespace getVariable ["CO_airfield_guardCount", 14], "CRN_ENF"] call co_main_fnc_spawnRovingGuards;