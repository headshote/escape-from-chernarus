// fn_checkTownCapture.sqf
{
    private _townName   = _x select 0;
    private _townX      = _x select 1;
    private _markerName = _x select 2;
    private _alreadyFallen = markerColor _markerName == "ColorRed";

    if (!_alreadyFallen && CO_rus_advanceFront < _townX + 500) then {
        private _rusUnits   = count (getPos (allGroups select { _x getVariable ["CO_faction",""] == "RUS_ADV" }) call { nearUnits [_townX, 600] });
        private _frontUnits = count (getPos (allGroups select { _x getVariable ["CO_faction",""] == "CRN_FRONT" }) call { nearUnits [_townX, 600] });

        if (_rusUnits > _frontUnits * 2) then {
            setMarkerColor [_markerName, "ColorRed"];
            setMarkerText  [_markerName, format ["%1 — FALLEN", _townName]];
            // Civilians in town now safe from Enforcers (they fled)
            [_townName] call co_main_fnc_enforcerRetreatFromTown;
            hint format ["%1 has fallen to Russian forces.", _townName];
        };
    };
} forEach CO_rus_townObjectives;