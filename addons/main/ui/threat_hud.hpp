// ============================================================
// threat_hud.hpp — persistent threat/status HUD (repair R2-a)
//
// Shown via cutRsc on a dedicated layer by fn_heatHud. Replaces
// the old hintSilent display, which faded out seconds after every
// update and shared the single hint channel with everything else
// ("a tooltip that flashes occasionally").
//
// The single structured-text control is positioned at runtime by
// fn_heatHud using safezone coordinates, so the x/y/w/h here are
// only placeholders. Content is set via ctrlSetStructuredText.
// ============================================================

class RscTitles {
    class CO_ThreatHUD {
        idd = 9400;
        duration = 1e+011;   // effectively forever; fn_heatHud re-cuts if lost
        fadeIn = 0;
        fadeOut = 0;
        onLoad = "uiNamespace setVariable ['CO_ThreatHUD_display', _this select 0];";

        class controls {
            class CO_ThreatText : RscStructuredText {
                idc = 9401;
                text = "";
                x = 0.62;
                y = 0.05;
                w = 0.35;
                h = 0.22;
                colorBackground[] = {0, 0, 0, 0};
            };
        };
    };
};
