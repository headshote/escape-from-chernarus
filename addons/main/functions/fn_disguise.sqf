// fn_disguise.sqf
// Player picks up clothing item → identity hash changes for police recognition.

player setVariable ["CO_playerDisguised", false, true];
player setVariable ["CO_disguiseLevel", 0, true];

["co_main_disguise", {
    params ["_player", "_clothingItem"];

    private _disguiseLevel = switch (_clothingItem) do {
        case "U_C_Workman_01": { 1 }; // basic worker clothes
        case "H_Cap_tan":      { 1 }; // hat only, minor
        case "G_Squares":      { 2 }; // glasses disguise
        case "U_C_Farmer":     { 2 };
        default                  { 0 };
    };

    _player addUniform _clothingItem;
    _player setVariable ["CO_disguiseLevel", _disguiseLevel, true];
    _player setVariable ["CO_playerDisguised", _disguiseLevel > 0, true];

}] call CBA_fnc_addEventHandler;