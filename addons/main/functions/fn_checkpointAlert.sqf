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

    {
        _x doTarget _target;
        _x setCombatMode "RED";
        _x setBehaviour "COMBAT";
        _x reveal [_target, 4];
    } forEach _claimed;

    [_target, _hostileGrp, _claimed, _token, _priority] spawn {
        params ["_target", "_grp", "_claimed", "_token", "_priority"];

        private _finished = false;
        private _startedAt = time;
        private _lastAlertAt = 0;
        private _deadline = time + 180;

        private _capturePlayerOrNpc = {
            params [["_attacker", objNull]];

            private _wl = (_target getVariable ["CO_wantedLevel", 0]) + 30;
            _target setVariable ["CO_wantedLevel", _wl min 100, true];

            if (isPlayer _target) then {
                [_target] remoteExecCall ["co_main_fnc_wrangleMinigame", _target];
                private _wrangleDeadline = time + 20;
                waitUntil {
                    sleep 0.3;
                    !alive _target ||
                    !isNil { _target getVariable "CO_wrangleResult" } ||
                    time > _wrangleDeadline
                };

                private _result = _target getVariable ["CO_wrangleResult", "captured"];
                _target setVariable ["CO_wrangleResult", nil, true];

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

            private _engageObject = if (vehicle _target != _target) then { vehicle _target } else { _target };
            {
                _x reveal [_engageObject, 4];
                _x doTarget _engageObject;
                _x setCombatMode "RED";
                _x setBehaviour "COMBAT";
            } forEach _liveUnits;

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
                private _shooters = _liveUnits select [0, (3 min count _liveUnits)];
                {
                    _x reveal [_engageObject, 4];
                    _x doWatch _engageObject;
                    _x fireAtTarget [_engageObject];
                } forEach _shooters;
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

        {
            [_x, _token] call co_main_fnc_releaseUnit;
        } forEach _claimed;

        _grp setVariable ["CO_grpEngaging", false, false];
    };
} forEach _detectedUnits;
