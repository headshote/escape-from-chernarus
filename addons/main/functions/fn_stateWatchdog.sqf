// ============================================================
// fn_stateWatchdog.sqf — stuck-state recovery loop (server-side)
//
// Repair plan R1-d. SQF has no try/finally: when a chase thread
// dies on a runtime error, the sticky state it set is never
// cleared — the patrol brain skips forever, the car keeps
// forceSpeed 0 in the middle of the road, and the target's
// broadcast CO_captureInProgress makes every aggression system
// on the map ignore them for the rest of the session (audit
// finding R2-3, the master cause of "nobody ever tried me").
//
// This loop runs every 30 s. For each suspicious condition it
// records when it FIRST saw it; if the condition persists past
// the owner's maximum legitimate lifetime, it repairs the state
// and logs a [CO][WATCHDOG] line. A healthy session logs zero
// watchdog lines — every line in the RPT is a real bug to chase.
//
// Recovered conditions and their grace periods:
//   CO_captureInProgress on a free unit ....... 180 s
//   CO_wrangleActive stale lock ............... 60 s
//   CO_policeFootChaseActive / vehiclePursuit . 480 s
//   CO_responseActive without a chase flag .... 90 s
//   CO_grpEngaging ............................ 300 s
//   bus stuck in dismounted/reboarding ........ 300 s
//   police car parked with no active chase .... 150 s
// ============================================================

if (!isServer) exitWith {};
if (missionNamespace getVariable ["CO_stateWatchdogRunning", false]) exitWith {};
CO_stateWatchdogRunning = true;

[] spawn {
    private _seen = createHashMap;

    // _check: returns true when the condition has persisted past _limit.
    // Deletes the timer when the condition cleared on its own.
    private _check = {
        params ["_key", "_active", "_limit"];
        if (!_active) exitWith {
            _seen deleteAt _key;
            false
        };
        private _first = _seen getOrDefault [_key, -1];
        if (_first < 0) then {
            _seen set [_key, time];
            _first = time;
        };
        if ((time - _first) > _limit) exitWith {
            _seen deleteAt _key;
            true
        };
        false
    };

    while { true } do {
        sleep 30;

        // ---- 0. Escalation expiry + heat decay (server-authoritative,
        // repair R2-a / audit R2-17). The old client-side decay in
        // fn_getEscalationState only ran inside the local player's HUD
        // loop, so states never expired on a dedicated server.
        {
            private _p = _x;
            if (!alive _p) then { continue };

            private _state = _p getVariable ["CO_escalationState", "UNAWARE"];
            private _until = _p getVariable ["CO_escalationUntil", 0];
            if (!(_state in ["UNAWARE", "CLEAR"]) && time > _until) then {
                [_p, "CLEAR", "expired", 0, grpNull] call co_main_fnc_setEscalationState;
                _state = "CLEAR";
            };

            if (_state in ["UNAWARE", "CLEAR"]) then {
                private _heat = _p getVariable ["CO_heatLevel", 0];
                if (_heat > 0) then {
                    // 30 s tick → half of the per-minute decay rate.
                    private _decay = (missionNamespace getVariable ["CO_heat_decayPerMinute", 5]) * 0.5;
                    _p setVariable ["CO_heatLevel", (_heat - _decay) max 0, true];
                };
            };
        } forEach allPlayers;

        // ---- 1. Ghost targets: stuck CO_captureInProgress ------------
        // A unit flagged in-progress but free (not captive, not KO'd,
        // not mid-wrangle, not inside a transport) is invisible to every
        // aggression system. Players checked always; NPC civs via a
        // bounded allUnits sweep.
        private _suspects = allPlayers + (allUnits select {
            side _x == civilian && !isPlayer _x &&
            (_x getVariable ["CO_captureInProgress", false])
        });
        {
            private _u = _x;
            private _stuck = alive _u &&
                (_u getVariable ["CO_captureInProgress", false]) &&
                !captive _u &&
                !(_u getVariable ["CO_knockedOut", false]) &&
                isNull (objectParent _u) &&
                ((time - (_u getVariable ["CO_wrangleActive", 0])) > 30);
            if ([format ["cip_%1", netId _u], _stuck, 180] call _check) then {
                _u setVariable ["CO_captureInProgress", false, true];
                ["watchdog_recovery"] call co_main_fnc_kpi;
                diag_log format ["[CO][WATCHDOG] Cleared stuck CO_captureInProgress on %1.", _u];
            };

            // Stale wrangle lock (dialog thread died on the client).
            private _wLock = _u getVariable ["CO_wrangleActive", 0];
            if ([format ["wl_%1", netId _u], (_wLock > 0 && (time - _wLock) > 30), 60] call _check) then {
                _u setVariable ["CO_wrangleActive", 0, false];
                ["watchdog_recovery"] call co_main_fnc_kpi;
                diag_log format ["[CO][WATCHDOG] Cleared stale wrangle lock on %1.", _u];
            };
        } forEach _suspects;

        // ---- 2. Police groups: dead chase flags + parked cars --------
        {
            private _grp = _x;
            if ((_grp getVariable ["CO_faction", ""]) != "POLICE") then { continue };
            if (({ alive _x } count units _grp) == 0) then { continue };
            private _gid = format ["pol_%1", groupId _grp];
            private _car = _grp getVariable ["CO_policePatrolCar", objNull];

            private _chasing =
                (_grp getVariable ["CO_policeFootChaseActive", false]) ||
                (_grp getVariable ["CO_vehiclePursuitActive", false]);

            if ([_gid + "_chase", _chasing, 480] call _check) then {
                _grp setVariable ["CO_policeFootChaseActive", false, false];
                _grp setVariable ["CO_vehiclePursuitActive", false, false];
                if (!isNull _car) then { _car setVariable ["CO_responseActive", false, true] };
                [_grp, _car] call co_main_fnc_policeResumePatrol;
                ["watchdog_recovery"] call co_main_fnc_kpi;
                diag_log format ["[CO][WATCHDOG] Reset dead chase flags on %1.", _grp];
            };

            // Siren stuck on with no chase running.
            if (!isNull _car) then {
                private _sirenGhost = alive _car &&
                    (_car getVariable ["CO_responseActive", false]) && !_chasing;
                if ([_gid + "_fx", _sirenGhost, 90] call _check) then {
                    _car setVariable ["CO_responseActive", false, true];
                    ["watchdog_recovery"] call co_main_fnc_kpi;
                    diag_log format ["[CO][WATCHDOG] Cleared ghost siren on %1.", _car];
                };

                // Car parked dead with no chase: forceSpeed leak or lost
                // waypoints. Ignore cars with a live driver-less state —
                // resumePatrol handles reboarding too.
                private _parked = alive _car && !_chasing &&
                    (abs (speed _car)) < 1 &&
                    ({ alive _x } count units _grp) > 0;
                if ([_gid + "_park", _parked, 150] call _check) then {
                    [_grp, _car] call co_main_fnc_policeResumePatrol;
                    ["watchdog_recovery"] call co_main_fnc_kpi;
                    diag_log format ["[CO][WATCHDOG] Un-parked police car %1 at %2.", _car, mapGridPosition _car];
                };
            };
        } forEach allGroups;

        // ---- 3. Generic group engagement flags ------------------------
        {
            private _grp = _x;
            private _engaging = (_grp getVariable ["CO_grpEngaging", false]) &&
                                ({ alive _x } count units _grp) > 0;
            if ([format ["eng_%1", groupId _grp], _engaging, 300] call _check) then {
                _grp setVariable ["CO_grpEngaging", false, false];
                ["watchdog_recovery"] call co_main_fnc_kpi;
                diag_log format ["[CO][WATCHDOG] Cleared stuck CO_grpEngaging on %1.", _grp];
            };
        } forEach allGroups;

        // ---- 4. Buses frozen mid-state --------------------------------
        {
            private _grp = _x;
            if (!(_grp getVariable ["CO_isBusEscortGrp", false])) then { continue };
            private _bus = _grp getVariable ["CO_transportVehicle", objNull];
            if (isNull _bus || !alive _bus) then { continue };
            private _state = _bus getVariable ["CO_busState", "traveling"];
            private _frozen = _state in ["dismounted", "reboarding"];
            if ([format ["bus_%1", netId _bus], _frozen, 300] call _check) then {
                _bus setVariable ["CO_busState", "traveling", true];
                _bus forceSpeed -1;
                _bus engineOn true;
                private _drv = driver _bus;
                if (!isNull _drv && alive _drv) then {
                    _drv enableAI "MOVE";
                    _drv enableAI "PATH";
                    _drv setBehaviour "SAFE";
                };
                ["watchdog_recovery"] call co_main_fnc_kpi;
                diag_log format ["[CO][WATCHDOG] Unfroze bus %1 from state '%2'.", netId _bus, _state];
            };
        } forEach allGroups;
    };
};
