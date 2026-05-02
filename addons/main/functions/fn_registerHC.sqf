// ============================================================
// fn_registerHC.sqf
// Server-side HC registration. Transfers server-owned AI groups to the
// registered headless client on a fixed cadence.
// ============================================================
params [["_ownerId", -1]];

if (!isServer) exitWith {};
if (_ownerId < 3) exitWith {};

missionNamespace setVariable ["CO_hcOwnerId", _ownerId, true];

if (missionNamespace getVariable ["CO_hcTransferLoopStarted", false]) exitWith {};
missionNamespace setVariable ["CO_hcTransferLoopStarted", true];

[] spawn {
    while { true } do {
        sleep 30;

        private _hcOwnerId = missionNamespace getVariable ["CO_hcOwnerId", -1];
        if (_hcOwnerId >= 3) then {
            {
                if (count units _x > 0 && groupOwner _x == 2) then {
                    setGroupOwner [_x, _hcOwnerId];
                };
            } forEach allGroups;
        };
    };
};