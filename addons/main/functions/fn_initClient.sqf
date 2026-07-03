// ============================================================
// fn_initClient.sqf — runs on every machine that has a screen
// ============================================================

// Wait for globals to arrive from server (sleep so we don't busy-spin the
// scheduler every frame while the server is still broadcasting on join).
waitUntil { sleep 0.5; !isNil "CO_checkpoint_hostilesPerPost" && !isNil "CO_police_active" };

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
[] call co_main_fnc_heatHud;

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

// Breakout self-action: visible only while locked in a capture
// transport. Runs the latch minigame; success is consumed by the
// transport's drive loop on the server.
CO_fnc_addBreakoutAction = {
    params [["_unit", player]];
    _unit addAction [
        "<t color='#FF9944'>Force the cargo latch</t>",
        { [] spawn co_main_fnc_breakoutMinigame; },
        nil, 1.6, false, true, "",
        "(player getVariable ['CO_detainPhase','']) == 'transport'
         && vehicle player != player
         && ((vehicle player) getVariable ['CO_isCaptureTransport', false])
         && time > (player getVariable ['CO_nextBreakoutAt', 0])"
    ];
};
[player] call CO_fnc_addBreakoutAction;

// Re-install after every respawn
addMissionEventHandler ["Respawn", {
    params ["_newUnit"];
    [_newUnit] call CO_fnc_addBreakoutAction;
    _newUnit setVariable ["CO_nonLethalInstalled", false, true];
    [_newUnit] call co_main_fnc_installNonLethalDamage;
    // Re-arm the weapon-fired tracker on the new body — the original EH was
    // bound to the previous unit, so without this police escalation logic
    // (CO_hasFiredWeapon) silently stops working after the first respawn.
    _newUnit setVariable ["CO_hasFiredWeapon", false, true];
    _newUnit addEventHandler ["Fired", {
        params ["_unit"];
        _unit setVariable ["CO_hasFiredWeapon", true, true];
        _unit setVariable ["CO_lastFireTime", time, true];
    }];
}];

// Police recognition is now server-authoritative in fn_policePatrols:
// suspicion rises, hails, ID checks, pursuits, backup and vehicle chases
// all run from the patrol controller to avoid client-side false triggers.

// Show initial briefing
titleText [
    "CHERNARUS OCCUPATION\nYou begin as a civilian. Avoid checkpoints, bus patrols, and police. Escape the border or risk detention, forced training, and the eastern front.",
    "BLACK IN",
    0.8
];
sleep 60;
titleFadeOut 4;
