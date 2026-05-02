params ["_player"];

disableSerialization;

createDialog "CO_WrangleDialog";
private _dlg = uiNamespace getVariable ["CO_WrangleDlg", displayNull];
if (isNull _dlg) exitWith {
    _player setVariable ["CO_wrangleResult", "captured", true];
};

private _resistBar  = _dlg displayCtrl 201;
private _totalW     = 0.6;
private _progress   = 0.5;  // 0 = captured, 1 = free
private _timeLimit  = 8;    // seconds to escape
private _startTime  = time;
private _result     = "captured";

// Keyboard press counter
missionNamespace setVariable ["CO_wranglePressCount", 0];
missionNamespace setVariable ["CO_wrangleActionKeys", actionKeys "DefaultAction"];
private _keyHandlerId = _dlg displayAddEventHandler ["KeyDown", {
    params ["_display", "_key"];

    if (_key in (missionNamespace getVariable ["CO_wrangleActionKeys", []])) then {
        missionNamespace setVariable [
            "CO_wranglePressCount",
            (missionNamespace getVariable ["CO_wranglePressCount", 0]) + 1
        ];
    };

    false
}];

// Mini-game loop
while { time - _startTime < _timeLimit } do {
    private _pressCount = missionNamespace getVariable ["CO_wranglePressCount", 0];

    if (_pressCount > 0) then {
        _progress = (_progress + (_pressCount * 0.08)) min 1;
        missionNamespace setVariable ["CO_wranglePressCount", 0];
    } else {
        _progress = (_progress - 0.03) max 0;
    };

    // Resize bar
    _resistBar ctrlSetPosition [0.2, 0.45, _totalW * _progress, 0.06];
    _resistBar ctrlCommit 0;

    if (_progress >= 1) then {
        _result = "escaped";
        break;
    };
    if (_progress <= 0) then {
        _result = "captured";
        break;
    };

    sleep 0.05;
};

_dlg displayRemoveEventHandler ["KeyDown", _keyHandlerId];
missionNamespace setVariable ["CO_wrangleActionKeys", nil];
missionNamespace setVariable ["CO_wranglePressCount", nil];
closeDialog 0;

_player setVariable ["CO_wrangleResult", _result, true]; // broadcast to server