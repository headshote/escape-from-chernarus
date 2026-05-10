// ============================================================
// fn_buildEasternFront.sqf
// Procedurally stamps a defense line across the eastern map.
// Density and depth controlled by admin panel.
// ============================================================

params [
    ["_frontX",        13500],   // X coordinate of front line
    ["_lineSpacingY",  missionNamespace getVariable ["CO_front_lineSpacingY", 200]],   // meters between defense nodes N-S
    ["_depthRows",     missionNamespace getVariable ["CO_front_depthRows", 2]],         // how many rows deep (1 = thin, 3 = fortified)
    ["_rowSpacingX",   missionNamespace getVariable ["CO_front_rowSpacing", 50]]        // meters between rows west
];

private _yMin = 1500;
private _yMax = 11500;
private _nodes = floor ((_yMax - _yMin) / _lineSpacingY);
private _spawned = 0;

for "_row" from 0 to (_depthRows - 1) do {
    private _rowX = _frontX - (_row * _rowSpacingX);

    for "_n" from 0 to _nodes do {
        private _y   = _yMin + (_n * _lineSpacingY) + (random 40 - 20); // slight randomization
        private _pos = [_rowX + (random 20 - 10), _y, 0];
        private _dir = 90; // face east

        // First row: full defense nests
        // Back rows: lighter trench lines
        private _template = if (_row == 0) then {"eastern_front_defense"} else {"eastern_trench_line"};
        [_pos, _dir, _template] call co_main_fnc_stampFortification;

        // Spawn CRN_FRONT unit group at each node
        [_pos, _dir, "CRN_FRONT"] call co_main_fnc_spawnFortGuards;

        _spawned = _spawned + 1;
        // Yield every few nodes so the server can process other init work and
        // avoid a multi-second hitch from spawning the entire front in one frame.
        if (_spawned % 4 == 0) then { sleep 0.25; };
    };
};

diag_log format ["[CO] Eastern front built: %1 nodes across %2 rows.", _spawned, _depthRows];