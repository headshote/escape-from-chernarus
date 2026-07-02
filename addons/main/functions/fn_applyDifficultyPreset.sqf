// ============================================================
// fn_applyDifficultyPreset.sqf
// Applies the cross-cutting tuning profile. Admin code can set
// CO_difficultyPreset to "Quiet Occupation", "Standard", or
// "Martial Law" and call this again.
// ============================================================
if (!isServer) exitWith {};

private _preset = missionNamespace getVariable ["CO_difficultyPreset", "Standard"];

private _values = switch (_preset) do {
    case "Quiet Occupation": {
        [
            ["CO_suspicion_baseRate", 8],
            ["CO_police_carStopChance", 0.03],
            ["CO_search_duration", 90],
            ["CO_chase_speedCoef", 1.08],
            ["CO_chase_aiStaminaDrain", 0.5],
            ["CO_chase_tackleRange", 2.0],
            ["CO_chase_tackleTime", 1.8],
            ["CO_tracker_speedCoef", 1.12],
            ["CO_checkpoint_maxCount", 12],
            ["CO_border_innerJitter", 120],
            ["CO_heat_decayPerMinute", 8]
        ]
    };
    case "Martial Law": {
        [
            ["CO_suspicion_baseRate", 18],
            ["CO_police_carStopChance", 0.16],
            ["CO_search_duration", 210],
            ["CO_chase_speedCoef", 1.18],
            ["CO_chase_aiStaminaDrain", 0.32],
            ["CO_chase_tackleRange", 2.35],
            ["CO_chase_tackleTime", 1.2],
            ["CO_tracker_speedCoef", 1.30],
            ["CO_checkpoint_maxCount", 28],
            ["CO_border_innerJitter", 260],
            ["CO_heat_decayPerMinute", 3]
        ]
    };
    default {
        [
            ["CO_suspicion_baseRate", 12],
            ["CO_police_carStopChance", 0.08],
            ["CO_search_duration", 150],
            ["CO_chase_speedCoef", 1.12],
            ["CO_chase_aiStaminaDrain", 0.42],
            ["CO_chase_tackleRange", 2.2],
            ["CO_chase_tackleTime", 1.5],
            ["CO_tracker_speedCoef", 1.25],
            ["CO_checkpoint_maxCount", 20],
            ["CO_border_innerJitter", 200],
            ["CO_heat_decayPerMinute", 5]
        ]
    };
};

{
    missionNamespace setVariable [_x select 0, _x select 1, true];
} forEach _values;

diag_log format ["[CO] Difficulty preset applied: %1", _preset];
