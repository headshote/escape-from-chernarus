// ============================================================
// fn_buildWestBorderEnforcement.sqf
// Creates a dedicated western-border enforcement layer: forest camps,
// west-town guard pressure, and a hard checkpoint on the Komarovo road.
// ============================================================

// Dense camp lattice along the western forest. The strip runs roughly
// from Komarovo south up to the NW bend at Y~10500. We jitter the X to
// avoid a perfectly straight line through the forest.
private _campSites = [
    [[3050, 2350, 0], 270, "border_outpost"],
    [[3160, 2950, 0], 270, "border_tower"],
    [[2840, 3520, 0], 270, "border_outpost"],
    [[3260, 4180, 0], 270, "border_tower"],
    [[2980, 4820, 0], 270, "border_outpost"],
    [[3170, 5520, 0], 270, "border_tower"],
    [[2920, 6180, 0], 270, "border_outpost"],
    [[3060, 6840, 0], 270, "border_tower"],
    [[2820, 7480, 0], 270, "border_outpost"],
    [[3110, 8140, 0], 270, "border_tower"],
    [[2960, 8800, 0], 270, "border_outpost"],
    [[3210, 9440, 0], 270, "border_tower"],
    [[2880, 10080, 0], 270, "border_outpost"],
    [[3070, 10620, 0], 270, "border_tower"]
];

private _westTownZones = [
    ["Komarovo", [3600, 2300, 0], 240],
    ["Balota",   [4500, 2200, 0], 280],
    ["Pavlovo",  [4400, 5600, 0], 260],
    ["Myshkino", [3300, 6900, 0], 280],
    ["Lopatino", [3700, 9700, 0], 280]
];

private _registerResponseGroup = {
    params ["_grp", "_center", "_detectRadius", ["_mode", "west_enforcement"], ["_vehicleLethal", false]];

    if (isNull _grp) exitWith {};

    _grp setVariable ["CO_borderMode", _mode, false];
    _grp setVariable ["CO_borderHomePos", _center, false];
    _grp setVariable ["CO_borderChaseRadius", missionNamespace getVariable ["CO_westBorderChaseRadius", 180], false];
    _grp setVariable ["CO_borderFireRadius", missionNamespace getVariable ["CO_westBorderFireRadius", 85], false];
    _grp setVariable ["CO_borderVehicleLethal", _vehicleLethal, false];
    _grp setVariable ["CO_borderEngaging", false, false];

    [_grp, _center, _detectRadius] spawn {
        params ["_grp", "_center", "_detectRadius"];

        while { ({ alive _x } count units _grp) > 0 } do {
            sleep 2;

            if (_grp getVariable ["CO_borderEngaging", false]) then { continue };

            private _targets = (_center nearEntities [["Man"], _detectRadius]) select {
                alive _x &&
                !captive _x &&
                side _x == civilian &&
                !(_x getVariable ["CO_isFemale", false])
            };

            if (_targets isEqualTo []) then { continue };

            private _sortedTargets = [_targets, [], { _x distance2D _center }, "ASCEND"] call BIS_fnc_sortBy;
            private _target = _sortedTargets select 0;

            _grp setVariable ["CO_borderEngaging", true, false];

            [_grp, _target] spawn {
                params ["_grp", "_target"];
                [units _grp, _target] call co_main_fnc_borderAlert;
                _grp setVariable ["CO_borderEngaging", false, false];
            };
        };
    };
};

private _campCount = (missionNamespace getVariable ["CO_westBorderCampCount", count _campSites]) min (count _campSites);
private _campGuardMin = missionNamespace getVariable ["CO_westBorderCampGuardsMin", 2];
private _campGuardMax = missionNamespace getVariable ["CO_westBorderCampGuardsMax", 4];
private _townGuardCount = missionNamespace getVariable ["CO_westBorderTownGuardCount", 4];

for "_campIndex" from 0 to (_campCount - 1) do {
    private _camp = _campSites select _campIndex;
    private _campPos = +(_camp select 0);
    private _campDir = _camp select 1;
    private _template = _camp select 2;
    private _guardCount = _campGuardMin + floor (random ((_campGuardMax - _campGuardMin + 1) max 1));

    [_campPos, _campDir, _template] call co_main_fnc_stampFortification;

    private _staticGrp = [_campPos, _campDir, "CRN_ENF", _guardCount] call co_main_fnc_spawnFortGuards;
    [_staticGrp, _campPos, 220] call _registerResponseGroup;

    private _rovingGrp = [_campPos, 90, (_guardCount max 2), "CRN_ENF"] call co_main_fnc_spawnRovingGuards;
    [_rovingGrp, _campPos, 260] call _registerResponseGroup;

    // Yield every couple of camps so the west edge spawns smoothly.
    if (_campIndex % 2 == 1) then { sleep 0.25; };
};

// --- Roving foot patrols that walk between camps through the forest. ---
// They give the strip life beyond static encampments and chase any male civ
// they spot exactly like a camp would.
private _patrolCount = (missionNamespace getVariable ["CO_westBorderForestPatrols", 5]) max 0;
if (_patrolCount > 0 && count _campSites > 1) then {
    private _step = (count _campSites) / _patrolCount;
    for "_p" from 0 to (_patrolCount - 1) do {
        private _anchorIdx = (round (_p * _step)) min ((count _campSites) - 1);
        private _anchor = (_campSites select _anchorIdx) select 0;
        private _grp = [_anchor, 60, 3, "CRN_ENF"] call co_main_fnc_spawnRovingGuards;
        if !(isNull _grp) then {
            // Replace the small idle cycle with a long N-S patrol along the strip
            { deleteWaypoint _x } forEach +waypoints _grp;
            private _patrolSpan = 6;
            for "_w" from 0 to _patrolSpan do {
                private _idx = ((_anchorIdx - 2 + _w) max 0) min ((count _campSites) - 1);
                private _wpPos = (_campSites select _idx) select 0;
                _wpPos = _wpPos vectorAdd [random 60 - 30, random 60 - 30, 0];
                private _wp = _grp addWaypoint [_wpPos, 25];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                _wp setWaypointBehaviour "AWARE";
                _wp setWaypointCombatMode "YELLOW";
            };
            private _cycleWp = _grp addWaypoint [_anchor, 0];
            _cycleWp setWaypointType "CYCLE";
            [_grp, _anchor, 250, "forest_patrol"] call _registerResponseGroup;
            _grp setVariable ["CO_borderChaseRadius", 320, false];
            _grp setVariable ["CO_borderFireRadius", 110, false];
        };
    };
};

{
    private _townName = _x select 0;
    private _townCenter = _x select 1;
    private _townRadius = _x select 2;
    private _townGrp = [_townCenter, (_townRadius min 120), _townGuardCount, "CRN_ENF"] call co_main_fnc_spawnRovingGuards;

    [_townGrp, _townCenter, _townRadius] call _registerResponseGroup;
    diag_log format ["[CO] West border town enforcement active: %1", _townName];
} forEach _westTownZones;

private _checkpointPos = [2550, 2300, 0];
private _checkpointRoads = _checkpointPos nearRoads 60;
if !(_checkpointRoads isEqualTo []) then {
    _checkpointPos = getPosATL (_checkpointRoads select 0);
};

[_checkpointPos, 270, "checkpoint_heavy"] call co_main_fnc_stampFortification;
private _checkpointGrp = [
    _checkpointPos,
    270,
    "CRN_ENF",
    missionNamespace getVariable ["CO_westRoadCheckpointGuardCount", 6]
] call co_main_fnc_spawnFortGuards;

[_checkpointGrp, _checkpointPos, 190, "checkpoint", missionNamespace getVariable ["CO_westRoadCheckpointLethal", true]] call _registerResponseGroup;
_checkpointGrp setVariable ["CO_borderChaseRadius", 260, false];
_checkpointGrp setVariable ["CO_borderFireRadius", 35, false];

diag_log format [
    "[CO] West border enforcement built: %1 camps, %2 guarded towns, checkpoint online.",
    _campCount,
    count _westTownZones
];