// ============================================================
// fn_guardAggroLoop.sqf
// Generic active-scan loop for static hostile guard groups
// (checkpoints, fortifications, airfield perimeter, detention).
// Engine treats civilians as friendly to BLUFOR (setFriend 1),
// so without this loop guards never engage unprovoked. This
// loop periodically scans for civilian men / non-captive players
// and routes them through fn_checkpointAlert.
//
// params:
//   _grp          - guard group
//   _anchorPos    - center to scan from (typically the post pos)
//   _radius       - scan radius in metres (default 70)
//   _faction      - "CRN_ENF" | "POLICE" | "CRN_FRONT" (default ENF)
//
// Returns: nothing. Spawns a server-side loop bound to the group.
// ============================================================
params [
    ["_grp", grpNull],
    ["_anchorPos", [0,0,0]],
    ["_radius", 70],
    ["_faction", "CRN_ENF"]
];

if (isNull _grp) exitWith {};
if (_grp getVariable ["CO_aggroLoopActive", false]) exitWith {};
_grp setVariable ["CO_aggroLoopActive", true, false];
_grp setVariable ["CO_aggroAnchor", _anchorPos, false];
_grp setVariable ["CO_aggroRadius", _radius, false];
if (isNil { _grp getVariable "CO_faction" }) then {
    _grp setVariable ["CO_faction", _faction, false];
};

[_grp] spawn {
    params ["_grp"];
    while {
        ({ alive _x } count units _grp) > 0
    } do {
        sleep 2.5;
        if ({ alive _x } count units _grp == 0) exitWith {};

        private _anchor = _grp getVariable ["CO_aggroAnchor", getPosATL (leader _grp)];
        private _radius = _grp getVariable ["CO_aggroRadius", 70];
        private _faction = _grp getVariable ["CO_faction", "CRN_ENF"];

        // Skip if group is already engaged (one of them is targeting / shooting)
        private _busy = false;
        {
            if (alive _x && {behaviour _x == "COMBAT" && !isNull (assignedTarget _x)}) exitWith {
                _busy = true;
            };
        } forEach units _grp;
        if (_busy) then { continue };

        // Find foot targets in a wider sphere than naive sight: use a center
        // close to the live leader so mobile guards (roving patrols) still
        // detect movement through their patrol radius.
        private _scanCenter = getPosATL (leader _grp);
        private _candidates = (_scanCenter nearEntities [["Man"], _radius]) select {
            private _u = _x;
            if (!alive _u) exitWith { false };
            if (captive _u) exitWith { false };
            if (_u getVariable ["CO_isFemale", false]) exitWith { false };
            if (_u getVariable ["CO_captureInProgress", false]) exitWith { false };
            if (_u getVariable ["CO_knockedOut", false]) exitWith { false };

            private _ufac = group _u getVariable ["CO_faction", ""];
            if (_ufac in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) exitWith { false };

            // Players: only target civilian-side or guer (resistance) characters
            if (isPlayer _u) exitWith {
                !((side group _u) in [west, east])
            };

            side _u == civilian
        };

        // Also pick up players inside civilian vehicles within slightly larger radius
        if (_candidates isEqualTo []) then {
            private _vehTargets = (_scanCenter nearEntities [["LandVehicle"], _radius + 30]) select {
                alive _x &&
                {!(_x getVariable ["CO_isBusPatrol", false])} &&
                {(group driver _x getVariable ["CO_faction", ""]) in ["", "RESISTANCE"]}
            };
            {
                private _crew = (crew _x) select {
                    isPlayer _x && !captive _x && !((side group _x) in [west,east])
                };
                if (count _crew > 0) exitWith {
                    _candidates = [_crew select 0];
                };
            } forEach _vehTargets;
        };

        if (_candidates isEqualTo []) then { continue };

        private _sorted = [_candidates, [], { _x distance2D _scanCenter }, "ASCEND"] call BIS_fnc_sortBy;
        private _target = _sorted select 0;

        // Throttle by per-group cooldown so we don't constantly re-fire
        // checkpointAlert on the same target while a chase is already underway.
        private _next = _grp getVariable ["CO_aggroNextAt", 0];
        if (time < _next) then { continue };
        _grp setVariable ["CO_aggroNextAt", time + 4, false];

        [[_target], _grp] call co_main_fnc_checkpointAlert;
    };

    _grp setVariable ["CO_aggroLoopActive", false, false];
};
