// ============================================================
// fn_reportCrime.sqf — crime & witness system (server-side)
//
// Repair plan R1-a. Before this existed, killing or wounding
// TCK/police raised NOTHING — no wanted, no heat, no alert, no
// reaction from units 10 m away. This function is the single
// entry point for "a player/civilian did something criminal":
//
//   type "kill"    — a TCK/POLICE unit was killed
//   type "wound"   — a TCK/POLICE unit was hit
//   type "gunfire" — a shot was fired near a TCK/POLICE unit
//                    (witness = the unit whose FiredNear tripped)
//
// Witness rules: kills/wounds are only punished when SEEN —
// a TCK/POLICE unit or NPC civilian within 140 m with a positive
// line-of-sight ray (or within 30 m, close enough to hear the
// scuffle and see the body drop). Unwitnessed violence stays
// unwitnessed: quiet takedowns remain a viable playstyle.
// Gunfire needs no LOS — sound carries.
//
// Effects on a witnessed crime:
//   - wanted level rises (kill +60 / wound +40 / gunfire +10)
//   - escalation state + heat via fn_setEscalationState (which
//     also publishes the LKP to the alert net)
//   - town alert level rises for ~10 min (police suspicion and
//     random-stop pressure scale with it — see fn_policeBrain)
//   - every CRN_ENF/POLICE group with a live unit within 200 m
//     gets a retaliation order; bus escort groups get a bus
//     emergency (fn_busAgroLoop dumps the escorts weapons-free)
//   - the perpetrator gets fn_installNonLethalDamage so the
//     armed response downs them into the capture pipeline
//     instead of killing them outright
//
// params: [_perp, _victim, _type, _witness]
// ============================================================
params [
    ["_perp", objNull],
    ["_victim", objNull],
    ["_type", "gunfire"],
    ["_witness", objNull]
];

if (!isServer) exitWith {
    [_perp, _victim, _type, _witness] remoteExecCall ["co_main_fnc_reportCrime", 2];
};

if (isNull _perp || !alive _perp) exitWith {};
if (captive _perp) exitWith {};
if (!(isPlayer _perp || side _perp == civilian)) exitWith {};
if ((group _perp getVariable ["CO_faction", ""]) in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) exitWith {};

// ---- Throttle per perpetrator + type ------------------------------
private _throttle = switch (_type) do {
    case "kill":    { 0 };     // every kill counts
    case "wound":   { 15 };
    default         { 20 };    // gunfire
};
// NOTE: exitWith inside then{} only leaves the block, so the throttle
// decision must be made at function scope.
private _throttleKey = format ["CO_lastCrime_%1", _type];
if (_throttle > 0 && { (time - (_perp getVariable [_throttleKey, -999])) < _throttle }) exitWith {};
if (_throttle > 0) then {
    _perp setVariable [_throttleKey, time, false];
};

private _refPos = if (!isNull _victim) then { getPosATL _victim } else { getPosATL _perp };

// ---- Witness check (kills/wounds only; gunfire is heard) ----------
private _witnessed = !isNull _witness;
if (!_witnessed && _type in ["kill", "wound"]) then {
    // Mounted units count too — they can witness through a windshield.
    private _cands = (_refPos nearEntities [["Man"], 140]) select {
        alive _x && _x != _perp && _x != _victim
    };
    // Split into security forces and civilian informers, check LOS on
    // a bounded set so a crowd doesn't cost 40 rays.
    private _checked = 0;
    {
        private _w = _x;
        if (_checked >= 8 || _witnessed) exitWith {};
        private _fac = group _w getVariable ["CO_faction", ""];
        private _isSecurity = _fac in ["CRN_ENF", "POLICE"];
        private _isInformer = !_isSecurity && !(isPlayer _w) && side _w == civilian &&
                              !(_w getVariable ["CO_knockedOut", false]) && !captive _w;
        if (_isSecurity || _isInformer) then {
            _checked = _checked + 1;
            private _d = _w distance _perp;
            if (_d < 30) exitWith { _witnessed = true; _witness = _w };
            private _vis = [vehicle _w, "VIEW"] checkVisibility [eyePos _w, eyePos _perp];
            if (_vis > 0.12) exitWith { _witnessed = true; _witness = _w };
        };
    } forEach ([_cands, [], { _x distance _perp }, "ASCEND"] call BIS_fnc_sortBy);
};

if (!_witnessed) exitWith {
    if (_type == "kill") then {
        diag_log format ["[CO][CRIME] Unwitnessed %1 by %2 — no consequences.", _type, _perp];
    };
};

// ---- Consequences --------------------------------------------------
private _wantedAdd = switch (_type) do {
    case "kill":  { missionNamespace getVariable ["CO_crime_killWanted", 60] };
    case "wound": { missionNamespace getVariable ["CO_crime_woundWanted", 40] };
    default       { missionNamespace getVariable ["CO_crime_gunfireWanted", 10] };
};
private _heat = switch (_type) do {
    case "kill":  { 85 };
    case "wound": { 70 };
    default       { 45 };
};
private _state = switch (_type) do {
    case "kill":  { "WEAPONS" };
    case "wound": { "PURSUIT" };
    default       { "SUSPICIOUS" };
};

private _wl = ((_perp getVariable ["CO_wantedLevel", 0]) + _wantedAdd) min 100;
_perp setVariable ["CO_wantedLevel", _wl, true];
[_perp] call co_main_fnc_installNonLethalDamage;
[_perp, _state, format ["crime_%1", _type], _heat, grpNull] call co_main_fnc_setEscalationState;
[format ["crime_%1", _type]] call co_main_fnc_kpi;

if (isPlayer _perp) then {
    private _msg = switch (_type) do {
        case "kill":  { "Witnessed: killing of an occupation soldier. You are a marked man." };
        case "wound": { "Witnessed: attack on occupation forces. Wanted level raised." };
        default       { "Gunfire reported nearby. Patrols are alert." };
    };
    [_msg] remoteExecCall ["systemChat", _perp];
};

// ---- Town alert level ----------------------------------------------
if (!isNil "CO_policeTownPosts") then {
    private _bestIdx = -1;
    private _bestD = 900;
    private _bestCenter = [0,0,0];
    private _bestRadius = 400;
    {
        private _d = _refPos distance2D (_x select 0);
        if (_d < _bestD) then {
            _bestD = _d;
            _bestIdx = _forEachIndex;
            _bestCenter = _x select 0;
            _bestRadius = _x select 1;
        };
    } forEach CO_policeTownPosts;
    if (_bestIdx >= 0) then {
        if (isNil "CO_townAlertLevels") then { CO_townAlertLevels = createHashMap };
        private _inc = if (_type == "gunfire") then { 1 } else { 2 };
        private _cur = CO_townAlertLevels getOrDefault [_bestIdx, [0, 0]];
        private _lvl = if ((_cur select 1) > time) then { _cur select 0 } else { 0 };
        CO_townAlertLevels set [_bestIdx, [(_lvl + _inc) min 3, time + 600]];
        diag_log format ["[CO][CRIME] Town %1 alert level -> %2 (%3).", _bestIdx, (_lvl + _inc) min 3, _type];
        if (_type in ["kill", "wound"]) then {
            [
                _bestIdx,
                _bestCenter,
                _bestRadius,
                missionNamespace getVariable ["CO_lockdown_duration", 600],
                missionNamespace getVariable ["CO_lockdown_extraPatrols", 2]
            ] call co_main_fnc_spawnLockdownPatrol;
        };
    };
};

// ---- Retaliation fan-out -------------------------------------------
// Kills/wounds arm every nearby security group against the perp.
// Gunfire only alerts the witness's own group (investigate posture).
private _armGroup = {
    params ["_grp", "_weaponsFree"];
    _grp setVariable ["CO_retaliateTarget", _perp, false];
    _grp setVariable ["CO_retaliateUntil", time + 120, false];
    private _isBusGrp = (_grp getVariable ["CO_isBusDriverGrp", false]) ||
                        (_grp getVariable ["CO_isBusEscortGrp", false]);
    if (_isBusGrp) then {
        private _bus = _grp getVariable ["CO_transportVehicle", objNull];
        if (!isNull _bus && alive _bus) then {
            _bus setVariable ["CO_busEmergencyTarget", _perp, false];
            _bus setVariable ["CO_busEmergencyUntil", time + 90, false];
            _bus setVariable ["CO_busEmergencyWeapons", _weaponsFree, false];
        };
    };
};

if (_type in ["kill", "wound"]) then {
    {
        private _grp = _x;
        if ((_grp getVariable ["CO_faction", ""]) in ["CRN_ENF", "POLICE"]) then {
            private _lead = leader _grp;
            if (!isNull _lead && alive _lead && (_lead distance2D _refPos) < 200) then {
                [_grp, true] call _armGroup;
            };
        };
    } forEach allGroups;
} else {
    if (!isNull _witness) then {
        [group _witness, false] call _armGroup;
    };
};
