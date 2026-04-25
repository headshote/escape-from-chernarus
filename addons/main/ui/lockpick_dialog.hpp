// ============================================================
// lockpick_dialog.hpp
// Displays a 4-key sequence for the lockpick minigame.
// ============================================================

class CO_LockpickDialog {
    idd = 9202;
    movingEnable = false;
    onLoad = "uiNamespace setVariable ['CO_LockpickDlg', _this select 0]";

    class Controls {
        class Background: RscText {
            idc = -1;
            colorBackground[] = {0.05, 0.05, 0.05, 0.88};
            x = 0.25; y = 0.3; w = 0.5; h = 0.35;
        };
        class Title: RscText {
            idc = 400;
            text = "PICK THE LOCK";
            colorText[] = {0.9, 0.8, 0.1, 1};
            style = 2; // ST_CENTER
            x = 0.3; y = 0.33; w = 0.4; h = 0.055;
        };
        class SequenceLabel: RscText {
            idc = 401;
            text = "";
            colorText[] = {1, 1, 1, 1};
            style = 2;
            x = 0.28; y = 0.40; w = 0.44; h = 0.06;
        };
        class Prompt: RscText {
            idc = 402;
            text = "Watch the sequence, then press the keys!";
            colorText[] = {0.7, 0.7, 0.7, 1};
            style = 2;
            x = 0.28; y = 0.50; w = 0.44; h = 0.04;
        };
        class StepIndicator: RscText {
            idc = 403;
            text = "";
            colorText[] = {0.3, 0.9, 0.3, 1};
            style = 2;
            x = 0.28; y = 0.56; w = 0.44; h = 0.04;
        };
    };
};
