// fn_adminPanel.sqf
disableSerialization;

private _adminUIDs = missionNamespace getVariable ["CO_adminUIDs", []];
private _adminUIDStrings = _adminUIDs apply { if (typeName _x == "STRING") then { _x } else { str _x } };
if (!hasInterface || { !((getPlayerUID player) in _adminUIDStrings) }) exitWith { hint "No admin access."; };

createDialog "CO_AdminPanel";
private _display = uiNamespace getVariable "CO_AdminPanelDlg";
if (isNull _display) exitWith { hint "Admin panel dialog failed to open."; };

// Sync slider positions to current values
(_display displayCtrl 301) sliderSetPosition CO_checkpoint_hostilesPerPost;
(_display displayCtrl 302) cbSetChecked CO_checkpoint_includeSmall;
(_display displayCtrl 310) sliderSetPosition CO_bus_totalCruising;
(_display displayCtrl 311) sliderSetPosition CO_bus_hostilesPerBus;
(_display displayCtrl 312) sliderSetPosition CO_bus_townGuaranteed;
(_display displayCtrl 320) sliderSetPosition CO_border_postSpacing;
(_display displayCtrl 330) sliderSetPosition CO_police_carStopChance;
(_display displayCtrl 331) cbSetChecked CO_police_active;
(_display displayCtrl 340) sliderSetPosition CO_rus_waveCooldown;

(_display displayCtrl 3011) ctrlSetText str (round CO_checkpoint_hostilesPerPost);
(_display displayCtrl 3101) ctrlSetText str (round CO_bus_totalCruising);
(_display displayCtrl 3111) ctrlSetText str (round CO_bus_hostilesPerBus);
(_display displayCtrl 3121) ctrlSetText str (round CO_bus_townGuaranteed);
(_display displayCtrl 3201) ctrlSetText str (round CO_border_postSpacing);
(_display displayCtrl 3301) ctrlSetText str CO_police_carStopChance;
(_display displayCtrl 3401) ctrlSetText str (round CO_rus_waveCooldown);
