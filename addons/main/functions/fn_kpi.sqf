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
    diag_log format ["[CO][KPI] %1", CO_kpiCounters];
};
