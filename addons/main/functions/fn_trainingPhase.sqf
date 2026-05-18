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

        while {
            alive _c &&
            ((_c getVariable ["CO_detainPhase", ""]) == "training")
        } do {
            sleep 2;
            if (!alive _c) exitWith {};

            private _d = _c distance2D CO_airfieldCenter;
            if (_d > _escapeRadius) then {
                if (!_outside) then {
                    _outside = true;
                    _c setCaptive false;
                    _c setVariable ["CO_hotHostile", time + 120, true];
                    _c setVariable ["CO_trainingEscape", true, true];
                    diag_log format [
                        "[CO] Training escape: %1 left airfield at %2 — guards lethal.",
                        name _c, mapGridPosition _c
                    ];
                    if (isPlayer _c) then {
                        ["CONSCRIPT ESCAPING — GUARDS WILL OPEN FIRE"] remoteExec ["hint", _c];
                    };
                };
                // Force every nearby CRN_ENF guard to engage the
                // escaping conscript. fireAtTarget bypasses side
                // relations and the fn_installNonLethalDamage
                // handler is NOT installed on the player at this
                // point, so hits are lethal.
                private _shooters = (CO_airfieldCenter nearEntities [["Man"], 600]) select {
                    alive _x &&
                    vehicle _x == _x &&
                    ((group _x) getVariable ["CO_faction", ""]) == "CRN_ENF"
                };
                {
                    _x reveal [_c, 4];
                    _x doWatch _c;
                    _x doTarget _c;
                    _x fireAtTarget [_c];
                    _x setCombatMode "RED";
                    _x setBehaviour "AWARE";
                } forEach _shooters;
            } else {
                if (_outside) then {
                    // Came back inside — re-arm protection.
                    _outside = false;
                    _c setCaptive true;
                    _c setVariable ["CO_hotHostile", 0, true];
                    _c setVariable ["CO_trainingEscape", false, true];
                    {
                        if (alive _x) then { _x doWatch objNull };
                    } forEach ((CO_airfieldCenter nearEntities [["Man"], 600]) select {
                        ((group _x) getVariable ["CO_faction", ""]) == "CRN_ENF"
                    });
                };
            };
        };
    };
};

// 10-minute window — if still captive, ship to front
_conscript setVariable ["CO_trainingStartTime", time, false];

[{
    params ["_c", "_trainTime"];
    !(captive _c) || time > (_c getVariable ["CO_trainingStartTime", 0]) + _trainTime
}, {
    params ["_c"];
    if (captive _c) then {
        [_c] call co_main_fnc_deployToFront;
    };
}, [_conscript, _trainTime]] call CBA_fnc_waitUntilAndExecute;