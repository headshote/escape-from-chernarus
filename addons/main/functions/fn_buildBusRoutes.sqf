// ============================================================
// fn_buildBusRoutes.sqf
// Procedurally creates bus patrol routes between settlements.
// Large towns always get intra-town routes too.
// ============================================================

CO_busRoutes = []; // populated below, used by bus spawner

// Step 1: Build routes FROM road graph
{
    private _aName  = _x select 0;
    private _bName  = _x select 1;
    private _midPos = _x select 2;
    private _aType  = _x select 3;
    private _bType  = _x select 4;

    private _aPos = (CO_settlements select { (_x select 0) == _aName } select 0) select 1;
    private _bPos = (CO_settlements select { (_x select 0) == _bName } select 0) select 1;

    // Route: a → midpoint → b → midpoint → a (loop)
    private _routeWps = [_aPos, _midPos, _bPos, _midPos];

    // Classify route importance
    private _priority = 1;
    if (_aType == "large" || _bType == "large")  then { _priority = 3 };
    if (_aType == "medium"|| _bType == "medium") then { _priority = 2 };

    CO_busRoutes pushBack [_routeWps, _priority, _aName + "–" + _bName];
} forEach CO_roadGraph;

// Step 2: Add intra-town loops for large settlements
{
    if ((_x select 2) == "large") then {
        private _center = _x select 1;
        private _loopWps = [
            _center getPos [120, 0],
            _center getPos [120, 90],
            _center getPos [120, 180],
            _center getPos [120, 270],
        ];
        // Snap each to nearest road
        _loopWps = _loopWps apply {
            private _road = _x nearRoads 30;
            if (count _road > 0) then { getPos (_road select 0) } else { _x }
        };
        CO_busRoutes pushBack [_loopWps, 4, (_x select 0) + " intra-town"];
    };
} forEach CO_settlements;