// ============================================================
// fn_borderZone.sqf
// Layered western border: outer forest patrols, sensor/tripflare
// line, tracker teams, night helicopter, and ambient dread.
// ============================================================
if (!isServer) exitWith {};
if (missionNamespace getVariable ["CO_borderZoneRunning", false]) exitWith {};
missionNamespace setVariable ["CO_borderZoneRunning", true, true];

private _anchors = [];
for "_y" from 2200 to 10800 step 650 do {
    _anchors pushBack [3300 + random 350 - 175, _y + random 180 - 90, 0];
};

// Outer belt patrols through the forest, not on the literal map edge.
{
    private _grp = [_x, 120, 3, "CRN_ENF"] call co_main_fnc_spawnRovingGuards;
    if (!isNull _grp) then {
        _grp setVariable ["CO_borderMode", "forest_patrol", false];
        _grp setVariable ["CO_borderChaseRadius", 420, false];
        _grp setVariable ["CO_borderFireRadius", 140, false];
    };
    sleep 0.1;
} forEach _anchors;

// Sensor line with random gaps.
CO_borderSensors = [];
for "_y" from 2050 to 11000 step (170 + random 80) do {
    if ((random 1) > 0.18) then {
        private _pos = [3820 + random 140 - 70, _y + random 80 - 40, 0];
        private _wire = "Land_Razorwire_F" createVehicle _pos;
        _wire setDir (80 + random 20);
        _wire setVariable ["CO_borderSensor", true, true];
        CO_borderSensors pushBack [_pos, _wire, true];
    };
};
publicVariable "CO_borderSensors";

// Sensor, breadcrumb, tracker and helicopter loop.
[] spawn {
    private _lastAmbient = 0;

    private _spawnTracker = {
        params ["_target", "_trail"];
        if (_target getVariable ["CO_borderTrackerActive", false]) exitWith {};
        _target setVariable ["CO_borderTrackerActive", true, true];

        private _start = if (_trail isEqualTo []) then { getPosATL _target } else { _trail select 0 };
        private _grp = createGroup west;
        _grp setVariable ["CO_faction", "CRN_ENF", true];
        for "_i" from 0 to 2 do {
            private _u = _grp createUnit ["B_Soldier_F", _start getPos [6 + random 6, random 360], [], 0, "FORM"];
            [_u] call co_main_fnc_initHostileUnit;
            _u setAnimSpeedCoef (missionNamespace getVariable ["CO_tracker_speedCoef", 1.25]);
        };

        [_grp, _target] spawn {
            params ["_grp", "_target"];
            private _end = time + 300;
            private _nextCue = time + 10;
            while { time < _end && alive _target && ({ alive _x } count units _grp) > 0 } do {
                private _trail = _target getVariable ["CO_borderBreadcrumbs", []];
                if !(_trail isEqualTo []) then {
                    private _next = _trail select 0;
                    if ((leader _grp) distance2D _next < 12 && count _trail > 1) then {
                        _trail deleteAt 0;
                        _target setVariable ["CO_borderBreadcrumbs", _trail, true];
                    };
                    { if (alive _x && vehicle _x == _x) then { _x doMove _next } } forEach units _grp;
                };
                if (time > _nextCue) then {
                    _nextCue = time + 18 + random 8;
                    playSound3D ["A3\Sounds_F\sfx\alarm.wss", leader _grp, false, getPosASL (leader _grp), 0.25, 1.35, 140];
                };
                if ((leader _grp) distance2D _target < 80) then {
                    [units _grp, _target] call co_main_fnc_borderAlert;
                    _end = time;
                };
                sleep 3;
            };
            { if (alive _x) then { _x setAnimSpeedCoef 1 } } forEach units _grp;
            _target setVariable ["CO_borderTrackerActive", false, true];
        };
    };

    private _launchHeli = {
        params ["_target"];
        if (missionNamespace getVariable ["CO_borderHeliActive", false]) exitWith {};
        missionNamespace setVariable ["CO_borderHeliActive", true, true];
        private _pos = (getPosATL _target) vectorAdd [0, 900, 160];
        private _heli = "B_Heli_Light_01_F" createVehicle _pos;
        createVehicleCrew _heli;
        private _light = "#lightpoint" createVehicle _pos;
        _light setLightBrightness 1.8;
        _light setLightColor [1,1,0.85];
        _light setLightAmbient [0.7,0.7,0.55];
        _light attachTo [_heli, [0,2,-1.5]];
        [_heli, _light, _target] spawn {
            params ["_heli", "_light", "_target"];
            private _end = time + 300;
            while { alive _heli && time < _end && alive _target } do {
                private _center = getPosATL _target;
                for "_i" from 0 to 7 do {
                    _heli doMove (_center getPos [420, _i * 45]);
                    sleep 8;
                };
            };
            deleteVehicle _light;
            { deleteVehicle _x } forEach crew _heli;
            deleteVehicle _heli;
            missionNamespace setVariable ["CO_borderHeliActive", false, true];
        };
    };

    while { true } do {
        sleep 2;
        {
            private _p = _x;
            if (!alive _p || captive _p) then { continue };

            private _flagged = (_p getVariable ["CO_borderFlaggedUntil", 0]) > time;
            {
                _x params ["_pos", "_wire", "_armed"];
                if (_armed && (_p distance2D _pos) < 12 && time > (_p getVariable ["CO_nextBorderSensorAt", 0])) then {
                    _p setVariable ["CO_nextBorderSensorAt", time + 45, true];
                    _p setVariable ["CO_borderFlaggedUntil", time + 300, true];
                    _p setVariable ["CO_borderBreadcrumbs", [getPosATL _p], true];
                    "F_40mm_White" createVehicle (_pos vectorAdd [0,0,80]);
                    [_p, "PURSUIT", "border_tripflare", 85, grpNull] call co_main_fnc_setEscalationState;
                    {
                        if ((_x getVariable ["CO_faction", ""]) == "CRN_ENF" && (leader _x distance2D _pos) < 1200) then {
                            [units _x, _p] call co_main_fnc_borderAlert;
                        };
                    } forEach allGroups;
                    [_p, [_pos]] call _spawnTracker;
                    if ((dayTime < 5 || dayTime > 20) && { (_p getVariable ["CO_wantedLevel", 0]) >= 75 }) then {
                        [_p] call _launchHeli;
                    };
                };
            } forEach (missionNamespace getVariable ["CO_borderSensors", []]);

            if (_flagged) then {
                private _trail = _p getVariable ["CO_borderBreadcrumbs", []];
                private _pPos = getPosATL _p;
                private _trailBroken = surfaceIsWater _pPos || { isOnRoad _p } || { vehicle _p != _p };
                if (_trailBroken) then {
                    _p setVariable ["CO_borderBreadcrumbs", [], true];
                    _p setVariable ["CO_borderTrailColdUntil", time + 20, true];
                } else {
                    private _last = if (_trail isEqualTo []) then { [0,0,0] } else { _trail select ((count _trail) - 1) };
                    if (time > (_p getVariable ["CO_borderTrailColdUntil", 0]) && { _pPos distance2D _last > 35 }) then {
                        _trail pushBack _pPos;
                        if (count _trail > 24) then { _trail deleteAt 0 };
                        _p setVariable ["CO_borderBreadcrumbs", _trail, true];
                    };
                };
            };
        } forEach allPlayers;

        if ((dayTime < 5 || dayTime > 20) && time > _lastAmbient) then {
            _lastAmbient = time + 75 + random 60;
            private _sensors = missionNamespace getVariable ["CO_borderSensors", []];
            if !(_sensors isEqualTo []) then {
                private _pos = (selectRandom _sensors) select 0;
                "F_40mm_White" createVehicle (_pos vectorAdd [random 300 - 150, random 300 - 150, 90]);
            };
        };
    };
};

diag_log format ["[CO] Border zone online: %1 sensors, %2 outer patrol anchors.", count CO_borderSensors, count _anchors];
