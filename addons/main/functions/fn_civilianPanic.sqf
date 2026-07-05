// ============================================================
// fn_civilianPanic.sqf
// Makes nearby NPC civilians flee from a raid/capture event.
// params: [_center, _radius, _source]
// ============================================================
params [
    ["_center", [0,0,0]],
    ["_radius", 90],
    ["_source", objNull]
];

private _civs = (_center nearEntities [["Man"], _radius]) select {
    alive _x &&
    !isPlayer _x &&
    side _x == civilian &&
    !captive _x &&
    !(_x getVariable ["CO_knockedOut", false])
};

{
    _x setVariable ["CO_civState", "fleeing", false];
    _x setVariable ["CO_civAlertUntil", time + 35, false];
    private _awayFrom = if (isNull _source) then { _center } else { getPosATL _source };
    private _dir = _awayFrom getDir _x;
    _x setBehaviour "AWARE";
    _x doMove ((getPosATL _x) getPos [80 + random 60, _dir]);
} forEach _civs;

// Sound cue only if the siren path resolved (R2-c); a missing file
// fails silently, so don't pretend there's audio when there isn't.
if (!isNull _source && (missionNamespace getVariable ["CO_sirenSoundPath", ""]) != "") then {
    playSound3D [CO_sirenSoundPath, _source, false, getPosASL _source, 1.1, 0.9, 180];
};
