class CfgPatches {
    class co_main {
        name = "Chernarus Occupation - Main";
        author = "YourNameHere";
        url = "";
        requiredVersion = 1.98;
        requiredAddons[] = {
            "cba_main",
            "cup_terrains_core",
            "cup_terrains_cup_chernarus_a3"
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
    class CO_bus_totalCruising {
        value = 30; min = 5; max = 80;
        typeName = "SCALAR";
        displayName = "Total Cruising Buses";
        category = "Occupation";
    };
    // ... all others follow this pattern
};

class CfgFunctions {
    class CO {
        class Main {
            file = "co_main\functions";

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
            class showEscapeUnlockScreen {};
            class crowdResistance  {};
            class adminPanel       {};
            class enduranceBar     {};
            class frontMilitary    {};
        };
    };
};

// Include UI dialog definitions
#include "ui\lockpick_dialog.hpp"
#include "ui\wrangle_dialog.hpp"
#include "ui\admin_panel.hpp"