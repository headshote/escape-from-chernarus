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
    private _nearRus = (getPosATL _player nearEntities [["Man"], 350]) select {
        alive _x && vehicle _x == _x &&
        ((group _x) getVariable ["CO_faction", ""]) == "RUS_ADV"
    };
    {
        _x reveal [_player, 4];
        _x doTarget _player;
        _x doFire _player;
        _x fireAtTarget [_player, currentWeapon _x];
        _x setCombatMode "RED";
    } forEach _nearRus;

    // Also pull mounted vehicle gunners on RUS_ADV vehicles into engagement.
    private _nearRusVeh = (getPosATL _player nearEntities [["Car","Tank","Wheeled_APC_F","Tracked_APC"], 450]) select {
        alive _x &&
        ((group (effectiveCommander _x)) getVariable ["CO_faction", ""]) == "RUS_ADV"
    };
    {
        private _v = _x;
        {
            if (alive _x) then {
                _x reveal [_player, 4];
                _x doTarget _player;
                _x fireAtTarget [_player];
            };
        } forEach (crew _v);
    } forEach _nearRusVeh;

    sleep 5;
};
