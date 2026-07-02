// ============================================================
// fn_kpi.sqf
// Lightweight server-side counters for tuning chase catch/loss rates.
// params: [_key, _delta]
// ============================================================
params [
    ["_key", "unknown"],
    ["_delta", 1]
];

if (!isServer) exitWith {};
if (isNil "CO_kpiCounters") then { CO_kpiCounters = createHashMap };

private _cur = CO_kpiCounters getOrDefault [_key, 0];
CO_kpiCounters set [_key, _cur + _delta];

private _next = missionNamespace getVariable ["CO_kpiNextLogAt", 0];
if (time > _next) then {
    missionNamespace setVariable ["CO_kpiNextLogAt", time + (missionNamespace getVariable ["CO_kpiLogInterval", 120]), false];
    private _footStarted = CO_kpiCounters getOrDefault ["police_foot_chase_started", 0];
    private _vehicleStarted = CO_kpiCounters getOrDefault ["vehicle_chase_started", 0];
    private _started = _footStarted + _vehicleStarted;
    private _caught = (CO_kpiCounters getOrDefault ["police_foot_chase_caught", 0]) +
                      (CO_kpiCounters getOrDefault ["qa_police_caught", 0]);
    private _lost = CO_kpiCounters getOrDefault ["police_foot_chase_lost", 0];
    private _watchdog = CO_kpiCounters getOrDefault ["watchdog_recovery", 0];
    private _catchRate = if (_started > 0) then { round ((_caught / _started) * 100) } else { 0 };
    private _lostRate = if (_started > 0) then { round ((_lost / _started) * 100) } else { 0 };
    diag_log format [
        "[CO][KPI] counters=%1 rates=[started:%2 caught:%3 lost:%4 catchRate:%5%% lostRate:%6%% watchdog:%7]",
        CO_kpiCounters,
        _started,
        _caught,
        _lost,
        _catchRate,
        _lostRate,
        _watchdog
    ];
};
