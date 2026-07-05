// ============================================================
// fn_isFrontSafeZone.sqf
//
// Returns [inside, zoneName, distance] for Krasnostav/frontline areas where
// deployed conscripts are allowed to operate without being considered AWOL.
// Accepts either a unit/object or a position array as the first argument.
// ============================================================
params [
    ["_target", objNull],
    ["_fallbackCenter", [11200, 12300, 0]]
];

private _pos = if (_target isEqualType objNull) then {
    if (isNull _target) then {
        _fallbackCenter
    } else {
        getPosATL _target
    }
} else {
    _target
};

private _baseRadius = (missionNamespace getVariable ["CO_awolRadius", 1200]) max 1800;
private _zones = missionNamespace getVariable ["CO_frontSafeZones", [
    [[11200, 12300, 0], _baseRadius, "Krasnostav town/outskirts"],
    [[12050, 12650, 0], 1400, "Krasnostav airfield"],
    [[11200, 13600, 0], 1500, "north forest staging area"],
    [[12150, 12300, 0], 1200, "forward defense line"]
]];

private _inside = false;
private _zoneName = "";
private _bestDistance = 1e9;

{
    if (_x isEqualType [] && { count _x >= 2 }) then {
        private _center = _x select 0;
        private _radius = _x select 1;
        private _name = _x param [2, "front zone"];
        private _distance = _pos distance2D _center;
        _bestDistance = _bestDistance min _distance;
        if (!_inside && { _distance <= _radius }) then {
            _inside = true;
            _zoneName = _name;
        };
    };
} forEach _zones;

// If the procedural front line is available, any actual CRN_FRONT node is
// also valid duty ground. This keeps the monitor correct if the player moves
// along the active line rather than only around Krasnostav.
if (!_inside && { !isNil "CO_frontDefensePositions" }) then {
    {
        private _distance = _pos distance2D _x;
        _bestDistance = _bestDistance min _distance;
        if (!_inside && { _distance <= 900 }) then {
            _inside = true;
            _zoneName = "active front line";
        };
    } forEach CO_frontDefensePositions;
};

[_inside, _zoneName, _bestDistance]
