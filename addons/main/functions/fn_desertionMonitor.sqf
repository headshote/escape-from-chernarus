// fn_desertionMonitor.sqf — server loop, runs every 10 seconds
while { true } do {
    sleep 10;
    {
        private _p = _x;
        if (_p getVariable ["CO_faction", ""] != "CRN_FRONT") then { continue };

        if (getPosATL _p select 0 < CO_rus_advanceFront - 2000) then {
            // Player is significantly behind lines — potential deserter
            private _wantedAlready = _p getVariable ["CO_deserterWanted", false];
            if (!_wantedAlready) then {
                _p setVariable ["CO_deserterWanted", true, true];
                _p setVariable ["CO_wantedLevel", 80, true]; // high wanted level
                // Alert nearest Enforcer group
                [getPos _p] call co_main_fnc_alertEnforcers;
            };
        };
    } forEach allPlayers;
};