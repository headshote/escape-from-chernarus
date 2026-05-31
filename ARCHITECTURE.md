# Chernarus Occupation — Architecture Reference

## Repository Layout

```
@ChernOccupation/
├── addons/
│   ├── main/                  ← addon source (pack to co_main.pbo)
│   │   ├── $PBOPREFIX$        ← contains "main"
│   │   ├── config.cpp
│   │   ├── functions/         ← all fn_*.sqf (60 files)
│   │   └── ui/                ← HPP dialog definitions
│   └── co_main.pbo            ← built addon (gitignored / output)
├── missions/
│   └── ChernOccupation.Chernarus/
│       ├── mission.sqm
│       ├── init.sqf
│       ├── description.ext
│       └── CO_adminDefaults.sqf
├── local_start_server.bat
├── GAMEPLAY.md
└── ARCHITECTURE.md
```

---

## Addon Structure (`co_main`)

### `config.cpp`

Declares three major config classes:

**`CfgPatches / co_main`**
- `requiredAddons[] = {"cba_main"}` — only CBA is a hard config dependency.
  CUP Terrains is required at mission level, not at addon config level.

**`CfgFunctions / co_main / Main`**
- `file = "\main\functions"` — absolute virtual path using the packed PBO prefix.
- All 60 functions registered as `class fnName {};`.
- Naming convention: source file `fn_FOO.sqf` → function `co_main_fnc_FOO`.

**UI base classes + dialog includes**
- `RscText`, `RscSlider`, `RscCheckBox`, `RscButton` must be declared in
  `config.cpp` before the `#include` directives, because Addon Builder parses
  the addon config without access to A3's default UI classes.
- Three dialogs included: `ui/lockpick_dialog.hpp`, `ui/wrangle_dialog.hpp`,
  `ui/admin_panel.hpp`.

---

## Init Chain

### Server (`isServer`)
```
init.sqf
  └── execVM "CO_adminDefaults.sqf"   (sets + broadcasts all globals)
  └── co_main_fnc_initServer
        ├── factionRelations           (setFriend matrix)
        ├── buildRoadGraph             → CO_roadGraph, CO_settlements
        ├── placeCheckpoints           (reads graph)
        ├── buildBorderForts
        ├── buildEasternFront
        ├── buildAirfieldCamp
        ├── buildBusRoutes             (reads graph → CO_busRoutes)
        ├── spawnAllBuses
        ├── civilianAI
        ├── trafficSystem
        ├── frontMilitary              (initial CRN_FRONT defense line)
        ├── spawn russianAdvance       (async loop)
        ├── spawn desertionMonitor     (async loop)
        ├── spawn policePatrols        (async loop)
        └── spawnWeaponCaches
```

> Police detain trigger spawns `fn_policeFootChase` per-patrol: stop car →
> force-dismount driver + passenger → on-foot melee chase → on knockout,
> NPC handoff to `transportToDetention` or player handoff to
> `spawnCaptureTransport` → reboard. Replaces the prior `doMove` from inside
> the cargo seat which never made the partner disembark.

### Client (`hasInterface`)
```
co_main_fnc_initClient
  ├── wait for server globals
  ├── enduranceBar                     (CBA per-frame handler)
  ├── disguise EH setup                (CBA event handler)
  └── police recognition loop          (every 4 s)
```

### Player-local respawn bootstrap
```
initPlayerLocal.sqf
  ├── registers the baseline civilian respawn via mission marker respawn_civilian
  ├── checks profileNamespace for escaped-player unlock state
  ├── adds a Resistance Fighter respawn position for that player only when unlocked
  └── refreshes the per-player respawn list on mission respawn
```

### Headless Client (`!hasInterface && !isServer`)
```
co_main_fnc_initHC
  └── every 30 s: transfer AI group ownership from server to HC
```

---

## Road Graph System

`fn_buildRoadGraph` runs once on server. It creates two globals:

- **`CO_settlements`**: array of `[name, pos, type]` for 17 named locations.
  Types: `"large"` | `"medium"` | `"small"`.
- **`CO_roadGraph`**: array of connection pairs. A pair is created for every
  two settlements within 400–3800 m where `roadAt midpoint` returns a road.
  Entry format: `[nameA, nameB, midpoint, typeA, typeB]`.

Downstream consumers:
- `fn_placeCheckpoints` — stamps a checkpoint on each road-graph mid-point.
- `fn_buildBusRoutes` — derives bus routes from graph pairs.
- `fn_civilianAI` — uses `CO_settlements` positions as spawn zones.

---

## Key Globals

All set in `CO_adminDefaults.sqf`, broadcast with `publicVariable`.

| Global | Type | Purpose |
|--------|------|---------|
| `CO_roadGraph` | Array | Settlement connectivity, built at init |
| `CO_settlements` | Array | Named settlement list with positions |
| `CO_busRoutes` | Array | Derived bus route segments |
| `CO_rus_advanceFront` | Number | Current X-coord of Russian front |
| `CO_front_unitsRemaining` | Number | CRN_FRONT alive count |
| `CO_checkpoint_hostilesPerPost` | Number | Guards per checkpoint |
| `CO_checkpoint_includeSmall` | Bool | Include small-road checkpoints |
| `CO_bus_totalCruising` | Number | Total buses on map |
| `CO_bus_hostilesPerBus` | Number | Guards per bus |
| `CO_bus_townGuaranteed` | Number | Min buses per large town |
| `CO_border_postSpacing` | Number | Meters between border posts |
| `CO_rus_waveCooldown` | Number | Seconds between Russian waves |
| `CO_rus_unitsPerWave` | Number | Infantry per wave |
| `CO_police_carStopChance` | Number | 0–1 probability per traffic check |
| `CO_police_active` | Bool | Enable/disable police patrols |
| `CO_adminUIDs` | Array | Steam64 UIDs allowed to open admin panel |

Per-player variables (set via `setVariable`):
- `CO_wantedLevel` (0–100, broadcast true)
- `CO_detainPhase` (`"detention"` | `"training"` | `"front"`)
- `CO_isFemale` (bool, exempts from checkpoint targeting)
- `CO_disguiseLevel` (0–3)
- `CO_endurance` (0–100, client-local)
- `CO_wrangleResult` (`"escaped"` | `"captured"`, cleared after read)

---

## Faction Relations

Set in `fn_factionRelations` via `setFriend`:

| A | B | Friends |
|---|---|---------|
| west | east | No (ENF/FRONT vs Russians) |
| west | civilian | Yes (ENF friendly to civs, civs don't flee) |
| west | guer | No (ENF vs Resistance) |
| east | guer | No (Russians vs Resistance) |
| guer | civilian | Yes |

Both CRN_ENF and CRN_FRONT groups are `createGroup west`. They are
disambiguated at runtime by `group getVariable "CO_faction"`.

---

## Conscription Pipeline Detail

```
fn_prisonSequence(_captive)
  ├── phase = "detention"
  ├── showDetentionHUD (remoteExec to player)
  ├── CBA_fnc_waitUntilAndExecute: 300 s or captive cleared
  │     if still captive → fn_transportToTraining
  │
  └── fn_transportToTraining(_captive)
        ├── move to airfield
        ├── showTrainingHUD
        ├── fn_trainingPhase → fn_trainingDrills
        ├── CBA_fnc_waitUntilAndExecute: 600 s
        └── fn_deployToFront → add to CRN_FRONT group
```

Desertion: `fn_desertionMonitor` (async loop) checks each CRN_FRONT soldier
every 10 s. If >500 m from `CO_rus_advanceFront` X-coord, marks as deserter.

---

## Dialog IDDs

| Dialog | IDD | File |
|--------|-----|------|
| CO_WrangleDialog | 9201 | `ui/wrangle_dialog.hpp` |
| CO_LockpickDialog | 9202 | `ui/lockpick_dialog.hpp` |
| CO_AdminPanel | 9300 | `ui/admin_panel.hpp` |

Dialog references use `uiNamespace getVariable` to retrieve the display object
set in `onLoad`. Example: `uiNamespace getVariable "CO_AdminPanelDlg"`.

---

## Build Process

1. **Addon PBO**: pack `addons/main` → output `addons/co_main.pbo`.
   - The `$PBOPREFIX$` file must contain exactly `main` (no newline issues).
   - The output filename stays `co_main.pbo`, but the internal virtual prefix is `main`.
     The function namespace remains `co_main_fnc_*`; only the file lookup root is `main`.
   - In Addon Builder, add `*.sqf;*.hpp` to **List of files to copy directly**.
     If you skip that step, the PBO will contain `config.bin` but omit the SQF
     sources, which produces a startup missing-script error.
   - Keep the output filename set to `co_main.pbo`. Do not also ship `main.pbo`.
   - After every build, ensure only `co_main.pbo` is present in `addons/`.
     Any stale `main.pbo` from a mis-named build will be loaded by Arma too
     and will override the correct one with broken function paths.
   - `tools/build_addon.ps1` wraps Addon Builder with the correct include rules
     and writes the rebuilt output back as `addons/co_main.pbo`.
   - `local_start_server.bat` now calls `tools/build_addon.ps1 -SkipIfUpToDate`
     automatically before validation, so local dedicated launches do not run
     against stale addon PBOs.
   - Run `tools/validate_build.ps1` after every rebuild. It verifies the exact
     source prefix, rejects duplicate PBOs, verifies the embedded PBO prefix,
     checks the `CfgFunctions.file` path, and confirms that the built PBO header
     actually contains the `fn_*.sqf` filenames from `addons/main/functions/`.

2. **Mission PBO**: pack `missions/ChernOccupation.Chernarus` → `ChernOccupation.Chernarus.pbo`.
   - `mission.sqm` is mandatory. Without it, the mission has no playable slots,
     clients hang in the connection flow, and the server repeatedly re-reads the
     mission from bank.
   - Copy to `<Arma3Server>/mpmissions/`.
   - Rebuild mission PBO whenever `init.sqf`, `description.ext`, or
     `CO_adminDefaults.sqf` changes.
   - Run `tools/validate_mission.ps1` after rebuilding. It checks that the source
     mission contains `mission.sqm`, that at least one playable slot exists, and
     that the deployed mission PBO header contains the core mission files.

3. **Local Dev Server**: `local_start_server.bat` does not rely on the mission PBO.
   - It stages `missions/ChernOccupation.Chernarus` into the dedicated server as
     an unpacked mission folder named `ChernOccupationLocal.Chernarus`.
   - This avoids Addon Builder mission-packing issues during local iteration and
     uses `tools/stage_local_mission.ps1` plus `tools/validate_mission.ps1` on
     every launch.
   - Mission spawn selection uses Arma's supported `BASE` respawn flow:
     `mission.sqm` provides the civilian `respawn_civilian` marker and
     `initPlayerLocal.sqf` adds the gated resistance respawn dynamically via
     `BIS_fnc_addRespawnPosition` after escape unlock.

4. **Launcher**: `local_start_server.bat` validates paths, generates `server.cfg`
   and `basic.cfg` under `.server_runtime/`, and launches `arma3server_x64.exe`.

---

## CBA Usage

CBA is required at runtime (`requiredAddons = {"cba_main"}`). Key APIs used:

| API | Where |
|-----|-------|
| `CBA_fnc_addPerFrameHandler` | `fn_enduranceBar` |
| `CBA_fnc_waitUntilAndExecute` | `fn_prisonSequence`, `fn_crowdResistance`, `fn_trainingPhase` |
| `CBA_fnc_addEventHandler` | `fn_disguise` |

VS Code will show false-positive CBA namespace errors. These do not affect builds.

---

## Adding a New Function

1. Create `addons/main/functions/fn_NEWNAME.sqf`.
2. Add `class NEWNAME {};` inside `CfgFunctions / co_main / Main` in `config.cpp`.
3. Call as `[] call co_main_fnc_NEWNAME` from SQF.
4. Rebuild `co_main.pbo`.

---

## Round 9 � Population caps + dismount fixes

- **RUS_ADV population cap.** `CO_rus_maxActive` (default 80, broadcast via `fn_initServer` + `CO_adminDefaults.sqf`). `fn_spawnRussianWave` and `fn_spawnRussianReplacement` both short-circuit when the live RUS_ADV count is at or above the cap. This bounds the AI simulation cost in the north sector (Krasnostav) where the wave + 1:1 replacement spawners previously produced unbounded growth.
- **Russian hostility tick throttle.** `fn_russianHostilityTick` now sleeps 8 s (was 5 s) and limits `reveal`/`doFire`/`fireAtTarget` issuance to the 5 nearest foot units and 2 nearest vehicles per player, sorted by distance. Caps network/command-queue spam.
- **Police foot chase.** New `fn_policeFootChase` (registered in `CfgFunctions`). Called from `fn_policePatrols` on detain trigger; replaces the previous in-vehicle `doMove` + nearest-unit-2.5m wait pattern that left passengers stuck in cargo.
- **Bus idle dismount.** `fn_busAgroLoop` switched to speed-based stuck detection (`speed _veh < 1.8 km/h`), 20 s threshold, full-escort dismount (no 2-escort cap). Idle-dismount applies in both `traveling` and `approaching` states.
- **Boot camp range.** Quest targets relocated downrange east of the existing visible static target line at the training field (`CO_trainingFieldPos vectorAdd [55..60, -24..-16]`), facing west toward the firing line with `mil_dot` per-target markers. Rack now also stocks 1000 backpacks + 1000 harness vests via `addBackpackCargoGlobal` / `addItemCargoGlobal`.

