// ============================================================
// fn_initClient.sqf — runs on every machine that has a screen
// ============================================================

// Wait for globals to arrive from server
waitUntil { !isNil "CO_checkpoint_hostilesPerPost" && !isNil "CO_police_active" };

// --- Player loadout policy: civilian start has no GPS ---
// Per spec point 16: only a map, compass, and watch by default. Players who
// later find a GPS in a weapon cache can pick it up manually. Goggles are
// unaffected so face-cover items still work as part of the disguise system.
{
    private _hasItem = (_x in (assignedItems player));
    if (_hasItem) then { player unassignItem _x; };
    player removeItem _x;
} forEach ["ItemGPS", "ItemRadio", "B_UavTerminal"];

// Make sure the basic identity items are present
{
    if !(_x in (assignedItems player)) then {
        player addItem _x;
        player assignItem _x;
    };
} forEach ["ItemMap", "ItemCompass", "ItemWatch"];

// Hide the player's own marker on the map (engine-level: shows only in radar
// HUD, which civilians don't have anyway). We force hide via showHUD
// preserving other elements so the watch/compass remain visible.
showGPS false;

// Start endurance bar HUD
[] call co_main_fnc_enduranceBar;

// Listen for wrangle result broadcast (server reads CO_wrangleResult)
// (Already handled via setVariable broadcast — nothing extra needed here)

// Disguise event listener (CBA EH wired in fn_disguise)
[] call co_main_fnc_disguise;

// Install non-lethal damage handler on the local player so TCK/police
// gunfire stuns instead of killing.
[player] call co_main_fnc_installNonLethalDamage;

// Track if the player has fired a weapon recently — police use this to
// decide whether to escalate to lethal. Flag clears after 60 s of silence.
player addEventHandler ["Fired", {
    params ["_unit"];
    _unit setVariable ["CO_hasFiredWeapon", true, true];
    _unit setVariable ["CO_lastFireTime", time, true];
}];
[] spawn {
    while { true } do {
        sleep 5;
        if (!alive player) then { continue };
        private _last = player getVariable ["CO_lastFireTime", -999];
        if ((player getVariable ["CO_hasFiredWeapon", false]) &&
            time - _last > 60) then {
            player setVariable ["CO_hasFiredWeapon", false, true];
        };
    };
};

// Re-install after every respawn
addMissionEventHandler ["Respawn", {
    params ["_newUnit"];
    _newUnit setVariable ["CO_nonLethalInstalled", false, true];
    [_newUnit] call co_main_fnc_installNonLethalDamage;
}];

// Police recognition loop: periodically check nearby police
[] spawn {
    while { true } do {
        sleep 4;
        if (!alive player) then { continue };
        if (!CO_police_active) then { continue };
        private _nearCops = allGroups select {
            _x getVariable ["CO_faction",""] == "POLICE" &&
            (leader _x) distance player < 80
        };
        {
            private _cop = leader _x;
            if ([_cop, player] call co_main_fnc_policeRecognise) then {
                [[player], group _cop] remoteExec ["co_main_fnc_checkpointAlert", 2];
            };
        } forEach _nearCops;
    };
};

// Show initial briefing
titleText [
    "CHERNARUS OCCUPATION\nYou begin as a civilian. Avoid checkpoints, bus patrols, and police. Escape the border or risk detention, forced training, and the eastern front.",
    "BLACK IN",
    0.8
];
sleep 60;
titleFadeOut 4;