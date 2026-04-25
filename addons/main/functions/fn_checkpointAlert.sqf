params ["_detectedUnits", "_hostileGrp"];

{
    private _target = _x;
    if (!(isPlayer _target) && side _target != civilian) then { continue };

    // Order whole group to move on target
    {
        _x doTarget _target;
        _x doMove (getPosATL _target);
        _x setCombatMode "RED";
        _x setBehaviour "COMBAT";
    } forEach units _hostileGrp;

    // Capture check loop — run on server
    [_target, _hostileGrp] spawn {
        params ["_target", "_grp"];
        private _captured = false;
        while { alive _target && !captive _target } do {
            private _nearest = [units _grp, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
            if ((_nearest select 0) distance _target < 2.5) then {
                // Trigger wrangle minigame on the player's machine
                [_target] remoteExecCall ["co_main_fnc_wrangleMinigame", _target];
                waitUntil { !isNil { _target getVariable "CO_wrangleResult" } };
                private _result = _target getVariable ["CO_wrangleResult", "captured"];
                _target setVariable ["CO_wrangleResult", nil, true];

                if (_result == "captured") then {
                    _target setCaptive true;
                    [_target, _grp] call co_main_fnc_transportToDetention;
                    _captured = true;
                };
            };
            sleep 0.5;
        };
    };
} forEach _detectedUnits;