// ============================================================
// fn_bootCampQuest.sqf
//
// Player-driven 3-stage boot camp at the NWAF training ground.
// Server-authoritative; the Arma 3 Task system (BIS_fnc_taskCreate)
// drives the map UI and notifications. Tasks are owned by the
// individual conscript so co-op players each get their own quest.
//
// Stages:
//   1. Obstacle course — visit two waypoints inside the airfield.
//   2. Rifle range — pick up an AK from the weapon rack and destroy
//      3 pop-up wooden targets.
//   3. Grenade range — detonate 2 grenades inside the pit.
//
// On graduation: CO_isCleared=true (Russian advance starts engaging
// the player, every faction stops trying to detain them), then
// fn_deployToFront teleports the player to Krasnostav with a
// proper kit. If the player breaches the perimeter the trainingPhase
// sentinel takes over (lethal pursuit, no graduation).
// ============================================================
params ["_player"];

if (!isServer) exitWith {};
if (isNull _player || !alive _player) exitWith {};
if (_player getVariable ["CO_bootCampActive", false]) exitWith {};
_player setVariable ["CO_bootCampActive", true, true];
_player setVariable ["CO_bootCampGraduated", false, true];

if (isNil "CO_airfieldCenter") then { CO_airfieldCenter = [2100, 12800, 0] };
if (isNil "CO_trainingFieldPos") then { CO_trainingFieldPos = [2160, 12800, 0] };

// ----- Stage positions (relative to training-field anchor) ----------
// NWAF runway runs roughly east-west. Place the firing line on the
// flat apron and put the targets ~120 m WEST so the player has clear,
// downhill LOS over the open runway (the previous south-facing layout
// put targets in the wooded hill behind the airfield where LOS was
// blocked, breaking both the shoot and the hit-detection check).
private _obstacleA       = CO_airfieldCenter vectorAdd [-90,  -20, 0];
private _obstacleB       = CO_airfieldCenter vectorAdd [ 90,   20, 0];
// Rack sits at the firing-line sandbags (fn_buildTrainingGround places
// the visible sandbag line at x=+10). Targets go DOWNRANGE to the EAST
// of the existing static-target row (which is at ~x=+25..+37) so the
// quest targets are right behind / on the same axis as the visible
// training range and unmissable from the firing line. Previous round-8
// placement at x=-110 (west of CO_trainingFieldPos) was in obstructed
// off-runway terrain and players couldn't see the targets at all.
private _weaponRackPos   = CO_trainingFieldPos vectorAdd [ 10, -16, 0];
private _riflePos        = CO_trainingFieldPos vectorAdd [ 10, -20, 0];
private _rifleFireLine   = _riflePos;
private _rifleTargetPositions = [
    CO_trainingFieldPos vectorAdd [ 55, -24, 0],
    CO_trainingFieldPos vectorAdd [ 60, -20, 0],
    CO_trainingFieldPos vectorAdd [ 55, -16, 0]
];
private _grenadePos       = CO_trainingFieldPos vectorAdd [-30,  60, 0];
private _grenadeTargetPos = CO_trainingFieldPos vectorAdd [-30,  90, 0];

// ----- Markers + Task IDs -----
private _suffix = format ["%1", round (random 1e6)];
private _mkA = format ["co_bc_A_%1", _suffix];
private _mkB = format ["co_bc_B_%1", _suffix];
private _mkR = format ["co_bc_R_%1", _suffix];
private _mkG = format ["co_bc_G_%1", _suffix];

private _tStage1 = format ["co_bc_t1_%1", _suffix];
private _tStage2 = format ["co_bc_t2_%1", _suffix];
private _tStage3 = format ["co_bc_t3_%1", _suffix];

// Helper: BIS_fnc_taskCreate wrapper that targets a single owner.
private _fnc_makeTask = {
    params ["_owner", "_id", "_desc", "_title", "_dest", "_state", "_priority"];
    [
        [_owner],
        _id,
        [_desc, _title, ""],
        _dest,
        _state,
        _priority,
        true,
        "scout",
        true
    ] call BIS_fnc_taskCreate;
};

["BOOT CAMP\nCheck your map (M) for objectives.\nReport to the obstacle course."] remoteExec ["hint", _player];
sleep 2;

// =========================================================
// STAGE 1 — Obstacle course
// =========================================================
createMarker [_mkA, _obstacleA];
_mkA setMarkerType  "mil_start";
_mkA setMarkerText  "OBSTACLE START";
_mkA setMarkerColor "ColorBLUFOR";
createMarker [_mkB, _obstacleB];
_mkB setMarkerType  "mil_end";
_mkB setMarkerText  "OBSTACLE FINISH";
_mkB setMarkerColor "ColorBLUFOR";

[_player, _tStage1,
 "Run the obstacle course. Sprint to the START flag, then to the FINISH flag inside the airfield perimeter.",
 "1/3  Obstacle Course",
 _obstacleA, "ASSIGNED", 3
] call _fnc_makeTask;

private _stage1Deadline = time + 240;
waitUntil {
    sleep 1;
    !alive _player ||
    !(_player getVariable ["CO_bootCampActive", false]) ||
    time > _stage1Deadline ||
    (_player distance _obstacleA < 8)
};

if (alive _player && (_player getVariable ["CO_bootCampActive", false]) && time <= _stage1Deadline) then {
    [[_player], _tStage1, _obstacleB] call BIS_fnc_taskSetDestination;
    ["Halfway there — reach the FINISH flag."] remoteExec ["hint", _player];
    waitUntil {
        sleep 1;
        !alive _player ||
        !(_player getVariable ["CO_bootCampActive", false]) ||
        time > _stage1Deadline ||
        (_player distance _obstacleB < 8)
    };
};

deleteMarker _mkA;
deleteMarker _mkB;

if (!alive _player || !(_player getVariable ["CO_bootCampActive", false])) exitWith {
    [_player, _tStage1, "FAILED"] call BIS_fnc_taskSetState;
};
if (time > _stage1Deadline) then {
    [_player, _tStage1, "FAILED"] call BIS_fnc_taskSetState;
} else {
    [_player, _tStage1, "SUCCEEDED"] call BIS_fnc_taskSetState;
};

// =========================================================
// STAGE 2 — Rifle range (weapon rack pickup)
// =========================================================
createMarker [_mkR, _riflePos];
_mkR setMarkerType  "mil_dot";
_mkR setMarkerText  "FIRING LINE";
_mkR setMarkerColor "ColorBLUFOR";

[_player, _tStage2,
 "At the firing line, pick up a training rifle from the weapon rack (mouse-wheel action). Destroy ALL THREE wooden pop-up targets.",
 "2/3  Rifle Range",
 _riflePos, "ASSIGNED", 2
] call _fnc_makeTask;

private _rack = createVehicle ["Box_NATO_WpsSpecial_F", _weaponRackPos, [], 0, "CAN_COLLIDE"];
_rack setPos _weaponRackPos;
_rack setDir 180;
clearWeaponCargoGlobal _rack;
clearMagazineCargoGlobal _rack;
clearItemCargoGlobal _rack;
// Bulk training stockpile (per user spec): ample weapons & ammo so an
// entire wave of conscripts can pull from the same rack without it
// emptying. clearWeaponCargoGlobal + addWeaponCargoGlobal is the safe
// network-replicated path.
_rack addWeaponCargoGlobal   ["arifle_AKM_F", 900];
_rack addMagazineCargoGlobal ["30Rnd_762x39_Mag_F", 100000];
// Per user spec: 1000 ammo carriers each so a wave of recruits can
// kit up off the same rack without depleting. Box_NATO_WpsSpecial_F
// supports backpack + item cargo for vests.
_rack addBackpackCargoGlobal ["B_AssaultPack_rgr", 1000];
_rack addItemCargoGlobal     ["V_HarnessO_brn",   1000];

// addAction must be added on every client to be usable; remoteExec
// with JIP=false (no persistent JIP entry — the rack is deleted at the
// end of stage 2, so late-joiners never need it and a persistent JIP
// queue entry per training run accumulates and degrades performance).
private _rackAction = [
    _rack,
    [
        "<t color='#00ff00'>Pick up training rifle</t>",
        {
            params ["_target", "_caller"];
            if (!(_caller getVariable ["CO_bootCampActive", false])) exitWith {};
            if ("arifle_AKM_F" in (weapons _caller)) exitWith {
                hint "You already have the training rifle.";
            };
            _caller addWeapon "arifle_AKM_F";
            _caller addMagazine "30Rnd_762x39_Mag_F";
            _caller addMagazine "30Rnd_762x39_Mag_F";
            _caller addMagazine "30Rnd_762x39_Mag_F";
            _caller selectWeapon "arifle_AKM_F";
            hint "Training rifle issued.\nDestroy the three wooden targets downrange.";
        },
        nil, 1.5, true, true, "",
        "_this distance _target < 3 && (_this getVariable ['CO_bootCampActive', false])"
    ]
] remoteExec ["addAction", 0, false];

// Pop-up wooden targets. Engine `damage` on TargetP_Inf_F does NOT rise
// reliably from rifle hits (it animates rather than taking damage),
// which is why "shooting them up close with a rifle didn't register"
// in earlier runs. We attach a HitPart event handler — fires on ANY
// projectile impact regardless of damage — and pop the target down for
// visible feedback. Tracked via a setVariable flag so the waitUntil
// check is deterministic.
private _targets = [];
private _targetMarkers = [];
private _tIdx = 0;
{
    private _t = createVehicle ["TargetP_Inf_F", _x, [], 0, "CAN_COLLIDE"];
    _t setPos _x;
    // Face WEST toward the firing line so the front of the target
    // (the silhouette) is visible from the shooter's position.
    _t setDir 270;
    _t setVariable ["CO_targetHit", false, true];
    _t addEventHandler ["HitPart", {
        params ["_arr"];
        private _entry = _arr select 0;
        private _tgt   = _entry select 0;
        private _shooter = _entry select 1;
        // Only count hits from a player (or anything the player owns)
        if (isPlayer _shooter) then {
            _tgt setVariable ["CO_targetHit", true, true];
            _tgt animate ["terc", 1];
        };
    }];
    _targets pushBack _t;

    // Visible per-target marker so the player can find them on the map.
    _tIdx = _tIdx + 1;
    private _mkT = format ["co_bc_tgt_%1_%2", _suffix, _tIdx];
    createMarker [_mkT, _x];
    _mkT setMarkerType  "mil_dot";
    _mkT setMarkerColor "ColorRED";
    _mkT setMarkerText  (format ["TARGET %1", _tIdx]);
    _targetMarkers pushBack _mkT;
} forEach _rifleTargetPositions;

private _stage2Deadline = time + 360;
waitUntil {
    sleep 1.5;
    !alive _player ||
    !(_player getVariable ["CO_bootCampActive", false]) ||
    time > _stage2Deadline ||
    ({ _x getVariable ["CO_targetHit", false] } count _targets) >= count _targets
};

{ if (!isNull _x) then { deleteVehicle _x } } forEach _targets;
if (!isNull _rack) then { deleteVehicle _rack };
deleteMarker _mkR;
{ deleteMarker _x } forEach _targetMarkers;

if (!alive _player || !(_player getVariable ["CO_bootCampActive", false])) exitWith {
    [_player, _tStage2, "FAILED"] call BIS_fnc_taskSetState;
};
if (time > _stage2Deadline) then {
    [_player, _tStage2, "FAILED"] call BIS_fnc_taskSetState;
} else {
    [_player, _tStage2, "SUCCEEDED"] call BIS_fnc_taskSetState;
};

// =========================================================
// STAGE 3 — Grenade range
// =========================================================
createMarker [_mkG, _grenadeTargetPos];
_mkG setMarkerType  "mil_destroy";
_mkG setMarkerText  "GRENADE PIT";
_mkG setMarkerColor "ColorBLUFOR";

[_player, _tStage3,
 "Move to the grenade pit and detonate TWO grenades inside the marked area.",
 "3/3  Grenade Range",
 _grenadeTargetPos, "ASSIGNED", 1
] call _fnc_makeTask;

_player addMagazine "HandGrenade";
_player addMagazine "HandGrenade";
_player addMagazine "HandGrenade";

private _stage3Deadline = time + 240;
private _grenadesThrown = 0;
private _lastGrenadeCount = { _x == "HandGrenade" } count (magazines _player);

while {
    alive _player &&
    (_player getVariable ["CO_bootCampActive", false]) &&
    time < _stage3Deadline &&
    _grenadesThrown < 2
} do {
    sleep 1;
    private _have = { _x == "HandGrenade" } count (magazines _player);
    if (_have < _lastGrenadeCount &&
        _player distance _grenadeTargetPos < 35) then {
        _grenadesThrown = _grenadesThrown + (_lastGrenadeCount - _have);
    };
    _lastGrenadeCount = _have;
};

deleteMarker _mkG;

if (!alive _player || !(_player getVariable ["CO_bootCampActive", false])) exitWith {
    [_player, _tStage3, "FAILED"] call BIS_fnc_taskSetState;
};
if (_grenadesThrown < 2) then {
    [_player, _tStage3, "FAILED"] call BIS_fnc_taskSetState;
} else {
    [_player, _tStage3, "SUCCEEDED"] call BIS_fnc_taskSetState;
};

// =========================================================
// GRADUATION
// =========================================================
["BOOT CAMP COMPLETE\nMoving you to the front at Krasnostav."] remoteExec ["hint", _player];
sleep 4;
_player setVariable ["CO_isCleared", true, true];
_player setVariable ["CO_bootCampGraduated", true, true];
_player setVariable ["CO_bootCampActive", false, true];
_player setVariable ["CO_detainPhase", "deployed", true];
[_player] call co_main_fnc_deployToFront;
