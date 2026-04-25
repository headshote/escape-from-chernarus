// fn_adminPanel.sqf
if !(isServer || (getPlayerUID player in CO_adminUIDs)) exitWith { hint "No access."; };

// Simple slider dialog — abbreviated
private _display = createDisplay "CO_AdminPanel";

// On slider change → broadcast new value
[_display displayCtrl 301, "sliderChanged", {
    CO_bus_totalCruising = round sliderPosition (_this select 0);
    publicVariable "CO_bus_totalCruising";
}] call CBA_fnc_addDisplayHandler;