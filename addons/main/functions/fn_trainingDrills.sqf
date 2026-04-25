// fn_trainingDrills.sqf — optional RP flavor for player conscripts
// Shows timed movement waypoints on screen, purely visual
params ["_player"];

private _drillPoints = [
    CO_trainingFieldPos vectorAdd [30, 0, 0],
    CO_trainingFieldPos vectorAdd [30, 30, 0],
    CO_trainingFieldPos vectorAdd [0, 30, 0],
    CO_trainingFieldPos,
];

{
    private _wp = _x;
    // Show marker
    createMarkerLocal [format ["drill_wp_%1", _forEachIndex], _wp];
    setMarkerShapeLocal [format ["drill_wp_%1", _forEachIndex], "ICON"];
    setMarkerTypeLocal  [format ["drill_wp_%1", _forEachIndex], "mil_dot"];
    setMarkerColorLocal [format ["drill_wp_%1", _forEachIndex], "ColorYellow"];

    waitUntil { sleep 0.5; _player distance _wp < 8 || !(captive _player) };
    deleteMarkerLocal format ["drill_wp_%1", _forEachIndex];
    if (!(captive _player)) exitWith {};
} forEach _drillPoints;