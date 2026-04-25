// ============================================================
// admin_panel.hpp
// Admin control panel dialog — sliders + checkboxes
// ============================================================

#define BTN_H  0.04
#define LBL_H  0.035
#define ROW(n) (0.08 + (n) * 0.055)
#define LEFT   0.12
#define MID    0.45
#define RIGHT  0.72

class CO_AdminPanel {
    idd = 9300;
    movingEnable = true;
    onLoad = "uiNamespace setVariable ['CO_AdminPanelDlg', _this select 0]";

    class Controls {
        // --- Background ---
        class BG: RscText {
            idc = -1;
            colorBackground[] = {0.05,0.05,0.08,0.92};
            x = 0.10; y = 0.05; w = 0.80; h = 0.92;
        };
        class TitleBar: RscText {
            idc = -1;
            text = "ADMIN CONTROL PANEL";
            colorText[] = {1,0.85,0.2,1};
            colorBackground[] = {0.1,0.1,0.15,1};
            style = 2;
            x = 0.10; y = 0.05; w = 0.80; h = 0.045;
        };

        // ---- Checkpoint section ----
        class Lbl_CP: RscText {
            idc = -1; text = "CHECKPOINTS";
            colorText[] = {0.6,0.8,1,1};
            x = LEFT; y = ROW(0); w = 0.30; h = LBL_H;
        };
        class Lbl_CPCount: RscText {
            idc = -1; text = "Guards per post:";
            colorText[] = {1,1,1,1};
            x = LEFT; y = ROW(1); w = 0.25; h = LBL_H;
        };
        class Sld_CPCount: RscSlider {
            idc = 301;
            x = MID; y = ROW(1); w = 0.25; h = LBL_H;
            sliderPosition = 4; sliderSpeed = 1;
            onSliderPosChanged = "CO_checkpoint_hostilesPerPost = round sliderPosition (_this select 0); publicVariable 'CO_checkpoint_hostilesPerPost';";
        };
        class Val_CPCount: RscText {
            idc = 3011;
            text = "4";
            colorText[] = {1,1,0,1};
            x = RIGHT; y = ROW(1); w = 0.06; h = LBL_H;
        };
        class Lbl_CPSmall: RscText {
            idc = -1; text = "Include small roads:";
            colorText[] = {1,1,1,1};
            x = LEFT; y = ROW(2); w = 0.25; h = LBL_H;
        };
        class Chk_CPSmall: RscCheckBox {
            idc = 302;
            x = MID; y = ROW(2); w = LBL_H; h = LBL_H;
            onCheckedChanged = "CO_checkpoint_includeSmall = checkboxChecked (_this select 0); publicVariable 'CO_checkpoint_includeSmall';";
        };

        // ---- Bus section ----
        class Lbl_BUS: RscText {
            idc = -1; text = "BUSES";
            colorText[] = {0.6,0.8,1,1};
            x = LEFT; y = ROW(3); w = 0.30; h = LBL_H;
        };
        class Lbl_BusTotal: RscText {
            idc = -1; text = "Total cruising buses:";
            colorText[] = {1,1,1,1};
            x = LEFT; y = ROW(4); w = 0.25; h = LBL_H;
        };
        class Sld_BusTotal: RscSlider {
            idc = 310;
            x = MID; y = ROW(4); w = 0.25; h = LBL_H;
            sliderPosition = 30; sliderSpeed = 1;
            onSliderPosChanged = "CO_bus_totalCruising = round sliderPosition (_this select 0); publicVariable 'CO_bus_totalCruising';";
        };
        class Val_BusTotal: RscText {
            idc = 3101; text = "30";
            colorText[] = {1,1,0,1};
            x = RIGHT; y = ROW(4); w = 0.06; h = LBL_H;
        };
        class Lbl_BusHostiles: RscText {
            idc = -1; text = "Hostiles per bus:";
            colorText[] = {1,1,1,1};
            x = LEFT; y = ROW(5); w = 0.25; h = LBL_H;
        };
        class Sld_BusHostiles: RscSlider {
            idc = 311;
            x = MID; y = ROW(5); w = 0.25; h = LBL_H;
            sliderPosition = 5; sliderSpeed = 1;
            onSliderPosChanged = "CO_bus_hostilesPerBus = round sliderPosition (_this select 0); publicVariable 'CO_bus_hostilesPerBus';";
        };
        class Val_BusHostiles: RscText {
            idc = 3111; text = "5";
            colorText[] = {1,1,0,1};
            x = RIGHT; y = ROW(5); w = 0.06; h = LBL_H;
        };
        class Lbl_BusTown: RscText {
            idc = -1; text = "Min town buses (large):";
            colorText[] = {1,1,1,1};
            x = LEFT; y = ROW(6); w = 0.25; h = LBL_H;
        };
        class Sld_BusTown: RscSlider {
            idc = 312;
            x = MID; y = ROW(6); w = 0.25; h = LBL_H;
            sliderPosition = 3; sliderSpeed = 1;
            onSliderPosChanged = "CO_bus_townGuaranteed = round sliderPosition (_this select 0); publicVariable 'CO_bus_townGuaranteed';";
        };
        class Val_BusTown: RscText {
            idc = 3121; text = "3";
            colorText[] = {1,1,0,1};
            x = RIGHT; y = ROW(6); w = 0.06; h = LBL_H;
        };

        // ---- Border section ----
        class Lbl_BOR: RscText {
            idc = -1; text = "BORDER PATROL";
            colorText[] = {0.6,0.8,1,1};
            x = LEFT; y = ROW(7); w = 0.30; h = LBL_H;
        };
        class Lbl_BorSpace: RscText {
            idc = -1; text = "Post spacing (m):";
            colorText[] = {1,1,1,1};
            x = LEFT; y = ROW(8); w = 0.25; h = LBL_H;
        };
        class Sld_BorSpace: RscSlider {
            idc = 320;
            x = MID; y = ROW(8); w = 0.25; h = LBL_H;
            sliderPosition = 600; sliderSpeed = 50;
            onSliderPosChanged = "CO_border_postSpacing = round sliderPosition (_this select 0); publicVariable 'CO_border_postSpacing';";
        };
        class Val_BorSpace: RscText {
            idc = 3201; text = "600";
            colorText[] = {1,1,0,1};
            x = RIGHT; y = ROW(8); w = 0.06; h = LBL_H;
        };

        // ---- Police section ----
        class Lbl_POL: RscText {
            idc = -1; text = "POLICE";
            colorText[] = {0.6,0.8,1,1};
            x = LEFT; y = ROW(9); w = 0.30; h = LBL_H;
        };
        class Lbl_PolStop: RscText {
            idc = -1; text = "Car stop chance (0-1):";
            colorText[] = {1,1,1,1};
            x = LEFT; y = ROW(10); w = 0.25; h = LBL_H;
        };
        class Sld_PolStop: RscSlider {
            idc = 330;
            x = MID; y = ROW(10); w = 0.25; h = LBL_H;
            sliderPosition = 0.05; sliderSpeed = 0.01;
            onSliderPosChanged = "CO_police_carStopChance = sliderPosition (_this select 0); publicVariable 'CO_police_carStopChance';";
        };
        class Val_PolStop: RscText {
            idc = 3301; text = "0.05";
            colorText[] = {1,1,0,1};
            x = RIGHT; y = ROW(10); w = 0.06; h = LBL_H;
        };
        class Lbl_PolActive: RscText {
            idc = -1; text = "Police active:";
            colorText[] = {1,1,1,1};
            x = LEFT; y = ROW(11); w = 0.25; h = LBL_H;
        };
        class Chk_PolActive: RscCheckBox {
            idc = 331;
            x = MID; y = ROW(11); w = LBL_H; h = LBL_H;
            checked = 1;
            onCheckedChanged = "CO_police_active = checkboxChecked (_this select 0); publicVariable 'CO_police_active';";
        };

        // ---- Russian advance ----
        class Lbl_RUS: RscText {
            idc = -1; text = "RUSSIAN ADVANCE";
            colorText[] = {0.6,0.8,1,1};
            x = LEFT; y = ROW(12); w = 0.30; h = LBL_H;
        };
        class Lbl_RusWave: RscText {
            idc = -1; text = "Wave cooldown (s):";
            colorText[] = {1,1,1,1};
            x = LEFT; y = ROW(13); w = 0.25; h = LBL_H;
        };
        class Sld_RusWave: RscSlider {
            idc = 340;
            x = MID; y = ROW(13); w = 0.25; h = LBL_H;
            sliderPosition = 180; sliderSpeed = 10;
            onSliderPosChanged = "CO_rus_waveCooldown = round sliderPosition (_this select 0); publicVariable 'CO_rus_waveCooldown';";
        };
        class Val_RusWave: RscText {
            idc = 3401; text = "180";
            colorText[] = {1,1,0,1};
            x = RIGHT; y = ROW(13); w = 0.06; h = LBL_H;
        };

        // ---- Close button ----
        class BtnClose: RscButton {
            idc = 399;
            text = "CLOSE";
            x = 0.44; y = ROW(15); w = 0.12; h = BTN_H;
            onButtonClick = "closeDialog 0;";
        };
    };
};
