// fn_trainingPhase.sqf
params ["_conscript"];
private _isPlayer = isPlayer _conscript;
private _trainTime = missionNamespace getVariable ["CO_conscript_trainTime", 600];

_conscript setPos (CO_trainingFieldPos vectorAdd [random 60 - 30, random 60 - 30, 0]);
_conscript setVariable ["CO_detainPhase", "training", true];
// Player can walk around inside the camp; captive flag keeps the
// camp's CRN_ENF garrison from auto-engaging while they stay in
// bounds. The perimeter sentinel below revokes that protection
// (and orders guards to fire) the moment they breach the wire.
_conscript setCaptive true;

// Heavily guarded — extra guards already placed at airfield by buildAirfieldCamp
// No need to re-spawn; just ensure the captive knows they're at training
if (_isPlayer) then {
    [_conscript] remoteExecCall ["co_main_fnc_showTrainingHUD", _conscript];
    // Launch the structured boot-camp quest (3 stages). On completion
    // it sets CO_isCleared=true and calls deployToFront → Krasnostav.
    [_conscript] spawn co_main_fnc_bootCampQuest;
};

// ---- Perimeter escape sentinel -----------------------------
// Civilians are setFriend west=1 so guards won't autonomously
// engage even when the player flees. This thread monitors the
// player against the airfield perimeter; if they breach it
// while still flagged for training, it strips their captive
// status, flags them CO_hotHostile, and orders every nearby
// CRN_ENF unit to fire at them via fireAtTarget (which bypasses
// engine side-friendship). Re-arms if they come back inside.
if (isServer) then {
    [_conscript] spawn {
        params ["_c"];
        if (isNil "CO_airfieldCenter") then { CO_airfieldCenter = [2100, 12800, 0] };
        if (isNil "CO_airfieldRadius") then { CO_airfieldRadius = 350 };
        private _escapeRadius = CO_airfieldRadius + 30;
        private _outside = false;
        private _outsideSince = -1;

        while {
            alive _c &&
            ((_c getVariable ["CO_detainPhase", ""]) == "training")
        } do {
            sleep 1.5;
            if (!alive _c) exitWith {};

            private _d = _c distance2D CO_airfieldCenter;
            if (_d > _escapeRadius) then {
                if (!_outside) then {
                    _outside = true;
                    _outsideSince = time;
                    _c setCaptive false;
                    _c setVariable ["CO_hotHostile", time + 240, true];
                    _c setVariable ["CO_trainingEscape", true, true];
                    // Cancel the in-flight boot-camp quest — the
                    // conscript chose to run, no graduation for them.
                    _c setVariable ["CO_bootCampActive", false, true];
                    // After 20 s outside, escalate to permanent AWOL so
                    // every faction (police, border, RUS_ADV, TCK)
                    // engages lethally and recapture sends them to a
                    // proper detention center (not the training loop).
                    diag_log format [
                        "[CO] Training escape: %1 left airfield at %2 — guards lethal.",
                        name _c, mapGridPosition _c
                    ];
                    if (isPlayer _c) then {
                        ["CONSCRIPT ESCAPING \u2014 GUARDS WILL OPEN FIRE"] remoteExec ["hint", _c];
                    };
                };

                // Promote to full AWOL after 25 s outside the wire.
                if (_outsideSince > 0 && (time - _outsideSince) > 25 &&
                    !(_c getVariable ["CO_isAWOL", false])) then {
                    _c setVariable ["CO_isAWOL", true, true];
                    _c setVariable ["CO_detainPhase", "awol", true];
                    if (isPlayer _c) then {
                        ["DESERTER\nYou are now AWOL. Every faction will shoot to kill."] remoteExec ["hint", _c];
                    };
                };

                // Pursuit: every CRN_ENF unit within 900 m gets lethal
                // orders against the escapee and is pushed to run after
                // them. fireAtTarget bypasses engine side-friendship.
                private _shooters = (CO_airfieldCenter nearEntities [["Man"], 900]) select {
                    alive _x &&
                    vehicle _x == _x &&
                    ((group _x) getVariable ["CO_faction", ""]) == "CRN_ENF"
                };
                {
                    _x reveal [_c, 4];
                    _x doWatch _c;
                    _x doTarget _c;
                    _x doFire _c;
                    _x fireAtTarget [_c];
                    _x setCombatMode "RED";
                    _x setBehaviour "COMBAT";
                    _x setSpeedMode "FULL";
                    _x enableAI "MOVE";
                    _x enableAI "PATH";
                    _x allowFleeing 0;
                    // Send the 4 closest into a foot chase.
                    if (_x distance2D _c > 40) then { _x doMove (getPosATL _c) };
                } forEach _shooters;
            } else {
                if (_outside) then {
                    // Came back inside — only re-arm protection if NOT
                    // already flagged AWOL (AWOL is permanent).
                    if (!(_c getVariable ["CO_isAWOL", false])) then {
                        _outside = false;
                        _outsideSince = -1;
                        _c setCaptive true;
                        _c setVariable ["CO_hotHostile", 0, true];
                        _c setVariable ["CO_trainingEscape", false, true];
                        {
                            if (alive _x) then { _x doWatch objNull };
                        } forEach ((CO_airfieldCenter nearEntities [["Man"], 900]) select {
                            ((group _x) getVariable ["CO_faction", ""]) == "CRN_ENF"
                        });
                    };
                };
            };
        };
    };
};

// 10-minute window — if still captive AND boot-camp didn't graduate
// them, ship to front. CRITICAL: do NOT auto-deploy escapees (who
// have CO_trainingEscape / CO_isAWOL flags). The original condition
// `!captive _c` fired the moment the perimeter sentinel revoked the
// captive flag, which incorrectly graduated escapees.
_conscript setVariable ["CO_trainingStartTime", time, false];

[{
    params ["_c", "_trainTime"];
    if (!alive _c) exitWith { true };
    // Boot camp graduation calls deployToFront itself — nothing to do.
    if (_c getVariable ["CO_isCleared", false]) exitWith { true };
    // Escapees are NEVER auto-deployed.
    if (_c getVariable ["CO_trainingEscape", false]) exitWith { true };
    if (_c getVariable ["CO_isAWOL", false]) exitWith { true };
    // Only auto-deploy when the full training window elapses with the
    // player still inside the wire and still in training phase.
    time > (_c getVariable ["CO_trainingStartTime", 0]) + _trainTime
}, {
    params ["_c"];
    if (!alive _c) exitWith {};
    if (_c getVariable ["CO_trainingEscape", false]) exitWith {};
    if (_c getVariable ["CO_isAWOL", false]) exitWith {};
    if (_c getVariable ["CO_isCleared", false]) exitWith {};
    [_c] call co_main_fnc_deployToFront;
}, [_conscript, _trainTime]] call CBA_fnc_waitUntilAndExecute;