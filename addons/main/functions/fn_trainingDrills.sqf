// fn_trainingDrills.sqf — optional RP flavor for player conscripts
// Shows timed movement waypoints on screen, purely visual
params ["_player"];

private _drillPoints = [
    CO_trainingFieldPos vectorAdd [30, 0, 0],
    CO_trainingFieldPos vectorAdd [30, 30, 0],
    CO_trainingFieldPos vectorAdd [0, 30, 0],
    CO_trainingFieldPos
];

{
    private _wp = _x;
    private _markerName = format ["drill_wp_%1", _forEachIndex];

    // Show marker
    createMarkerLocal [_markerName, _wp];
    _markerName setMarkerShapeLocal "ICON";
    _markerName setMarkerTypeLocal "mil_dot";
    _markerName setMarkerColorLocal "ColorYellow";

    waitUntil { sleep 0.5; _player distance _wp < 8 || !(captive _player) };
    deleteMarkerLocal _markerName;
    if (!(captive _player)) exitWith {};
} forEach _drillPoints;