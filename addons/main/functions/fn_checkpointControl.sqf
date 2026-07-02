// ============================================================
// fn_checkpointControl.sqf
// Legal passage, bypass detection, barrier running, pursuit car,
// spike dispatch, and night dressing for one checkpoint.
// params: [_pos, _dir, _grp, _objects, _pursuitCar, _pursuitGrp]
// ============================================================
params [
    ["_pos", [0,0,0]],
    ["_dir", 0],
    ["_grp", grpNull],
    ["_objects", []],
    ["_pursuitCar", objNull],
    ["_pursuitGrp", grpNull]
];

if (!isServer || isNull _grp) exitWith {};
if (_grp getVariable ["CO_checkpointControlActive", false]) exitWith {};
_grp setVariable ["CO_checkpointControlActive", true, false];

[_pos, _dir, _grp, _objects, _pursuitCar, _pursuitGrp] spawn {
    params ["_pos", "_dir", "_grp", "_objects", "_pursuitCar", "_pursuitGrp"];
    private _tracked = createHashMap;
    private _lastFlareAt = 0;

    private _alert = {
        params ["_driver", "_state", "_wantedAdd", "_reason"];
        private _wl = ((_driver getVariable ["CO_wantedLevel", 0]) + _wantedAdd) min 100;
        _driver setVariable ["CO_wantedLevel", _wl, true];
        [_driver, _state, format ["checkpoint_%1", _reason], 60 + _wantedAdd, _grp] call co_main_fnc_setEscalationState;
        if (dayTime < 5 || dayTime > 20) then {
            if ((time - _lastFlareAt) > 25) then {
                _lastFlareAt = time;
                "F_40mm_White" createVehicle ((_pos getPos [18, _dir]) vectorAdd [0,0,80]);
            };
        };
        if (!isNull _pursuitCar && alive _pursuitCar && !isNull _pursuitGrp) then {
            [_pursuitGrp, _pursuitCar, _driver, "checkpoint_pursuit"] spawn co_main_fnc_policeVehiclePursuit;
        };
    };

    while { ({ alive _x } count units _grp) > 0 } do {
        sleep 1;

        private _hourNight = (dayTime < 5 || dayTime > 20);
        {
            if (typeOf _x == "#lightpoint") then {
                _x setLightBrightness (if (_hourNight) then { 0.75 } else { 0.15 });
            };
        } forEach _objects;

        private _vehicles = (_pos nearEntities [["LandVehicle"], 360]) select {
            alive _x &&
            !(_x getVariable ["CO_isBusPatrol", false]) &&
            !(_x getVariable ["CO_isCaptureTransport", false]) &&
            !isNull (driver _x) &&
            alive (driver _x) &&
            (isPlayer (driver _x) || side (driver _x) == civilian)
        };

        {
            private _veh = _x;
            private _driver = driver _veh;
            private _id = netId _veh;
            private _d = _veh distance2D _pos;
            private _rec = _tracked getOrDefault [_id, [_d, time, false, false, false]];
            _rec params ["_lastD", "_seenAt", "_inspecting", "_bypassed", "_barrierRun"];

            if (_d < 30 && abs (speed _veh) < 8 && !_inspecting) then {
                _rec set [2, true];
                _tracked set [_id, _rec];
                [_driver, "SUSPICIOUS", "checkpoint_inspection", 35, _grp] call co_main_fnc_setEscalationState;
                if (isPlayer _driver) then {
                    ["Checkpoint inspection. Stop and keep the engine quiet."] remoteExecCall ["systemChat", _driver];
                };
                [_veh, _driver, _grp, _pursuitCar, _pursuitGrp] spawn {
                    params ["_veh", "_driver", "_grp", "_pursuitCar", "_pursuitGrp"];
                    sleep (10 + random 5);
                    if (!alive _driver || captive _driver) exitWith {};
                    if ((_veh distance2D (leader _grp)) > 55 || abs (speed _veh) > 12) exitWith {
                        private _wl = ((_driver getVariable ["CO_wantedLevel", 0]) + 20) min 100;
                        _driver setVariable ["CO_wantedLevel", _wl, true];
                        [_driver, "PURSUIT", "checkpoint_fled_inspection", 65, _grp] call co_main_fnc_setEscalationState;
                        if (!isNull _pursuitCar && alive _pursuitCar && !isNull _pursuitGrp) then {
                            [_pursuitGrp, _pursuitCar, _driver, "checkpoint_pursuit"] spawn co_main_fnc_policeVehiclePursuit;
                        };
                    };
                    private _wanted = _driver getVariable ["CO_wantedLevel", 0];
                    private _disguise = _driver getVariable ["CO_disguiseLevel", 0];
                    private _risk = _wanted - (_disguise * 12) + random 20;
                    if (_risk < 45) then {
                        [_driver, "CLEAR", "checkpoint_pass", 0, _grp] call co_main_fnc_setEscalationState;
                        if (isPlayer _driver) then { ["Documents accepted. Move through."] remoteExecCall ["systemChat", _driver] };
                    } else {
                        private _add = if (_risk < 65) then { 10 } else { 30 };
                        _driver setVariable ["CO_wantedLevel", ((_wanted + _add) min 100), true];
                        [_driver, "PURSUIT", "checkpoint_failed_papers", 75, _grp] call co_main_fnc_setEscalationState;
                        if (!isNull _pursuitCar && alive _pursuitCar && !isNull _pursuitGrp) then {
                            [_pursuitGrp, _pursuitCar, _driver, "checkpoint_pursuit"] spawn co_main_fnc_policeVehiclePursuit;
                        };
                        [[_driver], _grp] call co_main_fnc_checkpointAlert;
                    };
                };
            };

            private _offroadBypass = _d < 260 && _lastD < 220 && _d > (_lastD + 12) && !(isOnRoad _veh);
            if (_offroadBypass && !_bypassed) then {
                _rec set [3, true];
                [_driver, "PURSUIT", 15, "bypass"] call _alert;
                [_driver, getPosATL _driver, "checkpoint_bypass", 55] call co_main_fnc_alertPublish;
            };

            if (_d < 14 && abs (speed _veh) > 28 && !_barrierRun) then {
                _rec set [4, true];
                [_driver, "WEAPONS", 30, "barrier_run"] call _alert;
                [_driver, getPosATL _driver, _grp getVariable ["CO_faction", "CRN_ENF"], 650, 180] call co_main_fnc_dispatchRoadblock;
            };

            _rec set [0, _d];
            _tracked set [_id, _rec];
        } forEach _vehicles;
    };
};
