class CO_WrangleDialog {
    idd = 9201;
    movingEnable = false;
    onLoad = "uiNamespace setVariable ['CO_WrangleDlg', _this select 0]";

    class Controls {
        class Title: RscText {
            idc = 100;
            text = "RESIST!";
            colorText[] = {1,0.1,0.1,1};
            x = 0.3; y = 0.1; w = 0.4; h = 0.06;
        };
        class BarBackground: RscText {
            idc = 200;
            colorBackground[] = {0.2,0.2,0.2,0.9};
            x = 0.2; y = 0.45; w = 0.6; h = 0.06;
        };
        class StruggleBar: RscText {
            idc = 201;
            colorBackground[] = {0.9, 0.2, 0.1, 1};
            x = 0.2; y = 0.45; w = 0.6; h = 0.06; // shrinks via script
        };
        class InstructText: RscText {
            idc = 300;
            text = "Spam [F] to break free!";
            x = 0.3; y = 0.55; w = 0.4; h = 0.04;
        };
    };
};