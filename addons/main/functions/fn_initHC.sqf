// ============================================================
// fn_initHC.sqf
// Headless Client initialisation — offloads heavy NPC loops.
// HC takes control of groups by moving them to HC's machine.
// ============================================================

// Wait for server to finish building the world
waitUntil { !isNil "CO_roadGraph" };
sleep 5;

// Transfer all AI groups to HC for better performance
[] spawn {
    while { true } do {
        sleep 30;
        {
            if (count units _x > 0 && isServer) then {
                private _grpOwner = groupOwner _x;
                if (_grpOwner == 2) then { // still owned by server
                    setGroupOwner [_x, clientOwner];
                };
            };
        } forEach allGroups;
    };
};
