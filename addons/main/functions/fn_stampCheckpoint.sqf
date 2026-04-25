// ============================================================
// fn_stampCheckpoint.sqf
// Places physical objects + NPC group at a road position.
// Returns a data struct for the checkpoint.
// ============================================================

params ["_pos", "_dir"];

private _objects = [];
private _perpDir = _dir + 90;

// --- Barrier layout (perpendicular to road) ---
private _barrier_L  = "Land_CncBarrierMedium4_F" createVehicle _pos;
_barrier_L setDir _perpDir;
_barrier_L setPos (_pos getPos [6,  _perpDir]);
_objects pushBack _barrier_L;

private _barrier_R  = "Land_CncBarrierMedium4_F" createVehicle _pos;
_barrier_R setDir _perpDir;
_barrier_R setPos (_pos getPos [6,  _perpDir + 180]);
_objects pushBack _barrier_R;

// Center gap barrier (S-bend forcing slow entry)
private _barrier_C  = "Land_CncBarrierMedium4_F" createVehicle _pos;
_barrier_C setDir _perpDir;
_barrier_C setPos (_pos getPos [2,  _perpDir + 45]);
_objects pushBack _barrier_C;

// Sandbag guard positions
private _bag_L = "Land_BagFence_Long_F" createVehicle _pos;
_bag_L setDir _dir;
_bag_L setPos (_pos getPos [5, _perpDir + 80]);
_objects pushBack _bag_L;

private _bag_R = "Land_BagFence_Long_F" createVehicle _pos;
_bag_R setDir _dir;
_bag_R setPos (_pos getPos [5, _perpDir + 280]);
_objects pushBack _bag_R;

// Small guard hut
private _hut = "Land_Mil_guardhouse" createVehicle _pos;
_hut setDir _dir;
_hut setPos (_pos getPos [8, _perpDir + 270]);
_objects pushBack _hut;

// Spotlight (night visibility)
private _light = "#lightpoint" createVehicle (_pos getPos [4, _perpDir]);
_light setLightBrightness 0.4;
_light setLightAmbient    [0.9, 0.85, 0.7];
_light setLightColor      [1,   0.95, 0.8];
_objects pushBack _light;

// --- NPC Group ---
private _grp = createGroup west;  // BLUFOR Enforcers
_grp setVariable ["CO_faction", "CRN_ENF"];

for "_i" from 0 to (CO_checkpoint_hostilesPerPost - 1) do {
    private _spawnOffset = [
        [4, _perpDir + 80],
        [4, _perpDir + 280],
        [8, _dir],
        [8, _dir + 180]
    ] select (_i min 3);

    private _uPos = _pos getPos _spawnOffset;
    private _u    = _grp createUnit [
        selectRandom ["B_Soldier_F","B_Soldier_AR_F","B_Soldier_TL_F"],
        _uPos, [], 1, "FORM"
    ];
    [_u] call co_main_fnc_initHostileUnit;
};

// Patrol within 20m of checkpoint only
{
    private _wp = _grp addWaypoint [_pos getPos [12, _dir + (_forEachIndex * 180)], 0];
    _wp setWaypointType "CYCLE";
    _wp setWaypointSpeed "LIMITED";
} forEach [0,1];

// Return data struct
[_pos, _dir, _objects, _grp]