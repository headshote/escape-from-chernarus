// ============================================================
// fn_enforcerRetreatFromTown.sqf
// Called when a town falls to Russian forces.
// Enforcer groups near that town fall back west.
// params: [_townName (string)]
// ============================================================
params ["_townName"];

// Find town position
private _townData = CO_settlements select { (_x select 0) == _townName };
if (count _townData == 0) exitWith {};
private _townPos = (_townData select 0) select 1;

// Retreat all ENF groups within 1500m of fallen town
{
    if (_x getVariable ["CO_faction",""] == "CRN_ENF") then {
        if ((leader _x) distance _townPos < 1500) then {
            clearWaypoints _x;
            private _retreatX = (_townPos select 0) - 2000 - random 1000;
            private _retreatPos = [_retreatX max 500, (_townPos select 1) + random 1000 - 500, 0];
            private _wp = _x addWaypoint [_retreatPos, 50];
            _wp setWaypointType "MOVE";
            _wp setWaypointSpeed "FULL";
        };
    };
} forEach allGroups;
