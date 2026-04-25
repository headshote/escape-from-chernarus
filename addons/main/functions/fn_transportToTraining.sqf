// fn_transportToTraining.sqf
params ["_conscript"];

CO_trainingFieldPos = [2100, 12800, 0]; // NW airfield area

// Board bus
private _bus = "C_Van_01_transport_F" createVehicle getPos _conscript;
_conscript moveInCargo _bus;
_conscript setCaptive true;

// Escort group
private _escortGrp = createGroup west;
_escortGrp setVariable ["CO_faction", "CRN_ENF"];
for "_i" from 0 to 3 do {
    private _u = _escortGrp createUnit ["B_Soldier_F", getPos _bus, [], 2, "CARGO"];
    _u moveInCargo _bus;
    [_u] call co_main_fnc_initHostileUnit;
};
private _driverGrp = createGroup west;
private _busDriver = _driverGrp createUnit ["B_Soldier_F", getPos _bus, [], 0, "CARGO"];
_busDriver moveInDriver _bus;
[_busDriver] call co_main_fnc_initHostileUnit;

// Drive to airfield
(driver _bus) doMove CO_trainingFieldPos;

waitUntil { sleep 2; (driver _bus) distance CO_trainingFieldPos < 30 };
_conscript leaveVehicle _bus;

// Begin training phase
[_conscript] call co_main_fnc_trainingPhase;