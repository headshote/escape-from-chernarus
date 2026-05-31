// fn_policeRecognise.sqf
params ["_officer", "_suspect"];

private _baseChance     = _suspect getVariable ["CO_wantedLevel", 0]; // 0-100
private _disguiseMod    = (_suspect getVariable ["CO_disguiseLevel", 0]) * 20; // each level reduces by 20%
private _distance       = _officer distance _suspect;
private _distanceMod    = (100 - (_distance * 1.5)) max 0;

private _detectChance = ((_baseChance + _distanceMod) - _disguiseMod) max 0;

(random 100) < _detectChance // returns true if recognised