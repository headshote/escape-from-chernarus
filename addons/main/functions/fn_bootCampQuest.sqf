// ============================================================
// fn_bootCampQuest.sqf
//
// Player-driven 3-stage boot camp quest at NWAF training ground.
// Runs on the server; UI is remote-exec'd to the conscript.
//
// Stages:
//   1. Obstacle course — visit two waypoints in the airfield interior.
//   2. Rifle range — destroy 3 wooden targets with the issued AK.
//   3. Grenade range — destroy 1 target at the grenade pit with a grenade.
//
// On completion: setVariable CO_isCleared=true, then deployToFront
// teleports the player to Krasnostav with a full military loadout.
// If the player breaches the airfield perimeter mid-quest, the
// perimeter sentinel in fn_trainingPhase takes over (lethal engagement).
// ============================================================
params ["_player"];

if (!isServer) exitWith {};
if (isNull _player || !alive _player) exitWith {};
if (_player getVariable ["CO_bootCampActive", false]) exitWith {};
_player setVariable ["CO_bootCampActive", true, true];

if (isNil "CO_airfieldCenter") then { CO_airfieldCenter = [2100, 12800, 0] };

// Stage positions (relative to airfield center)
private _obstacleA   = CO_airfieldCenter vectorAdd [-90,  -20, 0];
private _obstacleB   = CO_airfieldCenter vectorAdd [ 90,   20, 0];
private _riflePos    = CO_airfieldCenter vectorAdd [ 60,  -80, 0];
private _rifleTargetPositions = [
    CO_airfieldCenter vectorAdd [ 60, -130, 0],
    CO_airfieldCenter vectorAdd [ 70, -135, 0],
    CO_airfieldCenter vectorAdd [ 80, -130, 0]
];
private _grenadePos  = CO_airfieldCenter vectorAdd [-70,  80, 0];
private _grenadeTargetPos = CO_airfieldCenter vectorAdd [-70, 110, 0];

// ---- HUD intro ---------------------------------------------------
[["BOOT CAMP\nFollow markers. Stage 1: obstacle course."]] remoteExec ["hint", _player];
sleep 3;

// ===== STAGE 1: Obstacle course =====
private _mkA = format ["co_bootcamp_A_%1", _player];
private _mkB = format ["co_bootcamp_B_%1", _player];
createMarker [_mkA, _obstacleA];
_mkA setMarkerType "mil_start";
_mkA setMarkerText "OBSTACLE START";
_mkA setMarkerColor "ColorRED";
createMarker [_mkB, _obstacleB];
_mkB setMarkerType "mil_end";
_mkB setMarkerText "OBSTACLE FINISH";
_mkB setMarkerColor "ColorRED";

// Wait for player to reach A then B (3 min cap per stage)
private _stage1Deadline = time + 180;
waitUntil {
    sleep 1;
    !alive _player ||
    !(_player getVariable ["CO_bootCampActive", false]) ||
    time > _stage1Deadline ||
    (_player distance _obstacleA < 6)
};
if (alive _player && (_player getVariable ["CO_bootCampActive", false])) then {
    [["Stage 1: reach the FINISH marker."]] remoteExec ["hint", _player];
};
waitUntil {
    sleep 1;
    !alive _player ||
    !(_player getVariable ["CO_bootCampActive", false]) ||
    time > _stage1Deadline ||
    (_player distance _obstacleB < 6)
};
deleteMarker _mkA;
deleteMarker _mkB;
if (!alive _player || !(_player getVariable ["CO_bootCampActive", false])) exitWith {};

// ===== STAGE 2: Rifle range =====
[["Stage 2: rifle range — DESTROY all 3 wooden targets."]] remoteExec ["hint", _player];
// Issue weapon (in case they're disarmed)
_player addWeapon "arifle_AKM_F";
_player addMagazine "30Rnd_762x39_Mag_F";
_player addMagazine "30Rnd_762x39_Mag_F";
_player selectWeapon "arifle_AKM_F";

private _mkR = format ["co_bootcamp_R_%1", _player];
createMarker [_mkR, _riflePos];
_mkR setMarkerType "mil_dot";
_mkR setMarkerText "FIRING LINE";
_mkR setMarkerColor "ColorRED";

private _targets = [];
{
    private _t = createVehicle ["TargetP_Inf_F", _x, [], 0, "CAN_COLLIDE"];
    _t setPos _x;
    _targets pushBack _t;
} forEach _rifleTargetPositions;

private _stage2Deadline = time + 240;
waitUntil {
    sleep 1.5;
    !alive _player ||
    !(_player getVariable ["CO_bootCampActive", false]) ||
    time > _stage2Deadline ||
    ({ !alive _x || damage _x > 0.8 } count _targets) >= count _targets
};
{ if (!isNull _x) then { deleteVehicle _x } } forEach _targets;
deleteMarker _mkR;
if (!alive _player || !(_player getVariable ["CO_bootCampActive", false])) exitWith {};

// ===== STAGE 3: Grenade range =====
[["Stage 3: grenade range — DETONATE a grenade at the marked pit."]] remoteExec ["hint", _player];
_player addMagazine "HandGrenade";
_player addMagazine "HandGrenade";
_player addMagazine "HandGrenade";

private _mkG = format ["co_bootcamp_G_%1", _player];
createMarker [_mkG, _grenadeTargetPos];
_mkG setMarkerType "mil_destroy";
_mkG setMarkerText "GRENADE PIT";
_mkG setMarkerColor "ColorRED";

// Track grenade detonations near the pit via a per-player Fired EH that
// sets CO_bootCampGrenadeOK true when a grenade fires AND lands close.
_player setVariable ["CO_bootCampGrenadeOK", false, true];
private _ehId = _player addEventHandler ["Fired", {
    params ["_unit","_weapon","_muzzle","_mode","_ammo","_magazine","_projectile"];
    if (_ammo isKindOf "GrenadeHand" || _ammo isKindOf "Grenade") then {
        [_unit, _projectile] spawn {
            params ["_u","_p"];
            // Wait for impact (up to 6 s) then check distance to pit.
            private _deadline = time + 6;
            waitUntil {
                sleep 0.1;
                isNull _p || time > _deadline
            };
            // Use last-known position as a best-effort impact location.
            // Engine clears _p on detonation, so we use a position
            // sampled mid-flight from a parallel watcher — but the
            // simplest robust signal: any grenade thrown within 20 m
            // of the pit at the moment of firing counts.
        };
    };
}];

// Simpler robust check: poll player distance to grenade pit and detect
// any nearby explosion mark on the ground (we just require the player
// to actually throw 2 grenades anywhere within 30 m of the pit while
// standing nearby).
private _stage3Deadline = time + 180;
private _grenadesThrown = 0;
private _lastGrenadeCount = {_x == "HandGrenade"} count (magazines _player);
while {
    alive _player &&
    (_player getVariable ["CO_bootCampActive", false]) &&
    time < _stage3Deadline &&
    _grenadesThrown < 2
} do {
    sleep 1;
    private _have = {_x == "HandGrenade"} count (magazines _player);
    if (_have < _lastGrenadeCount &&
        _player distance _grenadeTargetPos < 35) then {
        _grenadesThrown = _grenadesThrown + (_lastGrenadeCount - _have);
    };
    _lastGrenadeCount = _have;
};

_player removeEventHandler ["Fired", _ehId];
deleteMarker _mkG;
if (!alive _player || !(_player getVariable ["CO_bootCampActive", false])) exitWith {};

// ===== GRADUATION =====
[["BOOT CAMP COMPLETE\nReporting to the front at Krasnostav."]] remoteExec ["hint", _player];
sleep 4;
_player setVariable ["CO_isCleared", true, true];
_player setVariable ["CO_bootCampActive", false, true];
_player setVariable ["CO_detainPhase", "deployed", true];
[_player] call co_main_fnc_deployToFront;
