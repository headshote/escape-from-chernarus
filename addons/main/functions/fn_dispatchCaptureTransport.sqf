// ============================================================
// fn_dispatchCaptureTransport.sqf
// Knocks the target out and routes a nearby hostile transport
// (or the shooter's own bus if available) to drag them to a
// detention center. Used by the non-lethal damage flow.
// ============================================================
params [["_shooter", objNull], ["_target", objNull]];

if (!isServer) exitWith {
    [_shooter, _target] remoteExec ["co_main_fnc_dispatchCaptureTransport", 2];
};

if (isNull _target || !alive _target) exitWith {};
if (_target getVariable ["CO_isFemale", false]) exitWith {};
if (_target getVariable ["CO_captureInProgress", false]) exitWith {};
// Already mid-transport (van/bus has them in cargo or is en route).
// Without this guard, residual gunfire from guards after the wrangle
// completed kept re-triggering dispatchCaptureTransport, which yanked
// the player out of the existing van into a new one further down the
// road — the "vehicle keeps getting respawned" bug.
if (_target getVariable ["CO_transportInProgress", false]) exitWith {};
// Already detained and being processed (captive + in any vehicle).
if (captive _target && !isNull (objectParent _target)) exitWith {};

_target setVariable ["CO_captureInProgress", true, true];

// Knock the victim down — keep them captive while they ride/transport
[_shooter, _target, 90, true] call co_main_fnc_applyKnockout;

// Bump wanted level for players hit by police/ENF gunfire
if (isPlayer _target) then {
    private _wl = (_target getVariable ["CO_wantedLevel", 0]) + 30;
    _target setVariable ["CO_wantedLevel", _wl min 100, true];
};

// PLAYERS ALWAYS get a dedicated capture truck. The old "reuse nearest
// bus" path routed the player into a NPC-loading bus that delivered to
// a detention center instead of training, and moveInCargo on a remote
// player owner was unreliable. The dedicated truck flow (fn_spawnCaptureTransport)
// spawns a van at the nearest road, force-teleports the player into
// cargo with retries, and drives to NWAF training. This mirrors what
// the border patrol / SW fort already do for player captures and is
// what the gameplay spec calls for.
if (isPlayer _target) exitWith {
    diag_log format [
        "[CO] Player %1 captured by %2 group — dispatching dedicated truck to training.",
        name _target, (group _shooter) getVariable ["CO_faction", "?"]
    ];
    [_target, group _shooter] call co_main_fnc_spawnCaptureTransport;
};

// NPC civilians: prefer a patrol bus if one is nearby, else dedicated van.
private _shooterGrp = group _shooter;
private _bus = _shooterGrp getVariable ["CO_transportVehicle", objNull];
if (isNull _bus || !alive _bus) then {
    private _nearBuses = (_target nearEntities [["Car","Truck"], 350]) select {
        alive _x && (_x getVariable ["CO_isBusPatrol", false])
    };
    if !(_nearBuses isEqualTo []) then {
        _bus = (
            [_nearBuses, [], { _x distance2D _target }, "ASCEND"] call BIS_fnc_sortBy
        ) select 0;
    };
};

if (isNull _bus) exitWith {
    diag_log format [
        "[CO] No nearby bus for %1 — dispatching dedicated capture transport.",
        name _target
    ];
    [_target, group _shooter] call co_main_fnc_spawnCaptureTransport;
};

private _busGrp = group (driver _bus);

// Pause the bus and walk an escort over to the victim, then load them
[_bus, _busGrp, _target] spawn {
    params ["_bus", "_busGrp", "_target"];

    _bus setVariable ["CO_busState", "engaging", true];

    private _driver = driver _bus;
    if (!isNull _driver) then {
        _driver setVariable ["CO_vehicleChaseDriver", true, false];
        _bus forceSpeed -1;
        _driver doMove (getPosATL _target);

        // Wait for the bus to roll close enough to drop escort
        private _approachDeadline = time + 60;
        waitUntil {
            sleep 1;
            !alive _bus ||
            !alive _target ||
            (_bus distance2D _target) < 35 ||
            time > _approachDeadline
        };

        if (!alive _bus) exitWith {};
        doStop _driver;
        _bus forceSpeed 0;
    };

    // Dismount one or two escorts to drag the victim
    private _escort = (units _busGrp) select {
        alive _x && _x != driver _bus && (vehicle _x == _bus)
    };
    private _draggers = [];
    {
        if (count _draggers >= 2) exitWith {};
        _x allowGetIn false;
        unassignVehicle _x;
        if (vehicle _x == _bus) then { doGetOut _x; moveOut _x; };
        _x doMove (getPosATL _target);
        _draggers pushBack _x;
    } forEach _escort;

    private _dragDeadline = time + 25;
    waitUntil {
        sleep 0.5;
        !alive _bus || !alive _target ||
        (_draggers findIf { alive _x && _x distance _target < 2.6 } >= 0) ||
        time > _dragDeadline
    };

    if (!alive _bus || !alive _target) exitWith {};

    // Load victim
    _target setCaptive true;
    _target moveInCargo _bus;

    // Track in bus captives list
    private _busCaptives = _bus getVariable ["CO_busCaptives", []];
    if !(_target in _busCaptives) then {
        _busCaptives pushBack _target;
        _bus setVariable ["CO_busCaptives", _busCaptives, true];
    };
    _bus setVariable ["CO_busLastCaptureTime", time, true];

    // Reboard the draggers
    {
        if (alive _x) then {
            _x allowGetIn true;
            _x assignAsCargo _bus;
            [_x] orderGetIn true;
            _x doMove (getPosATL _bus);
        };
    } forEach _draggers;

    private _reboardDeadline = time + 12;
    waitUntil {
        sleep 0.5;
        !alive _bus ||
        ({ vehicle _x == _bus } count _draggers) >= ((count _draggers) max 1) ||
        time > _reboardDeadline
    };

    if (!isNull _driver && alive _driver) then {
        _driver setVariable ["CO_vehicleChaseDriver", false, false];
    };

    // Hand off to the existing detention dispatch flow so threshold /
    // cruising logic remains in one place.
    [_target, _busGrp] call co_main_fnc_transportToDetention;
};
