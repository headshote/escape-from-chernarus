// fn_adminPanel.sqf
if !(isServer || (getPlayerUID player in CO_adminUIDs)) exitWith { hint "No admin access."; };

createDialog "CO_AdminPanel";
private _display = uiNamespace getVariable "CO_AdminPanelDlg";
if (isNull _display) exitWith { hint "Admin panel dialog failed to open."; };

// Sync slider positions to current values
(_display displayCtrl 301) sliderSetPosition CO_checkpoint_hostilesPerPost;
(_display displayCtrl 310) sliderSetPosition CO_bus_totalCruising;
(_display displayCtrl 311) sliderSetPosition CO_bus_hostilesPerBus;
(_display displayCtrl 312) sliderSetPosition CO_bus_townGuaranteed;
(_display displayCtrl 320) sliderSetPosition CO_border_postSpacing;
(_display displayCtrl 330) sliderSetPosition CO_police_carStopChance;
(_display displayCtrl 340) sliderSetPosition CO_rus_waveCooldown;

// Update value labels on slider change via CBA display handlers
private _updateLabel = { params ["_ctrl","_idc"]; (_ctrl controlsGroupCtrl _idc) ctrlSetText str (round sliderPosition _ctrl); };

// Labels are updated via the onSliderPosChanged EH already embedded in HPP