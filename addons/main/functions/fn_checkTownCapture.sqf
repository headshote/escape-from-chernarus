// fn_checkTownCapture.sqf
{
    private _townName   = _x select 0;
    private _townX      = _x select 1;
    private _markerName = _x select 2;
    private _alreadyFallen = markerColor _markerName == "ColorRed";

    if (!_alreadyFallen && CO_rus_advanceFront < _townX + 500) then {
        private _townPos = [_townX, 6000, 0]; // approximate town center

        private _rusUnits = {
            _x getVariable ["CO_faction",""] == "RUS_ADV" &&
            ({ alive _x } count (units _x)) > 0 &&
            (leader _x) distance _townPos < 800
        } count allGroups;

        private _frontUnits = {
            _x getVariable ["CO_faction",""] == "CRN_FRONT" &&
            (leader _x) distance _townPos < 800
        } count allGroups;

        if (_rusUnits > _frontUnits * 2) then {
            _markerName setMarkerColor "ColorRed";
            _markerName setMarkerText format ["%1 - FALLEN", _townName];
            [_townName] call co_main_fnc_enforcerRetreatFromTown;
            [format ["%1 has fallen to Russian forces.", _townName]] remoteExecCall ["hint", 0];
        };
    };
} forEach CO_rus_townObjectives;