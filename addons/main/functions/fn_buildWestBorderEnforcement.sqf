// ============================================================
// fn_buildWestBorderEnforcement.sqf
// Creates a dedicated western-border enforcement layer: forest camps,
// west-town guard pressure, and a hard checkpoint on the Komarovo road.
// ============================================================

private _campSites = [
    [[3050, 2550, 0], 270, "border_outpost"],
    [[3160, 3420, 0], 270, "border_tower"],
    [[3260, 4580, 0], 270, "border_outpost"],
    [[3020, 5900, 0], 270, "border_tower"],
    [[2920, 7250, 0], 270, "border_outpost"],
    [[3070, 8720, 0], 270, "border_tower"],
    [[3210, 10120, 0], 270, "border_outpost"]
];

private _westTownZones = [
    ["Komarovo", [3600, 2300, 0], 220],
    ["Balota",   [4500, 2200, 0], 260],
    ["Pavlovo",  [4400, 5600, 0], 240],
    ["Myshkino", [1900, 6900, 0], 260],
    ["Lopatino", [2800,10200, 0], 280]
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
    [_staticGrp, _campPos, 130] call _registerResponseGroup;

    private _rovingGrp = [_campPos, 90, (_guardCount max 2), "CRN_ENF"] call co_main_fnc_spawnRovingGuards;
    [_rovingGrp, _campPos, 160] call _registerResponseGroup;
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