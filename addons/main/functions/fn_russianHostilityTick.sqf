// ============================================================
// fn_russianHostilityTick.sqf
//
// Per-player loop spawned by fn_deployToFront. The player can't
// actually switch engine sides at runtime (mission slots bind them
// to civilian), so the Russian advance (east-side AI) never picks
// them up via engine relations. This script forces explicit
// reveal+fireAtTarget on any RUS_ADV unit that comes within range
// of a cleared conscript. fireAtTarget bypasses friend-rating and
// makes the AI engage regardless of engine side.
//
// Stops automatically when the player dies, leaves the cleared
// state, or goes AWOL (AWOL has its own hostility system).
// ============================================================
params ["_player"];
if (!isServer) exitWith {};
if (isNull _player) exitWith {};

while {
    alive _player &&
    (_player getVariable ["CO_isCleared", false]) &&
    !(_player getVariable ["CO_isAWOL", false])
} do {
    // Round-9 throttle: limit to the 5 nearest RUS_ADV foot soldiers
    // and 2 nearest RUS_ADV vehicles, ticking at 8s instead of 5s.
    // Previously every RUS_ADV in 350 m (potentially dozens after a
    // few waves) received reveal/doTarget/doFire/fireAtTarget every
    // 5 s — a massive network/command-queue spam contributing to the
    // Krasnostav FPS drop.
    private _nearRus = (getPosATL _player nearEntities [["Man"], 350]) select {
        alive _x && vehicle _x == _x &&
        ((group _x) getVariable ["CO_faction", ""]) == "RUS_ADV"
    };
    private _nearRusSorted = [_nearRus, [], { _x distance _player }, "ASCEND"] call BIS_fnc_sortBy;
    private _topRus = _nearRusSorted select [0, 5];
    {
        _x reveal [_player, 4];
        _x doTarget _player;
        _x doFire _player;
        _x fireAtTarget [_player, currentWeapon _x];
        _x setCombatMode "RED";
    } forEach _topRus;

    // Also pull mounted vehicle gunners on RUS_ADV vehicles into engagement.
    private _nearRusVeh = (getPosATL _player nearEntities [["Car","Tank","Wheeled_APC_F","Tracked_APC"], 450]) select {
        alive _x &&
        ((group (effectiveCommander _x)) getVariable ["CO_faction", ""]) == "RUS_ADV"
    };
    private _nearRusVehSorted = [_nearRusVeh, [], { _x distance _player }, "ASCEND"] call BIS_fnc_sortBy;
    private _topVeh = _nearRusVehSorted select [0, 2];
    {
        private _v = _x;
        {
            if (alive _x) then {
                _x reveal [_player, 4];
                _x doTarget _player;
                _x fireAtTarget [_player];
            };
        } forEach (crew _v);
    } forEach _topVeh;

    sleep 8;
};
