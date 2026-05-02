class CfgPatches {
    class co_main {
        name = "Chernarus Occupation - Main";
        author = "YourNameHere";
        url = "";
        requiredVersion = 1.98;
        requiredAddons[] = {
            "cba_main"
        };
        units[] = {};
        weapons[] = {};
    };
};

class CO_AdminSettings {
    // One entry per variable — abbreviated for clarity; follow same pattern
    class CO_checkpoint_includeSmall {
        value = 0; typeName = "BOOL";
        displayName = "Checkpoints: Small Roads";
        description = "Adds checkpoints between small settlements. Greatly raises difficulty.";
        category = "Checkpoints";
    };
    class CO_bus_totalCruising {
        value = 30; min = 0; max = 80; typeName = "SCALAR";
        displayName = "Total Cruising Buses";
        category = "Buses";
    };
    class CO_front_depthRows {
        value = 2; min = 1; max = 4; typeName = "SCALAR";
        displayName = "Front Defense Depth (rows)";
        category = "Eastern Front";
    };
    class CO_border_postSpacing {
        value = 600; min = 200; max = 1500; typeName = "SCALAR";
        displayName = "Border Post Spacing (m)";
        description = "Lower = more posts = harder to escape.";
        category = "Border";
    };
    class CO_checkpoint_hostilesPerPost {
        value = 4; min = 1; max = 12;
        typeName = "SCALAR";
        displayName = "Hostiles per Checkpoint";
        category = "Occupation";
    };
    // ... all others follow this pattern
};

class CfgFunctions {
    class co_main {
        class Main {
            file = "\main\functions";

            class init             {};
            class initServer       {};
            class initClient       {};
            class factionRelations {};
            class buildRoadGraph   {};
            class placeCheckpoints {};
            class stampCheckpoint  {};
            class stampFortification {};
            class spawnFortGuards  {};
            class spawnRovingGuards{};
            class buildBorderForts {};
            class buildEasternFront{};
            class buildAirfieldCamp{};
            class buildBusRoutes   {};
            class spawnAllBuses    {};
            class spawnBusOnRoute  {};
            class busAgroLoop      {};
            class initHostileUnit  {};
            class checkpointAlert  {};
            class civilianAI       {};
            class trafficSystem    {};
            class russianAdvance   {};
            class spawnRussianWave {};
            class russianAdvanceWaypoints {};
            class checkTownCapture {};
            class frontCollapse    {};
            class prisonSequence   {};
            class transportToTraining {};
            class trainingPhase    {};
            class trainingDrills   {};
            class deployToFront    {};
            class transportToDetention {};
            class spawnDetentionGuards {};
            class desertionMonitor {};
            class wrangleMinigame  {};
            class minigame_lockpick{};
            class disguise         {};
            class policeRecognise  {};
            class borderPatrol     {};
            class borderAlert      {};
            class checkEscapeUnlock{};
            class unlockResistanceRespawn {};
            class spawnResistanceBike {};
            class applyMeleeHit   {};
            class applyKnockout   {};
            class showEscapeUnlockScreen {};
            class crowdResistance  {};
            class adminPanel       {};
            class enduranceBar     {};
            class frontMilitary    {};
            class policePatrols    {};
            class spawnWeaponCaches{};
            class borderPatrolWaypoints {};
            class enforcerRetreatFromTown {};
            class alertEnforcers   {};
            class alertNearbyGuards{};
            class prisonEscape     {};
            class initHC           {};
            class registerHC       {};
            class showDetentionHUD {};
            class showTrainingHUD  {};
            class showFrontDeployHUD {};
            class updateFrontLine  {};
            class buses            {};
            class checkpoints      {};
        };
    };
};

// UI control bases for dialog classes included below.
// Addon Builder/CfgConvert requires these base classes to exist at parse time.
class RscText {
    access = 0;
    type = 0;
    idc = -1;
    style = 0;
    linespacing = 1;
    colorBackground[] = {0,0,0,0};
    colorText[] = {1,1,1,1};
    text = "";
    shadow = 2;
    font = "RobotoCondensed";
    SizeEx = 0.03;
    fixedWidth = 0;
};

class RscSlider {
    access = 0;
    type = 43;
    style = 1024;
    idc = -1;
    color[] = {1,1,1,0.8};
    colorActive[] = {1,1,1,1};
};

class RscCheckBox {
    access = 0;
    type = 77;
    style = 0;
    idc = -1;
    checked = 0;
    color[] = {1,1,1,0.7};
    colorFocused[] = {1,1,1,1};
    colorHover[] = {1,1,1,1};
    colorPressed[] = {1,1,1,1};
    colorDisabled[] = {1,1,1,0.2};
    colorBackground[] = {0,0,0,0};
};

class RscButton {
    access = 0;
    type = 1;
    style = 2;
    idc = -1;
    text = "";
    font = "RobotoCondensed";
    sizeEx = 0.03;
    colorText[] = {1,1,1,1};
    colorDisabled[] = {0.4,0.4,0.4,1};
    colorBackground[] = {0.2,0.2,0.2,0.8};
    colorBackgroundActive[] = {0.3,0.3,0.3,1};
    colorBackgroundDisabled[] = {0,0,0,0.5};
    colorFocused[] = {0.3,0.3,0.3,1};
    colorShadow[] = {0,0,0,0};
    colorBorder[] = {0,0,0,1};
    borderSize = 0;
    soundEnter[] = {"\A3\ui_f\data\sound\RscButton\soundEnter",0.09,1};
    soundPush[] = {"\A3\ui_f\data\sound\RscButton\soundPush",0.09,1};
    soundClick[] = {"\A3\ui_f\data\sound\RscButton\soundClick",0.09,1};
    soundEscape[] = {"\A3\ui_f\data\sound\RscButton\soundEscape",0.09,1};
    shadow = 2;
    offsetX = 0;
    offsetY = 0;
    offsetPressedX = 0;
    offsetPressedY = 0;
};

// Include UI dialog definitions
#include "ui\lockpick_dialog.hpp"
#include "ui\wrangle_dialog.hpp"
#include "ui\admin_panel.hpp"