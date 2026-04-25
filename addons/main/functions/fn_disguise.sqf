// fn_disguise.sqf
// Player picks up clothing item → identity hash changes for police recognition.

CO_playerDisguised    = false;
CO_disguiseLevel      = 0; // 0-3, higher = harder to ID

["co_main_disguise", {
    params ["_player", "_clothingItem"];

    switch (_clothingItem) do {
        case "U_C_Workman_01": { CO_disguiseLevel = 1; }; // basic worker clothes
        case "H_Cap_tan":      { CO_disguiseLevel = 1; }; // hat only, minor
        case "G_Squares":      { CO_disguiseLevel = 2; }; // glasses disguise
        case "U_C_Farmer":     { CO_disguiseLevel = 2; };
        default                { CO_disguiseLevel = 0; };
    };

    _player addUniform _clothingItem;
    CO_playerDisguised = (CO_disguiseLevel > 0);

    publicVariable "CO_playerDisguised";
    publicVariable "CO_disguiseLevel";

}] call CBA_fnc_addEventHandler;