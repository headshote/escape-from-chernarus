params ["_player"];

createDialog "CO_WrangleDialog";
private _dlg = uiNamespace getVariable "CO_WrangleDlg";

private _resistBar  = _dlg displayCtrl 201;
private _totalW     = 0.6;
private _progress   = 0.5;  // 0 = captured, 1 = free
private _timeLimit  = 8;    // seconds to escape
private _startTime  = time;
private _result     = "captured";

// Keyboard press counter
private _pressCount = 0;
onKeyDown ["F", { _pressCount = _pressCount + 1; false }];

// Mini-game loop
while { time - _startTime < _timeLimit } do {
    if (_pressCount > 0) then {
        _progress = (_progress + (_pressCount * 0.08)) min 1;
        _pressCount = 0;
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

closeDialog 0;
onKeyDown ["F", {}]; // clear handler

_player setVariable ["CO_wrangleResult", _result, true]; // broadcast to server