// ============================================================
// fn_installCrimeWitness.sqf — server-side (units are server-local)
//
// Installs the three event handlers that feed fn_reportCrime on a
// TCK/POLICE unit, plus the group retaliation marker previously
// set inline in fn_initHostileUnit:
//
//   Hit       → group retaliation vars + reportCrime "wound"
//   Killed    → reportCrime "kill"
//   FiredNear → reportCrime "gunfire" (this unit is the witness)
//
// Applied by fn_initHostileUnit (all TCK) and by the police
// spawners, so police officers and gendarmerie foot patrols
// witness crimes exactly like enforcers do.
//
// params: [_unit]
// ============================================================
params [["_unit", objNull]];

if (isNull _unit) exitWith {};
if (_unit getVariable ["CO_crimeWitnessInstalled", false]) exitWith {};
_unit setVariable ["CO_crimeWitnessInstalled", true, false];

_unit addEventHandler ["Hit", {
    params ["_victim", "_source", "_damage", "_instigator"];
    private _src = if (!isNull _instigator) then { _instigator } else { _source };
    if (isNull _src || _src == _victim || !alive _src) exitWith {};
    // Resolve vehicle kills to the actual man behind the wheel/trigger.
    if (!(_src isKindOf "CAManBase")) then {
        private _d = driver _src;
        if (!isNull _d) then { _src = _d };
    };
    if (!(isPlayer _src || side _src == civilian)) exitWith {};
    if ((group _src getVariable ["CO_faction", ""]) in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) exitWith {};

    // Retaliation marker consumed by fn_tckGlobalAggression and the
    // bus emergency check in fn_busAgroLoop.
    private _grp = group _victim;
    _grp setVariable ["CO_retaliateTarget", _src, false];
    _grp setVariable ["CO_retaliateUntil", time + 90, false];
    if ((_grp getVariable ["CO_isBusDriverGrp", false]) || (_grp getVariable ["CO_isBusEscortGrp", false])) then {
        private _bus = _grp getVariable ["CO_transportVehicle", objNull];
        if (!isNull _bus && alive _bus) then {
            _bus setVariable ["CO_busEmergencyTarget", _src, false];
            _bus setVariable ["CO_busEmergencyUntil", time + 90, false];
            _bus setVariable ["CO_busEmergencyWeapons", true, false];
        };
    };

    [_src, _victim, "wound", _victim] call co_main_fnc_reportCrime;
}];

_unit addEventHandler ["Killed", {
    params ["_killed", "_killer", "_instigator"];
    private _src = if (!isNull _instigator) then { _instigator } else { _killer };
    if (isNull _src || _src == _killed) exitWith {};
    if (!(_src isKindOf "CAManBase")) then {
        private _d = driver _src;
        if (!isNull _d) then { _src = _d };
    };
    if (isNull _src || !(isPlayer _src || side _src == civilian)) exitWith {};
    if ((group _src getVariable ["CO_faction", ""]) in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) exitWith {};

    private _grp = group _killed;
    if ((_grp getVariable ["CO_isBusDriverGrp", false]) || (_grp getVariable ["CO_isBusEscortGrp", false])) then {
        private _bus = _grp getVariable ["CO_transportVehicle", objNull];
        if (!isNull _bus && alive _bus) then {
            _bus setVariable ["CO_busEmergencyTarget", _src, false];
            _bus setVariable ["CO_busEmergencyUntil", time + 90, false];
            _bus setVariable ["CO_busEmergencyWeapons", true, false];
        };
    };

    [_src, _killed, "kill"] call co_main_fnc_reportCrime;
}];

// FiredNear triggers for any weapon discharged within ~69 m of the
// unit. Heavily throttled per witness — one report per 12 s is plenty
// for the "gunshots in town" pressure effect.
_unit addEventHandler ["FiredNear", {
    params ["_unit", "_firer", "_distance"];
    if ((time - (_unit getVariable ["CO_nextFiredNearAt", -999])) < 0) exitWith {};
    if (isNull _firer || _firer == _unit) exitWith {};
    private _man = _firer;
    if (!(_man isKindOf "CAManBase")) then {
        private _d = driver _firer;
        if (isNull _d) exitWith {};
        _man = _d;
    };
    if (!(isPlayer _man || side _man == civilian)) exitWith {};
    if (captive _man) exitWith {};
    if ((group _man getVariable ["CO_faction", ""]) in ["CRN_ENF","POLICE","CRN_FRONT","RUS_ADV"]) exitWith {};

    _unit setVariable ["CO_nextFiredNearAt", time + 12, false];
    [_man, objNull, "gunfire", _unit] call co_main_fnc_reportCrime;
}];
