params ["_detectedUnits", "_hostileGrp"];

{
    private _target = _x;
    if (!(isPlayer _target) && side _target != civilian) then { continue };
    if (_target getVariable ["CO_captureInProgress", false]) then { continue };

    // Female civilians are never targeted first
    if (_target getVariable ["CO_isFemale", false]) then { continue };

    // Don't re-detain a player who is already a cleared conscript
    // (military / front deployee). AWOL conscripts ARE fair game though.
    if (_target getVariable ["CO_isCleared", false] &&
        !(_target getVariable ["CO_isAWOL", false])) then { continue };

    // Don't engage anyone inside the training-camp safe zone — the
    // boot-camp script owns engagement decisions in that area.
    if (!isNil "CO_airfieldCenter" &&
        {_target distance2D CO_airfieldCenter < (CO_airfieldRadius + 20)} &&
        !(_target getVariable ["CO_isAWOL", false])) then { continue };

    _target setVariable ["CO_captureInProgress", true, true];

    // Install non-lethal damage handler so any gunfire from this group on
    // civilians/players is converted into stun + transport.
    [_target] call co_main_fnc_installNonLethalDamage;

    // Check crowd resistance first
    [getPosATL _target, _hostileGrp, _target] call co_main_fnc_crowdResistance;

    // Order whole group to move on target. Guards close to melee range
    // first; if the target is still > 25 m after a beat, they're cleared
    // to open fire (handled by setting COMBAT/RED + revealing the target).
    {
        if (_x getVariable ["CO_vehicleChaseDriver", false]) then { continue };
        _x doTarget _target;
        _x doMove (getPosATL _target);
        _x setCombatMode "RED";
        _x setBehaviour "COMBAT";
        _x reveal [_target, 4];
        // Friendly side relations would block engine fire; clearing the
        // captive flag plus an explicit doFire on long-range targets is
        // applied inside the capture loop below.
    } forEach units _hostileGrp;

    // Capture check loop — run on server
    [_target, _hostileGrp] spawn {
        params ["_target", "_grp"];
        private _finished = false;

        while { alive _target && !captive _target && !_finished } do {
            private _liveUnits = units _grp select {
                alive _x &&
                !(_x getVariable ["CO_vehicleChaseDriver", false]) &&
                vehicle _x == _x
            };
            if (count _liveUnits == 0) exitWith {}; // all guards killed
            private _nearest = [_liveUnits, [], { _x distance _target }, "ASCEND"] call BIS_fnc_sortBy;
            private _closest = _nearest select 0;
            private _dist = _closest distance _target;

            // Long-range: explicitly order the closest guards to fire at the
            // target. fireAtTarget bypasses engine side-relations (civilians
            // are setFriend west = 1), and fn_installNonLethalDamage on the
            // target converts each hit into stun + scripted knockout.
            if (_dist > 12) then {
                private _shooters = _nearest select [0, (3 min count _nearest)];
                {
                    _x reveal [_target, 4];
                    _x doWatch _target;
                    _x setCombatMode "RED";
                    _x fireAtTarget [_target];
                } forEach _shooters;
            };

            if (_closest distance _target < 2.5) then {
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
                        // TCK (CRN_ENF) ships players directly to TRAINING via
                        // a dedicated truck. Police / other factions still use
                        // the bus-or-van detention path.
                        private _grpFac = _grp getVariable ["CO_faction", ""];
                        if (_grpFac == "CRN_ENF") then {
                            [_target, _grp] spawn co_main_fnc_spawnCaptureTransport;
                        } else {
                            [_target, _grp] call co_main_fnc_transportToDetention;
                        };
                        _finished = true;
                    };
                    // Escaped: give brief head-start
                    if (!_finished) then {
                        sleep 3;
                        _finished = true;
                    };
                } else {
                    // NPC civilian: punch them down so the swing animation
                    // plays on every viewer, then haul them off when they drop.
                    private _attacker = _nearest select 0;
                    [_attacker, _target] call co_main_fnc_applyMeleeHit;
                    if (_target getVariable ["CO_knockedOut", false]) then {
                        _target setCaptive true;
                        [_target, _grp] call co_main_fnc_transportToDetention;
                        _finished = true;
                    };
                };
            };
            sleep 0.5;
        };

        _target setVariable ["CO_captureInProgress", false, true];
    };
} forEach _detectedUnits;