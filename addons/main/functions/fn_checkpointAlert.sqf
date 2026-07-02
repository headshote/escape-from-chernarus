params ["_detectedUnits", "_hostileGrp"];

if (isNull _hostileGrp) exitWith {};

{
    private _target = _x;
    if (!(isPlayer _target) && side _target != civilian) then { continue };
    if (_target getVariable ["CO_captureInProgress", false]) then { continue };
    if (_target getVariable ["CO_isFemale", false]) then { continue };

    if (_target getVariable ["CO_isCleared", false] &&
        !(_target getVariable ["CO_isAWOL", false])) then { continue };

    if (!isNil "CO_airfieldCenter" &&
        {_target distance2D CO_airfieldCenter < (CO_airfieldRadius + 20)} &&
        !(_target getVariable ["CO_isAWOL", false])) then { continue };

    private _priority = if (isPlayer _target) then { 70 } else { 50 };
    private _targetKey = netId _target;
    if (_targetKey == "") then { _targetKey = str _target };
    private _token = format ["checkpoint_chase_%1_%2", _targetKey, floor (time * 10)];

    private _claimed = [];
    {
        if (
            alive _x &&
            vehicle _x == _x &&
            !(_x getVariable ["CO_vehicleChaseDriver", false]) &&
            { [_x, _token, _priority, 45] call co_main_fnc_claimUnit }
        ) then {
            _claimed pushBack _x;
        };
    } forEach units _hostileGrp;

    if (_claimed isEqualTo []) then { continue };

    _hostileGrp setVariable ["CO_grpEngaging", true, false];
    _target setVariable ["CO_captureInProgress", true, true];
    [_target] call co_main_fnc_installNonLethalDamage;
    [getPosATL _target, _hostileGrp, _target] call co_main_fnc_crowdResistance;
    [_target, getPosATL (vehicle _target), "checkpoint_alert", _priority] call co_main_fnc_alertPublish;

    // One-time posture. AWARE (not COMBAT) — COMBAT behaviour makes AI
    // bound/crawl tactically, which is exactly how a chase dies (R2-12).
    // fn_chaseMove owns movement from here; explicit fireAtTarget commands
    // below don't need COMBAT mode.
    {
        _x setBehaviour "AWARE";
        _x setCombatMode "YELLOW";
        _x reveal [_target, 4];
    } forEach _claimed;

    [_target, _hostileGrp, _claimed, _token, _priority] spawn {
        params ["_target", "_grp", "_claimed", "_token", "_priority"];

        private _finished = false;
        private _startedAt = time;
        private _lastAlertAt = 0;
        private _deadline = time + 180;
        // Static guards never abandon their post beyond the leash —
        // beyond it, the runner's position is radioed to mobile units.
        private _anchor = _grp getVariable ["CO_aggroAnchor", getPosATL (leader _grp)];
        private _leash = missionNamespace getVariable ["CO_checkpoint_chaseLeash", 250];
        private _leashed = false;

        private _capturePlayerOrNpc = {
            params [["_attacker", objNull]];

            private _wl = (_target getVariable ["CO_wantedLevel", 0]) + 30;
            _target setVariable ["CO_wantedLevel", _wl min 100, true];

            if (isPlayer _target) then {
                private _result = [_target, 20] call co_main_fnc_runWrangle;

                // Grab owned by another controller or player gone —
                // hold the cordon, try again next tick.
                if (_result in ["busy", "dead"]) exitWith { false };

                if (_result == "captured") exitWith {
                    _target setCaptive true;
                    private _grpFac = _grp getVariable ["CO_faction", ""];
                    if (_grpFac == "CRN_ENF") then {
                        [_target, _grp] spawn co_main_fnc_spawnCaptureTransport;
                    } else {
                        [_target, _grp] call co_main_fnc_transportToDetention;
                    };
                    true
                };

                _target setVariable ["CO_tackleImmuneUntil", time + 6, true];
                sleep 2;
                false
            } else {
                if (!isNull _attacker) then {
                    [_attacker, _target, 60, true] call co_main_fnc_applyKnockout;
                };
                if (_target getVariable ["CO_knockedOut", false]) then {
                    _target setCaptive true;
                    [_target, _grp] call co_main_fnc_transportToDetention;
                    true
                } else {
                    false
                }
            }
        };

        while {
            alive _target &&
            !captive _target &&
            !_finished &&
            time < _deadline
        } do {
            private _liveUnits = _claimed select {
                alive _x &&
                vehicle _x == _x &&
                !(_x getVariable ["CO_vehicleChaseDriver", false]) &&
                { [_x, _token, _priority, 25] call co_main_fnc_claimUnit }
            };
            if (_liveUnits isEqualTo []) exitWith {};

            // Leash: a checkpoint that empties itself chasing one runner
            // is a checkpoint you can walk through. Hand the runner to
            // the alert net and go home.
            if ((_target distance2D _anchor) > _leash) exitWith {
                _leashed = true;
                [_target, getPosATL (vehicle _target), "checkpoint_leash", 65] call co_main_fnc_alertPublish;
                [_target, "SEARCH", "checkpoint_leash", 60, _grp] call co_main_fnc_setEscalationState;
            };

            private _engageObject = if (vehicle _target != _target) then { vehicle _target } else { _target };

            if (vehicle _target == _target) then {
                [_liveUnits, _target] call co_main_fnc_chaseMove;
                if ((time - _lastAlertAt) > 5) then {
                    [_target, getPosATL _target, "checkpoint_chase", _priority] call co_main_fnc_alertPublish;
                    _lastAlertAt = time;
                };

                private _nearest = [_liveUnits, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
                private _closest = _nearest select 0;
                private _dist = _closest distance _target;

                if (_dist > 18 && (time - _startedAt) > 20) then {
                    private _shooters = _nearest select [0, (3 min count _nearest)];
                    {
                        _x reveal [_target, 4];
                        _x doWatch _target;
                        _x fireAtTarget [_target];
                    } forEach _shooters;
                };

                if ([_liveUnits, _target] call co_main_fnc_proximityTackle) then {
                    _finished = [_closest] call _capturePlayerOrNpc;
                };
            } else {
                // Target in a vehicle: shoot at the DRIVER, not the hull —
                // hull fire blows the car up and kills the "non-lethal"
                // target (R2-15). Only inside 100 m; beyond that the leash
                // or the alert net handles it.
                private _drv = driver (vehicle _target);
                if (!isNull _drv && (_target distance (leader _grp)) < 100) then {
                    private _shooters = _liveUnits select [0, (3 min count _liveUnits)];
                    {
                        _x reveal [_drv, 4];
                        _x doWatch _drv;
                        _x fireAtTarget [_drv];
                    } forEach _shooters;
                };
            };

            if (_target getVariable ["CO_knockedOut", false]) then {
                _target setCaptive true;
                private _grpFac = _grp getVariable ["CO_faction", ""];
                if (isPlayer _target && _grpFac == "CRN_ENF") then {
                    [_target, _grp] spawn co_main_fnc_spawnCaptureTransport;
                } else {
                    [_target, _grp] call co_main_fnc_transportToDetention;
                };
                _finished = true;
            };

            sleep 0.7;
        };

        if (alive _target && !(_target getVariable ["CO_knockedOut", false]) && !captive _target) then {
            _target setVariable ["CO_captureInProgress", false, true];
        };

        // Return to post: walk back to the anchor and restore the guard
        // posture + patrol waypoints so the checkpoint re-arms itself.
        {
            if (alive _x && vehicle _x == _x) then {
                _x setBehaviour "AWARE";
                _x setCombatMode "YELLOW";
                _x setUnitPos "AUTO";
                _x doMove (_anchor getPos [3 + random 6, random 360]);
            };
            [_x, _token] call co_main_fnc_releaseUnit;
        } forEach _claimed;
        if (count (waypoints _grp) > 0) then {
            _grp setCurrentWaypoint [_grp, 0];
        };

        _grp setVariable ["CO_grpEngaging", false, false];
    };
} forEach _detectedUnits;
