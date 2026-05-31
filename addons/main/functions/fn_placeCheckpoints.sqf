// ============================================================
// fn_placeCheckpoints.sqf
// Uses CO_roadGraph to stamp checkpoints procedurally.
// Respects admin settings for small-settlement inclusion.
// ============================================================

params [
    ["_includeLarge",  true],
    ["_includeMedium", true],
    ["_includeSmall",  false]   // off by default; toggled in admin panel
];

// Override with admin settings if available
if (!isNil "CO_checkpoint_includeLarge") then { _includeLarge = CO_checkpoint_includeLarge; };
if (!isNil "CO_checkpoint_includeMedium") then { _includeMedium = CO_checkpoint_includeMedium; };
if (!isNil "CO_checkpoint_includeSmall") then { _includeSmall = CO_checkpoint_includeSmall; };
private _fortTemplate = missionNamespace getVariable ["CO_checkpoint_fortTemplate", ""];

CO_activeCheckpoints = []; // store refs for later cleanup/toggle

{
    private _aType = _x select 3;
    private _bType = _x select 4;
    private _mid   = _x select 2;

    // Gate by settlement type of both endpoints
    private _allow = false;
    if (_includeLarge  && (_aType == "large"  || _bType == "large"))  then { _allow = true };
    if (_includeMedium && (_aType == "medium" || _bType == "medium")) then { _allow = true };
    if (_includeSmall  && (_aType == "small"  && _bType == "small"))  then { _allow = true };

    if (_allow) then {
        // Snap to nearest road at midpoint
        private _nearRoads = _mid nearRoads 40;
        if (count _nearRoads == 0) then { continue };
        private _snapRoad   = _nearRoads select 0;
        private _snapPos    = getPos _snapRoad;
        private _roadDir    = [_snapPos, _mid] call BIS_fnc_dirTo;

        private _cpData = [_snapPos, _roadDir] call co_main_fnc_stampCheckpoint;
        if (_fortTemplate != "") then {
            private _fortObjects = [_snapPos, _roadDir, _fortTemplate] call co_main_fnc_stampFortification;
            private _objects = _cpData select 2;
            _objects append _fortObjects;
            _cpData set [2, _objects];
        };
        CO_activeCheckpoints pushBack _cpData;
    };
} forEach CO_roadGraph;

diag_log format ["[CO] %1 checkpoints placed.", count CO_activeCheckpoints];