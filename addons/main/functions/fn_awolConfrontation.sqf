// ============================================================
// fn_awolConfrontation.sqf — point-blank fate roll for deserters
// (server-side singleton loop)
//
// Observed problem: an AWOL player who deliberately closed with
// border guards was stared at for a few seconds and then executed
// point-blank — always. Execution is legitimate totalitarian
// flavor, but it should not be the only outcome.
//
// New doctrine: when armed CRN_ENF/POLICE stand within grabbing
// range of a live AWOL for a sustained moment, the squad decides
// the deserter's fate ONCE (per confrontation):
//
//   CO_awol_detainChance (default 0.5) → DETAIN:
//     cease fire, knock out, wipe the deserter's AWOL/cleared/
//     graduate/escape flags, and dispatch the standard capture
//     transport — which delivers to NWAF and restarts
//     fn_trainingPhase. The conscription loop is fully cyclical:
//     train → desert → get caught → train again, forever.
//
//   otherwise → EXECUTE: a deliberate point-blank volley (the
//     engine sometimes dithers at zero range; we force the shot).
//
// The fate is remembered on the player for 60 s so one squad
// doesn't flip-flop mid-confrontation; surviving an execution and
// escaping re-rolls the dice at the next confrontation.
// ============================================================
if (!isServer) exitWith {};
if (missionNamespace getVariable ["CO_awolConfrontationRunning", false]) exitWith {};
CO_awolConfrontationRunning = true;

[] spawn {
    while { true } do {
        sleep 2;

        {
            private _p = _x;
            if (
                alive _p &&
                (_p getVariable ["CO_isAWOL", false]) &&
                !captive _p &&
                !(_p getVariable ["CO_knockedOut", false]) &&
                isNull (objectParent _p)
            ) then {

                // Armed security within grabbing range?
                private _close = ((getPosATL _p) nearEntities [["Man"], 12]) select {
                    alive _x &&
                    vehicle _x == _x &&
                    ((group _x) getVariable ["CO_faction", ""]) in ["CRN_ENF", "POLICE"] &&
                    currentWeapon _x != ""
                };

                if (_close isEqualTo []) then {
                    _p setVariable ["CO_awolCloseSince", -1, false];
                } else {
                    private _since = _p getVariable ["CO_awolCloseSince", -1];
                    if (_since < 0) then {
                        _since = time;
                        _p setVariable ["CO_awolCloseSince", time, false];
                    };

                    // Sustained contact (~2 s): decide the fate.
                    if ((time - _since) >= 2) then {
                        (_p getVariable ["CO_awolFate", ["", -999]]) params ["_fate", "_rolledAt"];
                        if (_fate == "" || (time - _rolledAt) > 60) then {
                            private _chance = missionNamespace getVariable ["CO_awol_detainChance", 0.5];
                            _fate = if ((random 1) < _chance) then { "detain" } else { "execute" };
                            _p setVariable ["CO_awolFate", [_fate, time], false];
                            // Executions must be able to kill: lift the
                            // non-lethal damage cap for a condemned deserter
                            // (broadcast — HandleDamage runs on the victim's
                            // machine). Cleared on detain and on respawn.
                            _p setVariable ["CO_awolExecution", _fate == "execute", true];
                            diag_log format [
                                "[CO] AWOL confrontation: %1 at %2 — squad decision: %3.",
                                name _p, mapGridPosition _p, _fate
                            ];
                        };

                        if (_fate == "detain") then {
                            // ---- Cease fire from every nearby hunter ----
                            {
                                if (alive _x &&
                                    ((group _x) getVariable ["CO_faction", ""]) in ["CRN_ENF", "POLICE"]) then {
                                    _x doWatch objNull;
                                    _x doTarget objNull;
                                    _x setCombatMode "YELLOW";
                                    _x setBehaviour "AWARE";
                                };
                            } forEach ((getPosATL _p) nearEntities [["Man"], 60]);

                            // ---- Wipe the deserter slate: back into the
                            // conscription pipeline, fully repeatable. ----
                            _p setVariable ["CO_awolExecution", false, true];
                            _p setVariable ["CO_isAWOL", false, true];
                            _p setVariable ["CO_isCleared", false, true];
                            _p setVariable ["CO_bootCampGraduated", false, true];
                            _p setVariable ["CO_bootCampActive", false, true];
                            _p setVariable ["CO_trainingEscape", false, true];
                            _p setVariable ["CO_hotHostile", 0, true];
                            _p setVariable ["CO_awolFate", ["", -999], false];
                            _p setVariable ["CO_awolCloseSince", -1, false];
                            [_p, "CLEAR", "awol_detained", 0, grpNull] call co_main_fnc_setEscalationState;

                            [objNull, _p, 30, true] call co_main_fnc_applyKnockout;
                            _p setCaptive true;

                            if (isPlayer _p) then {
                                ["They want you alive. Back to the training camp, deserter."] remoteExecCall ["systemChat", _p];
                            };
                            ["awol_detained"] call co_main_fnc_kpi;

                            [_p, group (_close select 0)] spawn co_main_fnc_spawnCaptureTransport;
                        } else {
                            // ---- Execution: make the point-blank volley
                            // deliberate instead of AI dithering. ----
                            private _nextVolley = _p getVariable ["CO_awolExecNextAt", 0];
                            if (time > _nextVolley) then {
                                _p setVariable ["CO_awolExecNextAt", time + 2.5, false];
                                {
                                    _x reveal [_p, 4];
                                    _x doTarget _p;
                                    _x setCombatMode "RED";
                                    _x fireAtTarget [_p];
                                } forEach (_close select [0, 2 min count _close]);
                                ["awol_executed_volley"] call co_main_fnc_kpi;
                            };
                        };
                    };
                };
            };
        } forEach allPlayers;
    };
};
