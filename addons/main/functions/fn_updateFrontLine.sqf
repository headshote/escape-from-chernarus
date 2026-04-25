// fn_updateFrontLine.sqf
// Updates map markers to show current Russian advance front line.
// Called from fn_russianAdvance loop after each wave.

// Create or update front line marker
if (isNil "CO_frontMarker") then {
    CO_frontMarker = createMarker ["co_frontline", [CO_rus_advanceFront, 7000, 0]];
    CO_frontMarker setMarkerShape "LINE";
    CO_frontMarker setMarkerBrush "Solid";
    CO_frontMarker setMarkerColor "ColorRed";
    CO_frontMarker setMarkerSize [10, 6000];
    CO_frontMarker setMarkerText "FRONT LINE";
} else {
    CO_frontMarker setMarkerPos [CO_rus_advanceFront, 7000, 0];
};

// Broadcast new front position to all clients
publicVariable "CO_rus_advanceFront";
