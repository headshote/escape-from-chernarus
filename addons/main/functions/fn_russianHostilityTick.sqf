// ============================================================
// fn_russianHostilityTick.sqf
//
// Per-player fallback bridge spawned by fn_deployToFront. The global
// russianAssaultBrain handles the battle as a whole; this keeps the local
// player's immediate threat responsive even if they are civilian-side in the
// engine relation table.
// ============================================================
params ["_player"];
if (!isServer) exitWith {};
if (isNull _player) exitWith {};

while {
    alive _player &&
    (_player getVariable ["CO_isCleared", false]) &&
    ((_player getVariable ["CO_detainPhase", ""]) == "deployed") &&
    !(_player getVariable ["CO_isAWOL", false])
} do {
    private _target = if (vehicle _player == _player) then { _player } else { vehicle _player };

    private _nearRus = (getPosATL _player nearEntities [["Man"], 650]) select {
        alive _x &&
        vehicle _x == _x &&
        ((group _x) getVariable ["CO_faction", ""]) == "RUS_ADV"
    };
    private _nearRusSorted = [_nearRus, [], { _x distance _player }, "ASCEND"] call BIS_fnc_sortBy;
    {
        _x reveal [_target, 4];
        _x doWatch _target;
        _x doTarget _target;
        _x doFire _target;
        _x setCombatMode "RED";
        _x setBehaviour "COMBAT";
        if ((_x distance2D _target) > 90) then { _x doMove (getPosATL _target) };

        private _weapon = currentWeapon _x;
        if (_weapon != "") then {
            _x fireAtTarget [_target, _weapon];
        } else {
            _x fireAtTarget [_target];
        };
    } forEach (_nearRusSorted select [0, 8]);

    private _nearRusVeh = (getPosATL _player nearEntities [["Car", "Tank", "Wheeled_APC_F", "Tracked_APC"], 1200]) select {
        alive _x &&
        ((group (effectiveCommander _x)) getVariable ["CO_faction", ""]) == "RUS_ADV"
    };
    private _nearRusVehSorted = [_nearRusVeh, [], { _x distance _player }, "ASCEND"] call BIS_fnc_sortBy;
    {
        private _veh = _x;
        _veh setVehicleReceiveRemoteTargets true;
        _veh setVehicleReportRemoteTargets true;

        {
            if (alive _x) then {
                _x reveal [_target, 4];
                _x doWatch _target;
                _x doTarget _target;
                _x doFire _target;
                _x setCombatMode "RED";
                _x setBehaviour "COMBAT";
            };
        } forEach (crew _veh);

        private _gunner = gunner _veh;
        if (!isNull _gunner && { alive _gunner }) then {
            private _weapon = currentWeapon _gunner;
            if (_weapon != "") then {
                _gunner fireAtTarget [_target, _weapon];
            } else {
                _gunner fireAtTarget [_target];
            };
        };

        private _driver = driver _veh;
        if (!isNull _driver && { alive _driver && ((_veh distance2D _target) > 220) }) then {
            _driver doMove (getPosATL _target);
        };
    } forEach (_nearRusVehSorted select [0, 4]);

    sleep 5;
};
