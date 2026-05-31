// fn_showDetentionHUD.sqf — client side
// Shows a persistent HUD label during detention phase and exposes a self-action
// the player can use to attempt to pick the cell lock and escape.
params ["_player"];
titleText ["YOU HAVE BEEN DETAINED\nEscape within 5 minutes or you will be transferred to training.\nUse the action menu (default key 6) to attempt the lock.", "BLACK IN", 0.5];
sleep 5;
titleFadeOut 2;

// Add a self-action only once per detention. Removed automatically once the
// player escapes (CO_detainPhase != "detention") or the detention timer
// transfers them to training.
private _existing = _player getVariable ["CO_detainActionId", -1];
if (_existing != -1) then { _player removeAction _existing; };

private _aid = _player addAction [
    "<t color='#FFCC00'>Attempt to pick the lock</t>",
    {
        params ["_target", "_caller", "_actionId"];
        if ((_target getVariable ["CO_detainPhase", ""]) != "detention") exitWith {
            hint "Too late — you are no longer in detention.";
            _target removeAction _actionId;
            _target setVariable ["CO_detainActionId", -1, false];
        };
        // Fire-and-forget; the minigame manages its own dialog and outcome.
        [_caller, objNull] spawn co_main_fnc_minigame_lockpick;
    },
    nil, 1.0, true, true,
    "",
    "(_target getVariable ['CO_detainPhase', '']) == 'detention'"
];
_player setVariable ["CO_detainActionId", _aid, false];
