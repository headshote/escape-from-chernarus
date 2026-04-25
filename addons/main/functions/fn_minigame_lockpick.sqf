// fn_minigame_lockpick.sqf
// Called when player interacts with a locked door in detention.
// Minigame: a sequence of 4 random keys to press within a time window.

params ["_player", "_door"];

private _keys = ["W","A","S","D","F","G","R"];
private _sequence = [];
for "_i" from 1 to 4 do {
    _sequence pushBack (_keys call BIS_fnc_selectRandom);
};

// Display sequence hint then hide it
hint format ["Sequence: %1", _sequence]; sleep 1.5; hint "";

private _correct = 0;
private _failed  = false;
private _startT  = time;

{
    private _expected = _x;
    private _pressed  = false;
    private _stepStart = time;

    while { !_pressed && (time - _stepStart < 2) } do {
        // Check key — simplified: use CBA key handler in real implementation
        if (inputAction "MoveForward" == 1 && _expected == "W") then { _pressed = true; };
        if (inputAction "MoveLeft" == 1   && _expected == "A") then { _pressed = true; };
        if (inputAction "MoveBack" == 1   && _expected == "S") then { _pressed = true; };
        if (inputAction "MoveRight" == 1  && _expected == "D") then { _pressed = true; };
        sleep 0.05;
    };

    if (!_pressed) exitWith { _failed = true; };
    _correct = _correct + 1;
} forEach _sequence;

if (!_failed) then {
    hint "Lock picked!";
    _door animate ["Door_1_rot", 1]; // open door
    [_player] remoteExec ["co_main_fnc_prisonEscape", 2]; // server-side escape logic
} else {
    hint "Guard alerted!";
    [getPos _player] remoteExec ["co_main_fnc_alertNearbyGuards", 2];
};