params ["_detectedUnits", "_hostileGrp"];

{
    private _target = _x;
    if (!(isPlayer _target) && side _target != civilian) then { continue };
    if (_target getVariable ["CO_captureInProgress", false]) then { continue };

    // Female civilians are never targeted first
    if (_target getVariable ["CO_isFemale", false]) then { continue };

    _target setVariable ["CO_captureInProgress", true, true];

    // Check crowd resistance first
    [getPosATL _target, _hostileGrp, _target] call co_main_fnc_crowdResistance;

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
        private _finished = false;

        while { alive _target && !captive _target && !_finished } do {
            private _liveUnits = units _grp select { alive _x };
            if (count _liveUnits == 0) exitWith {}; // all guards killed
            private _nearest = [_liveUnits, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
            if ((_nearest select 0) distance _target < 2.5) then {
                // Increase wanted level
                private _wl = (_target getVariable ["CO_wantedLevel", 0]) + 30;
                _target setVariable ["CO_wantedLevel", _wl min 100, true];

                // Trigger wrangle minigame on the player's machine
                if (isPlayer _target) then {
                    [_target] remoteExecCall ["co_main_fnc_wrangleMinigame", _target];
                    waitUntil { sleep 0.3; !isNil { _target getVariable "CO_wrangleResult" } };
                    private _result = _target getVariable ["CO_wrangleResult", "captured"];
                    _target setVariable ["CO_wrangleResult", nil, true];

                    if (_result == "captured") then {
                        _target setCaptive true;
                        [_target, _grp] call co_main_fnc_transportToDetention;
                        _finished = true;
                    };
                    // Escaped: give brief head-start
                    if (!_finished) then {
                        sleep 3;
                        _finished = true;
                    };
                } else {
                    // NPC civilian: auto-capture
                    _target setCaptive true;
                    [_target, _grp] call co_main_fnc_transportToDetention;
                    _finished = true;
                };
            };
            sleep 0.5;
        };

        _target setVariable ["CO_captureInProgress", false, true];
    };
} forEach _detectedUnits;