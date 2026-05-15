// ============================================================
// fn_busAgroLoop.sqf — server-side bus AI controller
//
// Earlier revisions relied on engine waypoints + setBehaviour AWARE
// to drive the bus, but in practice that left buses inert: drivers
// hesitating, paths failing, and the aggro scan never reaching the
// engagement branch. This version scripts every motion via doMove,
// with explicit cruising / hunting / engaging / delivering states,
// a stuck-recovery watchdog, and periodic dismount-search stops in
// populated settlements so the patrol actually behaves like a
// hostile press-gang sweep.
//
// State machine:
//   cruising    -> follows scripted route, scans for civilians
//   huntCruise  -> civilian spotted, drive toward them
//   engaging    -> close enough, escort dismounts and chases
//   patrolStop  -> periodic foot search of a settlement
//   delivering  -> handed off to fn_transportToDetention
//
// Params: [_veh, _grp]
//   _veh - the patrol vehicle (must have CO_busRouteWps var)
//   _grp - the patrol group (driver = leader)
// ============================================================
params ["_veh", "_grp"];

if (!isServer) exitWith {};
if (isNull _veh || isNull _grp) exitWith {};

private _aggroRadius        = missionNamespace getVariable ["CO_bus_aggroRadius", 260];
private _maxCaptives        = missionNamespace getVariable ["CO_bus_maxCaptives", 3];
private _patrolStopInterval = missionNamespace getVariable ["CO_bus_patrolStopInterval", 150];

private _routeWps = _veh getVariable ["CO_busRouteWps", []];
if (count _routeWps == 0) then { _routeWps = [getPosATL _veh] };

private _wpIdx          = 0;
private _stuckSince     = -1;
private _lastDoMove     = 0;
private _huntTarget     = objNull;
private _huntUntil      = 0;
private _lastPatrolStop = (time - _patrolStopInterval) + random 30;

_veh setVariable ["CO_busState", "cruising", true];

// Initial kick: ensure engine is on and the driver is heading somewhere.
_veh engineOn true;
_veh setFuel 1;

private _initDriver = driver _veh;
if (!isNull _initDriver) then {
    _initDriver enableAI "MOVE";
    _initDriver enableAI "PATH";
    _initDriver enableAI "FSM";
    _initDriver enableAI "AUTOTARGET";
    _initDriver doMove (_routeWps select 0);
    _veh forceSpeed -1;
};

diag_log format [
    "[CO] busAgroLoop started for %1 (route %2 wps).",
    typeOf _veh, count _routeWps
];

while { alive _veh } do {
    sleep 3;
    if (!alive _veh) exitWith {};

    private _state  = _veh getVariable ["CO_busState", "cruising"];
    // Legacy state name from older revisions
    if (_state == "patrol") then {
        _state = "cruising";
        _veh setVariable ["CO_busState", "cruising", true];
    };
    private _driver = driver _veh;

    // --- Driver replacement if dead ---
    if (isNull _driver || !alive _driver) then {
        private _alts = (units _grp) select {
            alive _x && vehicle _x == _veh && _x != driver _veh
        };
        if (count _alts > 0) then {
            (_alts select 0) moveInDriver _veh;
            _driver = driver _veh;
            if (!isNull _driver) then {
                _driver enableAI "MOVE";
                _driver enableAI "PATH";
                _veh engineOn true;
                _veh forceSpeed -1;
                _lastDoMove = 0;
                diag_log format ["[CO] Bus driver swapped at %1.", mapGridPosition _veh];
            };
        };
    };

    if (isNull driver _veh) exitWith {
        diag_log format ["[CO] Bus abandoned at %1 — terminating loop.", mapGridPosition _veh];
        _veh setVariable ["CO_busState", "abandoned", true];
    };
    _driver = driver _veh;

    // --- Delivery: external code drives ---
    if (_state == "delivering") then { continue };

    // --- Captive cap reached: idle until delivery scheduler takes over ---
    private _aboard = (_veh getVariable ["CO_busCaptives", []]) select {
        !isNull _x && alive _x && captive _x
    };
    _veh setVariable ["CO_busCaptives", _aboard, true];

    if (count _aboard >= _maxCaptives) then { continue };

    // ============================================================
    // SCAN — find target civilians/players around the bus
    // ============================================================
    private _scanCenter = getPosATL _veh;
    private _scan = (_scanCenter nearEntities [["Man"], _aggroRadius]) select {
        private _u = _x;
        private _ok = true;
        if (isNull _u || !alive _u || captive _u) then { _ok = false };
        if (_ok && (_u getVariable ["CO_isFemale", false])) then { _ok = false };
        if (_ok && (_u getVariable ["CO_captureInProgress", false])) then { _ok = false };
        if (_ok && (_u getVariable ["CO_knockedOut", false])) then { _ok = false };
        if (_ok && (vehicle _u == _veh)) then { _ok = false };
        if (_ok) then {
            private _f = group _u getVariable ["CO_faction", ""];
            if (_f in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) then { _ok = false };
        };
        if (_ok) then {
            if (isPlayer _u) then {
                _ok = !((side group _u) in [west, east]);
            } else {
                _ok = (side _u == civilian);
            };
        };
        _ok
    };

    // Also catch civilians inside civilian vehicles (drive-by)
    if (_scan isEqualTo []) then {
        private _vehCands = (_scanCenter nearEntities [["LandVehicle"], _aggroRadius + 150]) select {
            _x != _veh && alive _x && !(_x getVariable ["CO_isBusPatrol", false])
        };
        {
            private _v = _x;
            private _crew = (crew _v) select {
                private _u = _x;
                private _ok = (alive _u && !captive _u && !(_u getVariable ["CO_isFemale", false]));
                if (_ok) then {
                    private _f = group _u getVariable ["CO_faction", ""];
                    if (_f in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) then { _ok = false };
                };
                if (_ok) then {
                    _ok = (isPlayer _u || side _u == civilian);
                };
                _ok
            };
            if (count _crew > 0) exitWith { _scan = [_crew select 0]; };
        } forEach _vehCands;
    };

    // ============================================================
    // STATE switching: cruising -> huntCruise on target detect
    // ============================================================
    if !(_scan isEqualTo []) then {
        if !(_state in ["engaging","patrolStop"]) then {
            private _sorted = [_scan, [], { _x distance2D _veh }, "ASCEND"] call BIS_fnc_sortBy;
            _huntTarget = _sorted select 0;
            _huntUntil  = time + 90;
            _veh setVariable ["CO_busState", "huntCruise", true];
            _state = "huntCruise";
            _lastDoMove = 0;
            diag_log format [
                "[CO] Bus %1 acquired hunt target %2 at %3m.",
                netId _veh, name _huntTarget, round (_veh distance2D _huntTarget)
            ];
        };
    };

    // ============================================================
    // huntCruise: drive at the target until close enough to engage
    // ============================================================
    if (_state == "huntCruise") then {
        if (isNull _huntTarget || !alive _huntTarget || captive _huntTarget ||
            (_huntTarget getVariable ["CO_captureInProgress", false]) ||
            (_huntTarget getVariable ["CO_knockedOut", false]) ||
            time > _huntUntil) then {
            _huntTarget = objNull;
            _veh setVariable ["CO_busState", "cruising", true];
            _state = "cruising";
            _lastDoMove = 0;
        } else {
            private _tgtPos = getPosATL _huntTarget;
            if ((time - _lastDoMove) > 4) then {
                private _vel = velocity _huntTarget;
                if !(_vel isEqualTo [0,0,0]) then {
                    _tgtPos = _tgtPos vectorAdd (_vel vectorMultiply 4);
                };
                _driver doMove _tgtPos;
                _veh forceSpeed -1;
                _lastDoMove = time;
            };

            if (_veh distance2D _huntTarget < 45) then {
                _veh setVariable ["CO_busState", "engaging", true];
                [_veh, _grp, _huntTarget] spawn {
                    params ["_bus","_grp","_target"];
                    private _drv = driver _bus;
                    if (!isNull _drv) then {
                        doStop _drv;
                        _bus forceSpeed 0;
                        _drv setVariable ["CO_vehicleChaseDriver", true, false];
                        _drv setBehaviour "COMBAT";
                        _drv setCombatMode "RED";
                    };

                    private _escort = (units _grp) select {
                        alive _x && _x != driver _bus && vehicle _x == _bus
                    };

                    {
                        _x enableAI "MOVE";
                        _x enableAI "PATH";
                        _x enableAI "AUTOCOMBAT";
                        _x allowGetIn false;
                        unassignVehicle _x;
                        doGetOut _x;
                        moveOut _x;
                        _x setBehaviour "COMBAT";
                        _x setCombatMode "RED";
                        _x doTarget _target;
                        _x doMove (getPosATL _target);
                    } forEach _escort;

                    [[_target], _grp] call co_main_fnc_checkpointAlert;

                    private _deadline = time + 45;
                    waitUntil {
                        sleep 1;
                        !alive _bus ||
                        !alive _target ||
                        captive _target ||
                        (_target getVariable ["CO_knockedOut", false]) ||
                        time > _deadline
                    };

                    if (!alive _bus) exitWith {};

                    {
                        if (alive _x) then {
                            _x allowGetIn true;
                            _x assignAsCargo _bus;
                            [_x] orderGetIn true;
                            _x doMove (getPosATL _bus);
                        };
                    } forEach _escort;

                    private _reboardEnd = time + 15;
                    waitUntil {
                        sleep 0.5;
                        !alive _bus ||
                        ({ vehicle _x == _bus } count _escort) >= count _escort ||
                        time > _reboardEnd
                    };

                    if (!alive _bus) exitWith {};
                    if (!isNull _drv && alive _drv) then {
                        _drv setVariable ["CO_vehicleChaseDriver", false, false];
                        _drv setBehaviour "AWARE";
                        _drv setCombatMode "YELLOW";
                    };
                    _bus forceSpeed -1;
                    if ((_bus getVariable ["CO_busState","engaging"]) == "engaging") then {
                        _bus setVariable ["CO_busState", "cruising", true];
                    };
                };
            };
        };
    };

    // ============================================================
    // cruising: route waypoints + stuck recovery + patrol stops
    // ============================================================
    if (_state == "cruising") then {
        if (count _routeWps > 0) then {
            private _wp = _routeWps select (_wpIdx mod count _routeWps);

            if (_veh distance2D _wp < 25) then {
                _wpIdx = _wpIdx + 1;
                _lastDoMove = 0;
            } else {
                if ((time - _lastDoMove) > 6) then {
                    _driver doMove _wp;
                    _veh forceSpeed -1;
                    _lastDoMove = time;
                };
            };
        };

        if ((speed _veh) < 1.5) then {
            if (_stuckSince < 0) then { _stuckSince = time };
            if ((time - _stuckSince) > 25) then {
                diag_log format [
                    "[CO] Bus %1 stuck %2s at %3 — unsticking.",
                    netId _veh, round (time - _stuckSince), mapGridPosition _veh
                ];
                private _roads = (getPosATL _veh) nearRoads 120;
                if (count _roads > 0) then {
                    private _r = selectRandom _roads;
                    _veh setPos ((getPos _r) vectorAdd [0, 0, 0.3]);
                    _veh setVectorUp [0, 0, 1];
                };
                _veh engineOn true;
                _stuckSince = time;
                _lastDoMove = 0;
                _driver doMove (_routeWps select (_wpIdx mod count _routeWps));
            };
        } else {
            _stuckSince = -1;
        };

        // Periodic foot search inside towns
        if ((time - _lastPatrolStop) > _patrolStopInterval) then {
            private _nearSettlement = (CO_settlements findIf {
                (_veh distance2D (_x select 1)) < 350
            }) >= 0;
            if (_nearSettlement && (speed _veh) > 4) then {
                _lastPatrolStop = time;
                _veh setVariable ["CO_busState", "patrolStop", true];
                [_veh, _grp] spawn {
                    params ["_bus","_grp"];
                    private _drv = driver _bus;
                    if (isNull _drv) exitWith {};

                    doStop _drv;
                    _bus forceSpeed 0;

                    private _escort = (units _grp) select {
                        alive _x && _x != _drv && vehicle _x == _bus
                    };
                    {
                        _x allowGetIn false;
                        unassignVehicle _x;
                        doGetOut _x;
                        moveOut _x;
                        _x setBehaviour "AWARE";
                        _x setCombatMode "YELLOW";
                        private _patrolPoint = (getPosATL _bus) getPos [10 + random 30, random 360];
                        _x doMove _patrolPoint;
                    } forEach _escort;

                    sleep 35;

                    if (alive _bus && (_bus getVariable ["CO_busState","patrolStop"]) == "patrolStop") then {
                        {
                            if (alive _x) then {
                                _x allowGetIn true;
                                _x assignAsCargo _bus;
                                [_x] orderGetIn true;
                                _x doMove (getPosATL _bus);
                            };
                        } forEach _escort;
                        private _reboardEnd = time + 15;
                        waitUntil {
                            sleep 0.5;
                            !alive _bus ||
                            ({ vehicle _x == _bus } count _escort) >= count _escort ||
                            time > _reboardEnd
                        };
                        if (alive _bus) then {
                            _bus forceSpeed -1;
                            _bus setVariable ["CO_busState","cruising",true];
                        };
                    };
                };
            };
        };
    };
};

diag_log format ["[CO] busAgroLoop exiting for %1.", netId _veh];
