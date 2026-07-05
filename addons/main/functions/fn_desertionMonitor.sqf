// fn_desertionMonitor.sqf - server loop, runs every 10 seconds.
// Adds pressure only when a CRN_FRONT player is truly behind the moving war
// line. The Krasnostav/front safe zone is explicitly exempt so walking around
// the town, airfield, northern woods, or nearby front nodes never creates a
// false deserter flag.
if (!isServer) exitWith {};

while { true } do {
    sleep 10;
    {
        private _p = _x;
        if (_p getVariable ["CO_faction", ""] != "CRN_FRONT") then { continue };
        if (!(_p getVariable ["CO_isCleared", false])) then { continue };
        if (_p getVariable ["CO_isAWOL", false]) then { continue };

        private _frontState = [_p] call co_main_fnc_isFrontSafeZone;
        if (_frontState select 0) then { continue };

        private _advanceFront = missionNamespace getVariable ["CO_rus_advanceFront", 13000];
        if (((getPosATL _p) select 0) < (_advanceFront - 2000)) then {
            private _wantedAlready = _p getVariable ["CO_deserterWanted", false];
            if (!_wantedAlready) then {
                _p setVariable ["CO_deserterWanted", true, true];
                _p setVariable ["CO_wantedLevel", 80, true];
                [getPos _p] call co_main_fnc_alertEnforcers;
                diag_log format [
                    "[CO] Desertion monitor: %1 marked wanted behind front at %2.",
                    name _p,
                    mapGridPosition _p
                ];
            };
        };
    } forEach allPlayers;
};
