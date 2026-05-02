// ============================================================
// ChernOccupation — Mission Init
// ============================================================
// Support existing builds that still register functions as CO_fnc_* while the
// codebase consistently calls co_main_fnc_*.
private _legacyCategory = configFile >> "CfgFunctions" >> "CO" >> "Main";
if (isClass _legacyCategory) then {
    for "_index" from 0 to ((count _legacyCategory) - 1) do {
        private _entry = _legacyCategory select _index;
        if (!isClass _entry) then { continue };

        private _functionName = configName _entry;
        private _preferredName = format ["co_main_fnc_%1", _functionName];
        if !(isNil _preferredName) then { continue };

        private _legacyName = format ["CO_fnc_%1", _functionName];
        if !(isNil _legacyName) then {
            missionNamespace setVariable [_preferredName, missionNamespace getVariable _legacyName];
        };
    };
};

// Dedicated servers never own a player object, so keep server init separate.
if (isServer) then {
    execVM "CO_adminDefaults.sqf";
    waitUntil { !isNil "CO_checkpoint_hostilesPerPost" };
    [] call co_main_fnc_initServer;
};

if (hasInterface) then {
    waitUntil { !isNull player };
    [] call co_main_fnc_initClient;
};

if (!hasInterface && !isServer) then {
    [] call co_main_fnc_initHC;
};