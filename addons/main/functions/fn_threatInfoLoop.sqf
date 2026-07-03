// ============================================================
// fn_threatInfoLoop.sqf — per-player threat proximity broadcast
// (server-side)
//
// Feeds the situational HUD: TCK capture pressure does NOT depend
// on wanted level (they snatch anyone), so the player needs to
// know "are they around / am I targeted" rather than a star count.
//
// Every 4 s, classify all POLICE and CRN_ENF groups once, then
// broadcast per player:
//   CO_threatNear = [nearestPoliceDist, nearestOccupationDist]
// (rounded metres; 99999 when none). Occupation = CRN_ENF, which
// covers TCK trucks, checkpoints, AND border forces — one hostile
// apparatus, one tile.
//
// Cost: one allGroups pass + (#players × #groups) distance checks
// per tick — trivial at a 4 s cadence.
// ============================================================
if (!isServer) exitWith {};
if (missionNamespace getVariable ["CO_threatInfoRunning", false]) exitWith {};
CO_threatInfoRunning = true;

[] spawn {
    while { true } do {
        sleep 4;
        if (allPlayers isEqualTo []) then { continue };

        private _policePos = [];
        private _enfPos = [];
        {
            private _fac = _x getVariable ["CO_faction", ""];
            if (_fac in ["POLICE", "CRN_ENF"]) then {
                private _lead = leader _x;
                if (!isNull _lead && alive _lead) then {
                    if (_fac == "POLICE") then {
                        _policePos pushBack (getPosATL _lead);
                    } else {
                        _enfPos pushBack (getPosATL _lead);
                    };
                };
            };
        } forEach allGroups;

        {
            private _p = _x;
            if (alive _p) then {
                private _pPos = getPosATL _p;
                private _pMin = 99999;
                { private _d = _pPos distance2D _x; if (_d < _pMin) then { _pMin = _d } } forEach _policePos;
                private _eMin = 99999;
                { private _d = _pPos distance2D _x; if (_d < _eMin) then { _eMin = _d } } forEach _enfPos;
                _p setVariable ["CO_threatNear", [round _pMin, round _eMin], true];
            };
        } forEach allPlayers;
    };
};
