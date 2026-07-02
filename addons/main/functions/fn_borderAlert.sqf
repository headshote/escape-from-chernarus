// ============================================================
// fn_borderAlert.sqf
// Makes border patrol units pursue a specific target.
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
private _priority = if (isPlayer _target) then { 70 } else { 50 };
private _targetKey = netId _target;
if (_targetKey == "") then { _targetKey = str _target };
private _token = format ["border_chase_%1_%2", _targetKey, floor (time * 10)];

private _claimed = [];
{
    if (alive _x && vehicle _x == _x && { [_x, _token, _priority, 45] call co_main_fnc_claimUnit }) then {
        _claimed pushBack _x;
    };
} forEach _units;

if (_claimed isEqualTo []) exitWith {};

[_target, getPosATL (vehicle _target), "border_alert", _priority] call co_main_fnc_alertPublish;
[_target] call co_main_fnc_installNonLethalDamage;

private _capture = {
    params [["_attacker", objNull]];

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
            [_target, _grp] call co_main_fnc_transportToDetention;
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

private _resolved = false;
private _deadline = time + 180;

while {
    alive _target &&
    !_resolved &&
    time < _deadline &&
    ({ alive _x } count _claimed) > 0
} do {
    private _liveUnits = _claimed select {
        alive _x &&
        vehicle _x == _x &&
        { [_x, _token, _priority, 25] call co_main_fnc_claimUnit }
    };
    if (_liveUnits isEqualTo []) exitWith {};

    private _engageObject = if (vehicle _target != _target) then { vehicle _target } else { _target };
    private _distanceFromHome = _target distance2D _homePos;
    private _shouldFire = (
        _mode != "capture" &&
        { (_distanceFromHome > _fireRadius) || (_vehicleLethal && vehicle _target != _target) }
    );

    {
        _x doTarget _engageObject;
        _x reveal [_engageObject, 4];
        _x setCombatMode "RED";
        _x setBehaviour "COMBAT";

        if (_shouldFire) then {
            _x commandFire _engageObject;
            _x doFire _engageObject;
        };
    } forEach _liveUnits;

    if (!_shouldFire && vehicle _target == _target) then {
        [_liveUnits, _target] call co_main_fnc_chaseMove;
        [_target, getPosATL _target, "border_chase", _priority] call co_main_fnc_alertPublish;

        if ([_liveUnits, _target] call co_main_fnc_proximityTackle) then {
            private _sortedUnits = [_liveUnits, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
            _resolved = [_sortedUnits select 0] call _capture;
        };
    };

    if ((_target getVariable ["CO_knockedOut", false]) || captive _target) then {
        _resolved = true;
    };

    if (_distanceFromHome > (_chaseRadius + 80)) exitWith {};
    sleep 0.7;
};

{
    if (alive _x) then {
        _x doMove _homePos;
        _x setCombatMode "YELLOW";
        _x setBehaviour "SAFE";
    };
    [_x, _token] call co_main_fnc_releaseUnit;
} forEach _claimed;
