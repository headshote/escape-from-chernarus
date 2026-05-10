// ============================================================
// fn_borderAlert.sqf
// Makes a list of border patrol units pursue a specific target.
// params: [_units, _target]
// ============================================================
params ["_units", "_target"];

if (_units isEqualTo [] || isNull _target) exitWith {};

private _grp = group (_units select 0);
private _mode = _grp getVariable ["CO_borderMode", "capture"];
private _homePos = _grp getVariable ["CO_borderHomePos", getPosATL (leader _grp)];
private _chaseRadius = _grp getVariable ["CO_borderChaseRadius", 180];
private _fireRadius = _grp getVariable ["CO_borderFireRadius", 85];
private _vehicleLethal = _grp getVariable ["CO_borderVehicleLethal", false];

if (_mode == "capture") exitWith {
    {
        _x doTarget _target;
        _x doMove getPosATL _target;
        _x setCombatMode "RED";
        _x setBehaviour "COMBAT";
    } forEach _units;

    // Capture check — same pattern as checkpoint
    [_target, _grp] spawn {
        params ["_target", "_grp"];
        waitUntil {
            sleep 0.5;
            private _nearest = units _grp select { alive _x };
            if (count _nearest == 0) exitWith { true };
            private _sorted = [_nearest, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
            if ((_sorted select 0) distance _target < 2.5) then {
                if (isPlayer _target) then {
                    [_target] remoteExecCall ["co_main_fnc_wrangleMinigame", _target];
                    waitUntil { !isNil { _target getVariable "CO_wrangleResult" } };
                    private _result = _target getVariable ["CO_wrangleResult", "captured"];
                    _target setVariable ["CO_wrangleResult", nil, true];
                    if (_result == "captured") then {
                        _target setCaptive true;
                        [_target, _grp] call co_main_fnc_transportToDetention;
                    };
                } else {
                    // Non-player target: never run a wrangle dialog (would block
                    // forever waiting for a key handler that no one will trigger).
                    // Use the same melee knockout flow as checkpointAlert.
                    private _attacker = _sorted select 0;
                    [_attacker, _target] call co_main_fnc_applyMeleeHit;
                    if (_target getVariable ["CO_knockedOut", false]) then {
                        _target setCaptive true;
                        [_target, _grp] call co_main_fnc_transportToDetention;
                    };
                };
                true
            } else {
                false
            };
        };
    };
};

private _resolved = false;
private _lastMeleeAt = 0;

while { alive _target && !_resolved } do {
    private _liveUnits = units _grp select { alive _x };
    if (_liveUnits isEqualTo []) exitWith {};

    private _engageObject = if (vehicle _target != _target) then { vehicle _target } else { _target };
    private _distanceFromHome = _target distance2D _homePos;
    private _shouldFire = (_distanceFromHome > _fireRadius) || (_vehicleLethal && vehicle _target != _target);

    {
        _x doTarget _engageObject;
        _x setCombatMode "RED";
        _x setBehaviour "COMBAT";

        if (_shouldFire) then {
            _x commandFire _engageObject;
            _x doFire _engageObject;
        } else {
            _x doMove (getPosATL _target);
        };
    } forEach _liveUnits;

    if (!_shouldFire && vehicle _target == _target) then {
        private _sortedUnits = [_liveUnits, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
        private _attacker = _sortedUnits select 0;

        if ((_attacker distance _target) < 2.6 && time > (_lastMeleeAt + 0.9)) then {
            [_attacker, _target] call co_main_fnc_applyMeleeHit;
            _lastMeleeAt = time;
        };

        if ((_target getVariable ["CO_knockedOut", false]) || captive _target) then {
            _target setCaptive true;
            [_target, _grp] call co_main_fnc_transportToDetention;
            _resolved = true;
        };
    };

    if (_distanceFromHome > (_chaseRadius + 80)) exitWith {};

    sleep 1;
};

{
    if (alive _x) then {
        _x doMove _homePos;
        _x setCombatMode "YELLOW";
        _x setBehaviour "SAFE";
    };
} forEach units _grp;