// ============================================================
// fn_dispatchRoadblock.sqf
// Creates a temporary roadblock/spike strip ahead of a fleeing target.
// params: [_target, _sourcePos, _faction, _aheadDistance, _duration]
// ============================================================
params [
    ["_target", objNull],
    ["_sourcePos", [0,0,0]],
    ["_faction", "POLICE"],
    ["_aheadDistance", 450],
    ["_duration", 180]
];

if (!isServer || isNull _target) exitWith { [] };

private _targetVeh = vehicle _target;
private _pos = getPosATL _targetVeh;
private _vel = velocity _targetVeh;
_vel set [2, 0];
private _dir = if ((vectorMagnitude _vel) > 1) then {
    (_vel select 0) atan2 (_vel select 1)
} else {
    getDir _targetVeh
};

private _ahead = _pos getPos [_aheadDistance, _dir];
private _roads = _ahead nearRoads 300;
if (_roads isEqualTo []) exitWith { [] };

private _road = _roads select 0;
private _rbPos = getPosATL _road;
private _connected = roadsConnectedTo _road;
private _roadDir = if !(_connected isEqualTo []) then {
    [_rbPos, getPosATL (_connected select 0)] call BIS_fnc_dirTo
} else {
    _dir
};

private _objects = [];
private _spike = "Land_Razorwire_F" createVehicle _rbPos;
_spike setDir (_roadDir + 90);
_spike setPosATL _rbPos;
_spike setVariable ["CO_isSpikeStrip", true, true];
_objects pushBack _spike;

private _barrier = "Land_CncBarrierMedium4_F" createVehicle (_rbPos getPos [7, _roadDir + 90]);
_barrier setDir (_roadDir + 90);
_objects pushBack _barrier;

private _grp = createGroup west;
_grp setVariable ["CO_faction", _faction, true];
private _car = "C_Offroad_01_F" createVehicle (_rbPos getPos [16, _roadDir + 180]);
_car setDir _roadDir;
_objects pushBack _car;

for "_i" from 0 to 1 do {
    private _u = _grp createUnit ["B_Soldier_F", _rbPos getPos [8 + random 4, _roadDir + 80 + (_i * 180)], [], 0, "FORM"];
    [_u] call co_main_fnc_initHostileUnit;
};

CO_activeRoadblocks = missionNamespace getVariable ["CO_activeRoadblocks", []];
CO_activeRoadblocks pushBack [_rbPos, time + _duration, _objects, _grp];
missionNamespace setVariable ["CO_activeRoadblocks", CO_activeRoadblocks, true];

[_spike, _duration] spawn {
    params ["_spike", "_duration"];
    private _end = time + _duration;
    private _wheels = ["HitLFWheel","HitRFWheel","HitLF2Wheel","HitRF2Wheel","HitLMWheel","HitRMWheel","HitLBWheel","HitRBWheel"];
    while { alive _spike && time < _end } do {
        sleep 0.25;
        private _vehicles = (getPosATL _spike) nearEntities [["LandVehicle"], 7];
        {
            private _veh = _x;
            if (alive _veh && abs (speed _veh) > 8 && !(_veh getVariable ["CO_spiked", false])) then {
                _veh setVariable ["CO_spiked", true, true];
                { _veh setHitPointDamage [_x, 1] } forEach _wheels;
                diag_log format ["[CO] Roadblock spiked vehicle %1 at %2.", typeOf _veh, mapGridPosition _veh];
            };
        } forEach _vehicles;
    };
};

[_objects, _grp, _duration] spawn {
    params ["_objects", "_grp", "_duration"];
    sleep _duration;
    { if (!isNull _x) then { deleteVehicle _x } } forEach _objects;
    { if (alive _x) then { deleteVehicle _x } } forEach units _grp;
    deleteGroup _grp;
};

["roadblock_dispatched"] call co_main_fnc_kpi;
[_rbPos, _grp, _objects]
