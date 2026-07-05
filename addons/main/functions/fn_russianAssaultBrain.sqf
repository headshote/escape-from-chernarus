// ============================================================
// fn_russianAssaultBrain.sqf
//
// Server-side targeting bridge for the Krasnostav battle. Engine relations
// make OPFOR ignore civilian-side player slots, even after deployment, so this
// loop explicitly feeds RUS_ADV groups valid deployed conscript / CRN_FRONT
// targets. Bounded scans keep it cheap while making armor and infantry feel
// awake around the town.
// ============================================================
if (!isServer) exitWith {};
if (missionNamespace getVariable ["CO_russianAssaultBrainRunning", false]) exitWith {};
missionNamespace setVariable ["CO_russianAssaultBrainRunning", true, false];

private _sectorCenter = [11200, 12300, 0];
private _sectorRadius = 3600;
private _engageRadius = 1700;

while { true } do {
    sleep 4;

    private _targets = (allPlayers + allUnits) select {
        private _u = _x;
        if (!alive _u) exitWith { false };
        if (_u getVariable ["CO_isAWOL", false]) exitWith { false };
        if ((_u distance2D _sectorCenter) > _sectorRadius) exitWith { false };

        private _fac = group _u getVariable ["CO_faction", ""];
        (_fac == "CRN_FRONT") ||
        {
            (_u getVariable ["CO_isCleared", false]) &&
            ((_u getVariable ["CO_detainPhase", ""]) == "deployed")
        }
    };
    _targets = _targets arrayIntersect _targets;

    if (_targets isEqualTo []) then { continue };

    {
        private _grp = _x;
        if ((_grp getVariable ["CO_faction", ""]) != "RUS_ADV") then { continue };
        private _live = units _grp select { alive _x };
        if (_live isEqualTo []) then { continue };

        private _anchor = getPosATL (vehicle (leader _grp));
        if ((_anchor distance2D _sectorCenter) > (_sectorRadius + 900)) then { continue };

        private _nearTargets = _targets select {
            private _tObj = if (vehicle _x == _x) then { _x } else { vehicle _x };
            alive _tObj && { (_tObj distance2D _anchor) < _engageRadius }
        };
        if (_nearTargets isEqualTo []) then {
            if ((_grp getVariable ["CO_advanceLane", ""]) == "north") then {
                private _patrolPos = selectRandom [
                    [11200 + random 500 - 250, 12300 + random 500 - 250, 0],
                    [12050 + random 450 - 225, 12650 + random 450 - 225, 0],
                    [11150 + random 600 - 300, 13400 + random 600 - 300, 0]
                ];
                {
                    if (alive _x) then {
                        _x enableAI "MOVE";
                        _x enableAI "PATH";
                        _x setBehaviour "COMBAT";
                        _x setCombatMode "RED";
                        if (vehicle _x == _x) then { _x doMove _patrolPos };
                    };
                } forEach _live;
                private _veh = vehicle (leader _grp);
                if (_veh != leader _grp) then { driver _veh doMove _patrolPos };
            };
            continue;
        };

        private _sortedTargets = [_nearTargets, [], { _x distance2D _anchor }, "ASCEND"] call BIS_fnc_sortBy;
        private _targetUnit = selectRandom (_sortedTargets select [0, ((count _sortedTargets) min 4)]);
        private _target = if (vehicle _targetUnit == _targetUnit) then { _targetUnit } else { vehicle _targetUnit };

        _grp setCombatMode "RED";

        {
            if (alive _x) then {
                _x reveal [_target, 4];
                _x doWatch _target;
                _x doTarget _target;
                _x doFire _target;
                _x setCombatMode "RED";
                _x setBehaviour "COMBAT";
                _x allowFleeing 0;

                if (vehicle _x == _x) then {
                    if ((_x distance2D _target) > 90) then { _x doMove (getPosATL _target) };
                    private _weapon = currentWeapon _x;
                    if (_weapon != "") then {
                        _x fireAtTarget [_target, _weapon];
                    } else {
                        _x fireAtTarget [_target];
                    };
                };
            };
        } forEach _live;

        private _vehicles = [];
        {
            private _veh = vehicle _x;
            if (_veh != _x && { !(_veh in _vehicles) }) then { _vehicles pushBack _veh };
        } forEach _live;

        {
            private _veh = _x;
            if (!alive _veh) then { continue };
            _veh setVehicleReceiveRemoteTargets true;
            _veh setVehicleReportRemoteTargets true;

            private _gunner = gunner _veh;
            if (!isNull _gunner && { alive _gunner }) then {
                _gunner reveal [_target, 4];
                _gunner doWatch _target;
                _gunner doTarget _target;
                _gunner doFire _target;
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
        } forEach _vehicles;
    } forEach allGroups;
};
