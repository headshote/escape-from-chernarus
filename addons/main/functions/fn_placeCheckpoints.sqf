// ============================================================
// fn_placeCheckpoints.sqf
// Scores road-graph candidates by off-road resistance and stamps
// the highest-value choke points rather than every midpoint.
// ============================================================

params [
    ["_includeLarge",  true],
    ["_includeMedium", true],
    ["_includeSmall",  false]
];

if (!isNil "CO_checkpoint_includeLarge") then { _includeLarge = CO_checkpoint_includeLarge };
if (!isNil "CO_checkpoint_includeMedium") then { _includeMedium = CO_checkpoint_includeMedium };
if (!isNil "CO_checkpoint_includeSmall") then { _includeSmall = CO_checkpoint_includeSmall };

private _fortTemplate = missionNamespace getVariable ["CO_checkpoint_fortTemplate", ""];
private _maxCount = missionNamespace getVariable ["CO_checkpoint_maxCount", 20];

CO_activeCheckpoints = [];
CO_checkpointScores = [];

private _scoreSite = {
    params ["_pos", "_dir"];
    private _score = 0;
    private _perp = _dir + 90;

    {
        private _sideDir = _perp + _x;
        {
            private _sample = _pos getPos [_x, _sideDir];
            private _trees = count (nearestTerrainObjects [_sample, ["TREE","SMALL TREE","BUSH"], 35, false]);
            private _water = if (surfaceIsWater _sample) then { 80 } else { 0 };
            private _h1 = getTerrainHeightASL _sample;
            private _h2 = getTerrainHeightASL (_sample getPos [25, _sideDir]);
            private _slope = abs (_h2 - _h1) * 5;
            _score = _score + (_trees min 45) + _water + (_slope min 35);
        } forEach [40, 60, 80];
    } forEach [0, 180];

    private _nearHouses = count (_pos nearObjects ["House", 90]);
    _score = _score + (_nearHouses min 20);
    _score
};

private _candidates = [];
{
    private _aType = _x select 3;
    private _bType = _x select 4;
    private _mid = _x select 2;

    private _allow = false;
    if (_includeLarge && (_aType == "large" || _bType == "large")) then { _allow = true };
    if (_includeMedium && (_aType == "medium" || _bType == "medium")) then { _allow = true };
    if (_includeSmall && (_aType == "small" && _bType == "small")) then { _allow = true };
    if (!_allow) then { continue };

    private _nearRoads = _mid nearRoads 70;
    if (_nearRoads isEqualTo []) then { continue };
    private _road = _nearRoads select 0;
    private _snapPos = getPosATL _road;
    private _connected = roadsConnectedTo _road;
    private _roadDir = if !(_connected isEqualTo []) then {
        [_snapPos, getPosATL (_connected select 0)] call BIS_fnc_dirTo
    } else {
        [_snapPos, _mid] call BIS_fnc_dirTo
    };
    private _score = [_snapPos, _roadDir] call _scoreSite;
    _candidates pushBack [_score, _snapPos, _roadDir, _x];
} forEach CO_roadGraph;

_candidates = [_candidates, [], { -(_x select 0) }, "ASCEND"] call BIS_fnc_sortBy;
private _selected = _candidates select [0, (_maxCount min count _candidates)];

{
    _x params ["_score", "_snapPos", "_roadDir", "_graphEntry"];
    private _cpData = [_snapPos, _roadDir] call co_main_fnc_stampCheckpoint;
    if (_fortTemplate != "") then {
        private _fortObjects = [_snapPos, _roadDir, _fortTemplate] call co_main_fnc_stampFortification;
        private _objects = _cpData select 2;
        _objects append _fortObjects;
        _cpData set [2, _objects];
    };
    CO_activeCheckpoints pushBack _cpData;
    CO_checkpointScores pushBack [_score, _snapPos, _graphEntry];
    sleep 0.05;
} forEach _selected;

publicVariable "CO_activeCheckpoints";
diag_log format ["[CO] %1 scored choke-point checkpoints placed from %2 candidates.", count CO_activeCheckpoints, count _candidates];
