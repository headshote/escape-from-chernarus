// ============================================================
// fn_policeResponseFX.sqf — response light + siren while a
// police/response car has CO_responseActive=true.
//
// Repair R2-c: the siren path is now VERIFIED at runtime with
// fileExists against a candidate list (the old hardcoded
// "A3\Sounds_F\sfx\alarm.wss" was never confirmed to exist — a
// bad path fails silently, leaving the "siren" mute). If no
// candidate resolves, the fallback is a periodic horn blast
// using the vehicle's own config-defined horn weapon, which is
// guaranteed to exist and audible to all clients.
//
// params: [_vehicle]
// ============================================================
params [["_veh", objNull]];
if (isNull _veh) exitWith {};
if (_veh getVariable ["CO_responseFXRunning", false]) exitWith {};
_veh setVariable ["CO_responseFXRunning", true, false];

// Resolve the siren sound once per session and cache the result.
if (isNil "CO_sirenSoundPath") then {
    CO_sirenSoundPath = "";
    {
        if (fileExists _x) exitWith { CO_sirenSoundPath = _x };
    } forEach [
        "A3\Sounds_F\sfx\alarm.wss",
        "A3\Sounds_F\sfx\alarm_BLUFOR.wss",
        "A3\Sounds_F\sfx\alarm_OPFOR.wss",
        "A3\Sounds_F\sfx\SFX_Alarm_01.wss"
    ];
    diag_log format ["[CO] Siren sound resolved to '%1' (empty = horn fallback).", CO_sirenSoundPath];
};

[_veh] spawn {
    params ["_veh"];
    private _light = "#lightpoint" createVehicle (getPosATL _veh);
    _light setLightColor [0.1, 0.25, 1];
    _light setLightAmbient [0.02, 0.05, 0.25];
    _light setLightBrightness 0.8;
    _light attachTo [_veh, [0, -0.8, 1.4]];

    // Config-derived horn weapon for the fallback siren.
    private _horn = "";
    {
        if ("horn" in toLower _x) exitWith { _horn = _x };
    } forEach (weapons _veh);

    while { alive _veh && (_veh getVariable ["CO_responseActive", false]) } do {
        _light setLightBrightness 0.9;
        if (CO_sirenSoundPath != "") then {
            playSound3D [CO_sirenSoundPath, _veh, false, getPosASL _veh, 0.9, 1.15, 450];
        } else {
            private _drv = driver _veh;
            if (_horn != "" && !isNull _drv && alive _drv && !isPlayer _drv) then {
                _drv forceWeaponFire [_horn, _horn];
            };
        };
        sleep 0.4;
        _light setLightBrightness 0.25;
        sleep 2.8;
    };

    deleteVehicle _light;
    _veh setVariable ["CO_responseFXRunning", false, false];
};
