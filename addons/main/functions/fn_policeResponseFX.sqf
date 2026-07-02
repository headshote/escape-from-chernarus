// ============================================================
// fn_policeResponseFX.sqf
// Siren-ish audio pulse plus blue light while a police/response car
// has CO_responseActive=true.
// params: [_vehicle]
// ============================================================
params [["_veh", objNull]];
if (isNull _veh) exitWith {};
if (_veh getVariable ["CO_responseFXRunning", false]) exitWith {};
_veh setVariable ["CO_responseFXRunning", true, false];

[_veh] spawn {
    params ["_veh"];
    private _light = "#lightpoint" createVehicle (getPosATL _veh);
    _light setLightColor [0.1, 0.25, 1];
    _light setLightAmbient [0.02, 0.05, 0.25];
    _light setLightBrightness 0.8;
    _light attachTo [_veh, [0, -0.8, 1.4]];

    while { alive _veh && (_veh getVariable ["CO_responseActive", false]) } do {
        _light setLightBrightness 0.9;
        playSound3D ["A3\Sounds_F\sfx\alarm.wss", _veh, false, getPosASL _veh, 0.9, 1.15, 450];
        sleep 0.4;
        _light setLightBrightness 0.25;
        sleep 2.8;
    };

    deleteVehicle _light;
    _veh setVariable ["CO_responseFXRunning", false, false];
};
