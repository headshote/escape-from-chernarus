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
| CO_ThreatHUD (RscTitles) | 9400 | `ui/threat_hud.hpp` |

`CO_ThreatHUD` is not a dialog: it is a persistent `RscTitles` layer shown via
`cutRsc` on the `CO_ThreatHUDLayer` BIS layer by `fn_heatHud`. Its single
structured-text control (idc 9401) is positioned at runtime with safezone
coordinates and re-cut automatically if the display is lost (respawn/load).
Transition toasts use a second layer, `CO_ToastLayer` (`fn_chaseStinger`).

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

## Round R8 — Police reaction, return-fire, physical detain

- **Melee assaults are now crimes.** `fn_applyMeleeHit` applies damage via
  `setHitPointDamage`, which NEVER fires the "Hit" event handler — so punching a cop
  was invisible to the crime/retaliation system (knocked-out cops woke amnesiac; their
  partners ignored the assault). Melee on a CRN_ENF/POLICE unit now explicitly sets the
  group's `CO_retaliateTarget`/`CO_retaliateUntil` (+ bus emergency) and calls
  `fn_reportCrime` "wound".
- **Knocked-out officers remember.** `fn_applyKnockout` records `CO_lastKnockoutBy`;
  on wake-up, a POLICE/CRN_ENF unit re-arms its group's retaliation against the
  assailant (if still nearby) so they don't get up and wander off.
- **Police retaliation response.** `fn_policeBrain` gained a top-priority block that
  consumes `CO_retaliateTarget` (POLICE were excluded from tckGlobalAggression, so
  nothing was reading it): partner-down / squad-assaulted → chase-and-DETAIN via
  `fn_policeFootChase` (or vehicle pursuit), within 260 m.
- **Return-fire window.** `fn_policeFootChase` now keys the firefight on the player's
  last shot: while they've fired within `CO_police_returnFireWindow` (10 s) officers
  trade fire back (non-lethal-filtered) at any range and the tackle is suppressed; once
  they stop shooting for the whole window officers holster and drop back to
  chase/tackle/detain. Replaces the old WEAPONS-only >18 m volley.
- **`fn_detainSequence`** (new): the physical arrest beat — an officer must be at arm's
  reach (walks up to a target downed at range; aborts and frees the target if none can
  reach), the detainee is forced to a kneeling pose (`Acts_ExecutionVictim_Loop`,
  re-asserted through the hold), THEN `fn_spawnCaptureTransport` is dispatched. No more
  telekinetic grabs. Wired into every conscious player-capture path: police foot chase,
  checkpoint (tackle + downed-at-range), bus hunter (tackle + downed), TCK global
  aggression, and the transport-breakout recapture. NPC capture paths (bus loading,
  transportToDetention) are unchanged. New flag `CO_detainInProgress` (cleared by the
  state watchdog and the respawn wipe).

## Round R7 — Transport overhaul, breakout, town garrisons, formation restored

- **`fn_spawnCaptureTransport` rebuilt.** (a) The crew is now spawned FRESH in its own
  group and claimed at priority 90 — the old version borrowed the driver from the
  capturing group, whose controller kept re-tasking him (even moveInCargo'ing him back
  into his TCK truck mid-route) and whose waypoints the transport overwrote. (b) The
  stuck-watchdog no longer teleports the van: ladder = re-issue route → reverse out →
  after the 3rd failure ONE fallback, the accepted dismount-and-deliver-to-training
  flow (same as flipped/destroyed vans, which still work as before). (c) The drive
  loop resolves to explicit outcomes: arrived / escaped / rescued (crew killed frees
  the captive) / failsafe / dead. (d) Captive rides in **locked cargo**; escaping
  clears the transport state, adds wanted +20, sets SEARCH, publishes the LKP, and the
  crew chases for 45 s (tackle → re-transport). Vans/crews despawn when unobserved.
- **`fn_breakoutMinigame`** (new, client): "Force the cargo latch" self-action while
  in a capture transport — 5-key lockpick-style sequence (reuses CO_LockpickDialog);
  success sets `CO_breakoutAt`, consumed by the transport drive loop; failure = 8 s
  cooldown. Action installed in `fn_initClient` (re-added on respawn).
- **Town TCK behavior** (`fn_spawnAllBuses` / `fn_spawnBusOnRoute` / `fn_busAgroLoop`):
  buses sharing a route get ROTATED route starts (the guaranteed town trucks used to
  all spawn at waypoint 0 nose-to-tail and gridlock into permanent idling); the first
  bus per intra-town route becomes the **town garrison** (`CO_busGarrison`): parks,
  driver stays, squad released as a permanent foot-harassment patrol driven by
  tckGlobalAggression; and the lost `CO_bus_patrolStopInterval` behavior is restored —
  cruising trucks periodically pull over near pedestrians and jump the squad out
  through the normal dismount/hunt/reboard cycle.
- **`fn_tckGlobalAggression`** now refuses to touch units holding a claim of
  priority ≥ 60 (transport crews, AWOL detain squads) — including via the
  retaliation path, which bypasses normal claim acquisition.
- **Parade formation restored.** The training-escape sentinel was drafting the
  saluting recruit dummies and the drill instructor (both CRN_ENF) into pursuits,
  marching the whole formation off the map. They're excluded now, and both anim
  loops self-heal (walk back + re-disable MOVE if displaced).

## Round R6 — Boot camp props, escape leash, AWOL fate roll, respawn wipe

- **Boot camp props are persistent world objects** (`fn_buildTrainingGround`), not
  per-quest-run spawns. Root cause of the vanishing/smoking crate: the old rack was
  created each run at [10,-16] — the exact position of a firing-line sandbag — so it
  clipped, blew up (the smoke), and was also deleted whenever stage 2 ended. Now:
  indestructible rifle rack at [6,-28] (`CO_bootCampRack`/`CO_bootCampRackPos`,
  JIP-persistent pickup action), grenade crate at the pit (`CO_bootCampGrenadeCrate`,
  "Take grenades" action, 500 HandGrenades cargo), wreck + barrel targets at the
  impact area, and two armed range wardens (firing line + pit). Firing-line sandbags
  rotated to dir 90 — parallel to the target line. `fn_bootCampQuest` no longer
  creates or deletes any of these.
- **Training escape leash tunable:** `CO_training_escapeRadius` (default 250 m,
  clamped to the old airfield+30 value) replaces the fixed 380 m in
  `fn_trainingPhase`'s perimeter sentinel.
- **`fn_awolConfrontation`** (new server loop, 2 s tick, launched in `fn_initServer`):
  when armed CRN_ENF/POLICE stand within 12 m of a live AWOL for ~2 s, the squad
  rolls the deserter's fate once (`CO_awol_detainChance`, default 0.5):
  *detain* — cease fire, wipe AWOL/cleared/graduated/escape flags, knockout,
  `spawnCaptureTransport` back to NWAF → `fn_trainingPhase` restarts (the
  conscription loop is fully cyclical); *execute* — deliberate point-blank volley,
  with `CO_awolExecution` lifting the non-lethal damage cap in
  `fn_installNonLethalDamage` so the execution can actually kill.
- **Respawn slate wipe:** server `EntityRespawned` mission EH (in `fn_initServer`)
  resets every per-player state var (AWOL, cleared, detain phase, boot camp, wanted,
  heat, escalation, captureInProgress, captive) on the new body — death is a clean
  restart.

## Round R5 — Situational HUD + police uniform fix

- **`fn_policeLoadout`** (new): shared police gear applicator; resolves the uniform
  via `isClass` over `U_B_GEN_Soldier_F` → `U_B_GendarmerieSuit_01_F` → guerilla
  fallback, verifies the result (never underwear), caches in
  `CO_policeUniformClass`, installs crime-witness EHs. Used by all three police
  spawners.
- **`fn_threatInfoLoop`** (new, launched in `fn_initServer`): 4 s server loop; one
  `allGroups` classification pass per tick, then per player broadcasts
  `CO_threatNear = [nearestPoliceDist, nearestOccupationDist]` (CRN_ENF covers TCK +
  checkpoints + border).
- **`fn_heatHud`** rewritten as a phase-aware display driven by
  `CO_detainPhase` / `CO_isAWOL` / `CO_isCleared` / `CO_bootCampActive`:
  free (POLICE + TCK/BORDER tiles, escalation split by `CO_escalationSource`
  prefix), detained/transport, training (uses new `CO_bootCampStage` broadcasts
  from `fn_bootCampQuest`), frontline (minimal), AWOL (banner + both tiles).
- Removed the dead `CO_fnc_policeInspection` global block from `fn_policeBrain`
  (superseded by `fn_policeOrderInspection` in the R3/R4 commit).

## Round R2 — Make it legible (repair plan Phase R2)

- **Persistent threat HUD.** `ui/threat_hud.hpp` (RscTitles `CO_ThreatHUD`, idd 9400)
  + new `RscStructuredText` base class in `config.cpp`. `fn_heatHud` rewritten: renders
  stamina + WANTED stars (wanted only) + a colored posture chip (CALM / COOLING /
  WATCHED / ID CHECK / PURSUIT / HUNTED / WEAPONS FREE / SHOOT TO KILL) on a dedicated
  always-visible cutRsc layer. No more `hintSilent` (which faded out and fought the
  hint channel). `fn_enduranceBar` keeps writing `CO_enduranceHudText`; only the HUD
  renders it.
- **Server-authoritative escalation lifecycle (audit R2-17).** Expiry of escalation
  states and heat decay moved into the `fn_stateWatchdog` maintenance loop (30 s tick,
  half of `CO_heat_decayPerMinute` per tick). `fn_getEscalationState` is now a pure
  read (treats expired as CLEAR without writing) — previously decay only ran inside
  the local player's HUD loop, so nothing expired on a dedicated server.
- **Transition toasts.** `fn_chaseStinger` (invoked by `fn_setEscalationState` only on
  real transitions) shows a 4-second auto-fading toast on `CO_ToastLayer`
  (serial-guarded so rapid transitions don't clip newer toasts) plus the throttled
  music stinger.
- **Siren sound sanity (R2-c).** `fn_policeResponseFX` resolves the siren path once at
  runtime via `fileExists` over a candidate list (cached in `CO_sirenSoundPath`,
  logged); if none resolves it falls back to periodic horn blasts using the vehicle's
  config-defined horn weapon. `fn_civilianPanic` only plays audio when the path
  resolved.

## Round R1 — Make the city react (repair plan Phase R1)

- **Crime & witness system.** `fn_installCrimeWitness` (applied by
  `fn_initHostileUnit` + both police spawners) adds Hit/Killed/FiredNear EHs feeding
  `fn_reportCrime`: witnessed kills/wounds of TCK/police raise wanted (+60/+40),
  set WEAPONS/PURSUIT escalation, bump a per-town alert level (`CO_townAlertLevels`,
  10 min expiry), and arm every CRN_ENF/POLICE group within 200 m — bus groups get a
  `CO_busEmergency*` order. Unwitnessed kills stay free (stealth is viable).
- **Bus under-fire doctrine.** `fn_busAgroLoop` main loop consumes the bus emergency:
  full escort dismount (no held-back guard), hunters seeded with the attacker at
  claim priority 90, weapons-free (`fireAtTarget` stun volleys through the
  non-lethal filter) when blood was drawn.
- **Bus captive-cap deadlock fixed.** Cap reached → forced detention delivery (or
  forced reboard when dismounted) instead of `continue`-ing past the state machine.
- **State watchdog.** `fn_stateWatchdog` (30 s tick, launched first in
  `fn_initServer`) recovers stuck `CO_captureInProgress`, stale wrangle locks, dead
  police chase flags, ghost sirens, parked patrol cars, and frozen bus states; every
  recovery logs `[CO][WATCHDOG]` — a healthy RPT has none.
- **Police lifecycle.** Shared `fn_policeBrain` (suspicion sweep, hails, random ID
  checks via `CO_police_carStopChance`, alert-net response, AWOL handling, town-alert
  scaling) drives BOTH car patrols (`fn_policePatrols`) and urban foot police
  (`fn_spawnUrbanFootPatrols` — previously brainless). `fn_policeResumePatrol` is the
  mandatory epilogue for `fn_policeFootChase` (now car-optional) and
  `fn_policeVehiclePursuit` (which also replaces dead drivers mid-pursuit).
- **Serialized wrangle.** `fn_runWrangle` mutexes the minigame (`CO_wrangleActive`);
  police/checkpoint/bus grabs all route through it — concurrent grabs no longer
  auto-capture via a failed createDialog.
- **Arbiter cap fixed.** `fn_claimUnit` chase cap actually rejects now (the old
  `exitWith`-in-`then{}` fall-through granted claims anyway); player-priority (>= 70)
  chases are exempt from the cap. Bus hunters share one token per dismount event.
- **Checkpoint chases.** `fn_checkpointAlert` posture set once (AWARE, not per-tick
  COMBAT/RED spam), 250 m leash (`CO_checkpoint_chaseLeash`) with alert-net handoff,
  return-to-post epilogue, and vehicle fire aimed at the driver instead of the hull.
- **Target weighting.** `fn_tckGlobalAggression` and bus hunters score targets
  (players −40, heat −0.5/pt, armed −25) instead of picking the nearest civ; TCK
  retaliation now runs before the mounted-unit skip (mounted units dismount to fight).
- New functions registered in `CfgFunctions`: `reportCrime`, `installCrimeWitness`,
  `runWrangle`, `stateWatchdog`, `policeBrain`, `policeResumePatrol`. New tunables in
  `CO_adminDefaults.sqf`: `CO_crime_killWanted/woundWanted/gunfireWanted`,
  `CO_checkpoint_chaseLeash`, `CO_police_chaseDeadline`.

## Round 9 � Population caps + dismount fixes

- **RUS_ADV population cap.** `CO_rus_maxActive` (default 80, broadcast via `fn_initServer` + `CO_adminDefaults.sqf`). `fn_spawnRussianWave` and `fn_spawnRussianReplacement` both short-circuit when the live RUS_ADV count is at or above the cap. This bounds the AI simulation cost in the north sector (Krasnostav) where the wave + 1:1 replacement spawners previously produced unbounded growth.
- **Russian hostility tick throttle.** `fn_russianHostilityTick` now sleeps 8 s (was 5 s) and limits `reveal`/`doFire`/`fireAtTarget` issuance to the 5 nearest foot units and 2 nearest vehicles per player, sorted by distance. Caps network/command-queue spam.
- **Police foot chase.** New `fn_policeFootChase` (registered in `CfgFunctions`). Called from `fn_policePatrols` on detain trigger; replaces the previous in-vehicle `doMove` + nearest-unit-2.5m wait pattern that left passengers stuck in cargo.
- **Bus idle dismount.** `fn_busAgroLoop` switched to speed-based stuck detection (`speed _veh < 1.8 km/h`), 20 s threshold, full-escort dismount (no 2-escort cap). Idle-dismount applies in both `traveling` and `approaching` states.
- **Boot camp range.** Quest targets relocated downrange east of the existing visible static target line at the training field (`CO_trainingFieldPos vectorAdd [55..60, -24..-16]`), facing west toward the firing line with `mil_dot` per-target markers. Rack now also stocks 1000 backpacks + 1000 harness vests via `addBackpackCargoGlobal` / `addItemCargoGlobal`.

