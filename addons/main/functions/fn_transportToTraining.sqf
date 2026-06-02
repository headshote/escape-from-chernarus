// fn_transportToTraining.sqf
params ["_conscript"];

if (isNil "CO_trainingFieldPos") then {
    CO_trainingFieldPos = [2160, 12800, 0]; // NW airfield training field
    publicVariable "CO_trainingFieldPos";
};

// Board bus
private _bus = "C_Van_01_transport_F" createVehicle (getPosATL _conscript);
_bus allowDamage false;
[_bus] spawn {
    params ["_bus"];
    sleep 6;
    if (!isNull _bus) then { _bus allowDamage true };
};
_conscript assignAsCargo _bus;
_conscript moveInCargo _bus;
if (isPlayer _conscript) then {
    [_conscript, _bus] remoteExec ["moveInCargo", _conscript];
};
_conscript setCaptive true;

// Escort group
private _escortGrp = createGroup west;
_escortGrp setVariable ["CO_faction", "CRN_ENF", true];
for "_i" from 0 to 3 do {
    private _u = _escortGrp createUnit ["B_Soldier_F", getPos _bus, [], 2, "CARGO"];
    _u moveInCargo _bus;
    [_u] call co_main_fnc_initHostileUnit;
};
private _driverGrp = createGroup west;
_driverGrp setVariable ["CO_faction", "CRN_ENF", true];
private _busDriver = _driverGrp createUnit ["B_Soldier_F", getPos _bus, [], 0, "CARGO"];
_busDriver moveInDriver _bus;
[_busDriver] call co_main_fnc_initHostileUnit;

// Drive to airfield
_bus engineOn true;
_bus setFuel 1;
private _wp = _driverGrp addWaypoint [CO_trainingFieldPos, 0];
_wp setWaypointType "MOVE";
_wp setWaypointSpeed "NORMAL";
_wp setWaypointBehaviour "SAFE";
_wp setWaypointCombatMode "BLUE";
(driver _bus) doMove CO_trainingFieldPos;

private _deadline = time + 480;
waitUntil {
    sleep 2;
    !alive _bus ||
    isNull (driver _bus) ||
    ((driver _bus) distance2D CO_trainingFieldPos) < 35 ||
    time > _deadline
};

if (alive _conscript) then {
    if (_conscript in _bus) then {
        unassignVehicle _conscript;
        _conscript leaveVehicle _bus;
        moveOut _conscript;
    };
    _conscript setPosATL (CO_trainingFieldPos vectorAdd [random 20 - 10, random 20 - 10, 0]);
};

// Begin training phase
if (alive _conscript) then {
    [_conscript] call co_main_fnc_trainingPhase;
};
