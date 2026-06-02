// fn_disguise.sqf — client-side
// Wires disguise pickup actions to weapon caches and listens for the CBA event
// that updates a player's CO_disguiseLevel after they swap clothing.

player setVariable ["CO_playerDisguised", false, true];
player setVariable ["CO_disguiseLevel", 0, true];

// CBA event raised when a disguise item is applied (locally on the affected
// player). Bumps disguise level which fn_policeRecognise uses to dampen
// recognition rolls.
["co_main_disguise", {
    params ["_player", "_clothingItem"];
    if (isNull _player || _player != player) exitWith {};

    private _disguiseLevel = switch (true) do {
        case (_clothingItem in ["U_C_Workman_01", "U_C_Poor_1", "U_C_Poor_2"]):       { 1 };
        case (_clothingItem in ["U_C_Farmer", "U_C_Driver_1", "U_C_HunterBody_grn"]): { 2 };
        case (_clothingItem in ["U_C_Scientist", "U_C_Journalist"]):                  { 3 };
        default                                                                          { 0 };
    };

    if (_disguiseLevel > 0) then {
        removeUniform _player;
        _player addUniform _clothingItem;
    };

    private _current = _player getVariable ["CO_disguiseLevel", 0];
    if (_disguiseLevel > _current) then {
        _player setVariable ["CO_disguiseLevel", _disguiseLevel, true];
        _player setVariable ["CO_playerDisguised", _disguiseLevel > 0, true];
        hint format ["Disguise applied (level %1). Police are less likely to recognise you.", _disguiseLevel];
    };
}] call CBA_fnc_addEventHandler;

// Per-frame: ensure every weapon cache near the player has a "Take Disguise"
// action. We add it once per cache via an action ID stored on the box. This
// also adds a generic "Loot Cache" action so the player can grab the box
// contents in one click (sparse weapons remain inside for manual pickup).
private _ensureCacheActions = {
    params ["_box"];
    if (!alive _box) exitWith {};
    if (!(_box getVariable ["CO_isWeaponCache", false])) exitWith {};
    if (_box getVariable ["CO_clientActionsBound", false]) exitWith {};
    _box setVariable ["CO_clientActionsBound", true];

    _box addAction [
        "<t color='#FFCC00'>Take Disguise (Worker)</t>",
        {
            params ["_target", "_caller"];
            private _items = _target getVariable ["CO_disguiseItems", []];
            private _clothing = if ("U_C_Workman_01" in _items) then { "U_C_Workman_01" } else { "U_C_Poor_1" };
            if !(_clothing in _items) exitWith { hint "No worker disguise in this cache."; };
            ["co_main_disguise", [_caller, _clothing]] call CBA_fnc_localEvent;
            // Mark this cache as having had its disguise taken so the action
            // greys out for subsequent uses.
            _target setVariable ["CO_disguiseTaken", true, true];
        },
        nil, 1.5, true, true,
        "",
        "alive _target && _this distance _target < 3 && !(_target getVariable ['CO_disguiseTaken', false]) && { ((_target getVariable ['CO_disguiseItems', []]) findIf { _x in ['U_C_Workman_01','U_C_Poor_1'] }) >= 0 }"
    ];

    _box addAction [
        "<t color='#FFCC00'>Take Disguise (Farmer)</t>",
        {
            params ["_target", "_caller"];
            private _items = _target getVariable ["CO_disguiseItems", []];
            private _clothing = if ("U_C_Farmer" in _items) then { "U_C_Farmer" } else { "U_C_Driver_1" };
            if !(_clothing in _items) exitWith { hint "No farmer disguise in this cache."; };
            ["co_main_disguise", [_caller, _clothing]] call CBA_fnc_localEvent;
            _target setVariable ["CO_disguiseTaken", true, true];
        },
        nil, 1.4, true, true,
        "",
        "alive _target && _this distance _target < 3 && !(_target getVariable ['CO_disguiseTaken', false]) && { ((_target getVariable ['CO_disguiseItems', []]) findIf { _x in ['U_C_Farmer','U_C_Driver_1'] }) >= 0 }"
    ];
};

[{
    {
        if (_x getVariable ["CO_isWeaponCache", false]) then {
            [_x] call (missionNamespace getVariable ["CO_fnc_ensureCacheActions", {}]);
        };
    } forEach (player nearObjects ["B_supplyCrate_F", 12]);
}, 4, []] call CBA_fnc_addPerFrameHandler;

missionNamespace setVariable ["CO_fnc_ensureCacheActions", _ensureCacheActions];
