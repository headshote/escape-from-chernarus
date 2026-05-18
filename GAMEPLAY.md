# Chernarus Occupation — Gameplay Reference

Arma 3 multiplayer mission (1–32 players). Players start as ordinary Chernarus civilians
under military occupation by a pro-government enforcer faction (CRN_ENF). Russians (RUS_ADV)
are advancing from the east. The player's arc is: survive the occupation → get conscripted →
escape → join the resistance.

The current runtime build is designed so that checkpoints, buses, civilians, traffic, police,
border patrols, the airfield camp, and the eastern front are initialized as separate subsystems.
One failing subsystem should no longer leave the whole map empty.

---

## Factions

| Side | Tag | Role |
|------|-----|------|
| BLUFOR (`west`) | CRN_ENF | Enforcers — occupation police, checkpoint guards, bus escorts |
| BLUFOR (`west`) | CRN_FRONT | Chernarus military deployed at the eastern front |
| OPFOR (`east`) | RUS_ADV | Russian advance — waves attacking from east |
| INDEP (`guer`) | Resistance | Unlocked by players who successfully escape |
| Civilian | — | NPC civilians + players before capture |

Both CRN_ENF and CRN_FRONT are BLUFOR (`west`). They are distinguished by the group
variable `CO_faction` (`"CRN_ENF"` or `"CRN_FRONT"`).

---

## Wanted Level

Every player has `CO_wantedLevel` (0–100, persistent per session).

| Action | Change |
|--------|--------|
| Captured at checkpoint | +30 |
| Fleeing police pursuit | +20 |
| Police recognition check (high suspicion) | progressive |
| Successful escape from detention | –20 |
| Disguise equipped | recognition threshold raised |

Police recognition (`fn_policeRecognise`) computes a score from wanted level,
disguise level (`CO_disguiseLevel` 0–3), proximity, and time-of-day. Triggers pursuit above 50.

---

## Checkpoints

Checkpoints are placed procedurally along roads derived from the `CO_roadGraph` (see
ARCHITECTURE.md). Large and medium settlements get checkpoints on connecting roads;
small settlements are optional (tunable). Each post has `CO_checkpoint_hostilesPerPost`
guards (default 4).

Player approach triggers `fn_checkpointAlert`:
- Female NPC civilians are never targeted.
- Checkpoint guards now actively scan nearby civilian men and players instead of waiting for
  direct engine hostility.
- Crowd resistance (`fn_crowdResistance`) can block or slow enforcers.
- If a guard closes to 2.5 m the **wrangle minigame** fires (`fn_wrangleMinigame`).
- Win wrangle → 3-second head-start, wanted level +30.
- Lose wrangle → `setCaptive true`, transport to detention.

---

## Hostile Buses

Buses run fixed routes derived from the road graph (nearby-settlement pairs). Each bus
carries `CO_bus_hostilesPerBus` guards (default 5). Large towns get a minimum of
`CO_bus_townGuaranteed` buses (default 3).

Bus agro loop (`fn_busAgroLoop`) detects nearby players and male civilian NPCs, dismounts the
escort group, and triggers `fn_checkpointAlert` using the bus guard group.

If a TCK truck has been effectively stationary (speed below ~1.8 km/h) for 20 s in
`traveling` or `approaching` state, the full escort dismounts and chases on foot — no
escort cap. This prevents a stuck truck from sitting uselessly while civs/players are
nearby. NPC captures are loaded into the truck for delivery; player captures are handed
off to `spawnCaptureTransport`.

Successful bus captures now knock the target out, load them into the vehicle, keep cruising for
a short window, and then route the bus to the nearest detention center once it has enough
detainees or the post-capture cruise timer expires.

---

## Conscription Pipeline

Captured players/civilians go through three phases, each with a HUD notification.

```
Detention (5 min, fn_prisonSequence)
    ↓ [if not escaped]
Training Camp / Airfield (10 min, fn_trainingPhase → fn_trainingDrills)
    ↓ [if not deserted]
Eastern Front (deployed as CRN_FRONT, fn_deployToFront)
```

- **Detention** (`fn_showDetentionHUD`): player is captive at central detention compound.
  Lockpick minigame available on cell doors.
- **Training** (`fn_showTrainingHUD`): player is moved to NW airfield. Timed drills.
- **Front** (`fn_showFrontDeployHUD`): player assigned to CRN_FRONT group defending
  against Russian waves.

---

## Escape Mechanics

### Lockpick Minigame (`fn_minigame_lockpick`)
- Detention cell doors only.
- 4-key sequence displayed for 1.5 s, then hidden.
- 2 s per key to press correctly (WASD/F/G/R).
- Success → `fn_prisonEscape` (remove captive, wanted –20).
- Failure → `fn_alertNearbyGuards` (60 m radius).

### Border Escape
- All 4 map edges patrolled: west/north/east land edges (ATV patrols), south coast (armed boat).
- Post spacing: `CO_border_postSpacing` meters (default 600).
- Player within 150 m of an edge triggers alert to nearby CRN_ENF groups.
- Player within 50 m of actual edge triggers `fn_checkEscapeUnlock`.
- Successful cross → `fn_showEscapeUnlockScreen`, sets resistance respawn eligibility.
- Players spawning at the unlocked resistance location or the initial Chernogorsk civilian start
  now receive a personal bicycle when the class exists, with a quadbike fallback on servers that
  do not expose a bicycle vehicle class.

---

## Non-Lethal Melee

Players now have a basic punch-based unarmed melee system while no weapon is equipped.

- Range: about 2.4 m.
- Effect: repeated punches within a short window knock the target unconscious for 60 seconds.
- Input: left mouse click while unarmed and close enough to a human target.
- Use: gives both players and the TCK capture loop a non-lethal takedown path without adding a
  separate melee weapon dependency.

This is a lightweight scripted system rather than a full melee-animation framework.

---

## Endurance Bar

Client-side HUD (`fn_enduranceBar`). Tracks sprint/stamina as `CO_endurance` (0–100).
Depletes on movement, recovers at rest. Below 20: `setCustomAimCoef 4` (penalty).
Displayed via `hintSilent` text bar, updates every 6 frames.

---

## Police System

Town police patrols in Chernogorsk, Elektrozavodsk, Berezino, Zelenogorsk, Stary Sobor.
- 2 police Offroads per town, pistol-armed, gendarmerie uniform (helmet + harness vest +
  P07). Police uniform is force-applied so they no longer end up in underwear if a uniform
  swap silently fails.
- Patrol cars cruise on `LIMITED` speed in `SAFE` behaviour. The driver and the partner both
  have `AUTOTARGET`/`TARGET` disabled so the driver never accelerates away from the partner.
- Every 5 s: check all players for `CO_wantedLevel ≥ 50` + positive recognition result, plus a
  random `CO_police_carStopChance` roll on nearby civilians.
- On a hit, `fn_policeFootChase` stops the car (`doStop` + `forceSpeed 0`), force-dismounts
  both officers (`unassignVehicle` → `action ["GetOut"]` → `moveOut` fallback), and runs an
  on-foot pursuit with non-lethal melee (`fn_applyMeleeHit`). On knockout: NPC civilians are
  routed via `transportToDetention`; players via `spawnCaptureTransport` (the standard
  dedicated-truck capture flow).
- After capture or chase timeout, both officers reboard the patrol car and resume cruising.

Traffic system also has random car stop checks at `CO_police_carStopChance` frequency.

Disguise items: worker uniform (level 1), farmer/glasses (level 2). Higher level raises
the recognition threshold needed for pursuit.

---

## Russian Advance

Abstract east-to-west front, modelled by `CO_rus_advanceFront` (X coordinate).

Each wave (`fn_spawnRussianWave`):
- `CO_rus_unitsPerWave` infantry + every `CO_rus_armorFrequency` waves one APC.
- Front advances 120 m per wave (abstract).
- Town objectives checked west-to-east: Berezino → Elektrozavodsk → Chernogorsk → Balota.
- When a town falls: `fn_enforcerRetreatFromTown` (ENF groups within 1500 m retreat west),
  `fn_updateFrontLine` redraws the `co_frontline` map marker.
- If `CO_front_unitsRemaining ≤ 10`: `fn_frontCollapse`.
- Deserters (soldiers moving >500 m from front): detected by `fn_desertionMonitor`.

**Population cap.** `CO_rus_maxActive` (default 80) limits the live RUS_ADV unit count.
Both `fn_spawnRussianWave` and `fn_spawnRussianReplacement` skip spawning when at or above
the cap. This prevents unbounded growth that was producing severe FPS drops near Krasnostav
(replacement spawns +1 per kill, wave spawns +30 every 100 s, combined with no cleanup).

**Hostility tick throttle.** `fn_russianHostilityTick` (the per-player loop that forces
RUS_ADV to engage cleared conscripts despite the engine `civilian setFriend [west,1]`
relation) now sleeps 8 s (was 5 s) and only issues `reveal`/`doFire`/`fireAtTarget` against
the 5 nearest foot units and 2 nearest vehicles. This bounds the command spam regardless of
local AI density.

---

## Civilian AI

The civilian system now targets a much denser population spread across `CO_settlements`, with
heavy weighting toward large towns and a wider spawn radius inside cities so central areas do
not stay empty while only the western edge of town feels populated. Each reacts to nearby military:
- 0–0.5 random: flee.
- 0.5–0.85: comply (stand still).
- >0.85: resist (engage).

Crowd resistance (`fn_crowdResistance`): if ≥ 3 civilians are within 15 m of a capture
attempt, roll a chance to block/slow the enforcer group.

---

## Weapon Caches

12 hidden boxes across Chernarus (apartments, rural buildings). Three types:
- **Pistol**: P07 + magazines.
- **Rifle**: AKM + magazines.
- **Melee**: Toolkit (crowbar proxy) + medkits.

Snapped to nearby building floor if possible. Marked with `CO_isWeaponCache = true`.

---

## Admin Panel (`fn_adminPanel`)

Dialog `CO_AdminPanel` (idd 9300). Accessible only to UIDs in `CO_adminUIDs`.
Sliders broadcast globals via `publicVariable` on change. Key tunables:

In game, an approved admin now gets an `Open Admin Panel` action on their player.
If the action does not appear, the player's Steam64 UID is not currently listed in
`missions/ChernOccupation.Chernarus/CO_adminDefaults.sqf` under `CO_adminUIDs`.

| Control | Global | Default |
|---------|--------|---------|
| Guards per checkpoint | `CO_checkpoint_hostilesPerPost` | 4 |
| Include small roads | `CO_checkpoint_includeSmall` | false |
| Total buses | `CO_bus_totalCruising` | 30 |
| Hostiles per bus | `CO_bus_hostilesPerBus` | 5 |
| Border spacing | `CO_border_postSpacing` | 600 m |
| Police stop chance | `CO_police_carStopChance` | 0.05 |
| Russian wave cooldown | `CO_rus_waveCooldown` | 180 s |

All defaults live in `missions/ChernOccupation.Chernarus/CO_adminDefaults.sqf`.

---

## Current Runtime Notes

- Large towns now have guaranteed civilian presence, guaranteed hostile bus allocation, police,
  and denser traffic so places like Chernogorsk should no longer load as empty when the world
  population systems initialize correctly.
- Border patrols, airfield defenses, and eastern-front fortifications are started independently
  from the town-life systems so a failure in one subsystem does not stop civilian life, buses,
  police, or checkpoints from spawning.
- The opening client briefing text now stays on screen for about one minute so the initial
  objective is readable on connection.
- Civilian-start players at the Chernogorsk train-station spawn now request a support bike from
  the same helper that already serves unlocked resistance spawns.
- `local_start_server.bat` now resolves copied dependency mods from the dedicated-server root
  before falling back to a full client install path, which makes a server-only laptop setup easier.

---

## Known Gaps

- Resistance is still implemented as an unlocked respawn path rather than a full separate
  lobby-selectable faction with its own slot list.
- The dedicated server still reports a long-standing `a3_characters_f` deleted-content warning
  during startup. It was already present in earlier spawn-capable runs, but it still needs a
  dedicated mission dependency audit.
- This document reflects the current scripted systems, but the detention, training, front-line,
  and town-population loops still need live in-game playtesting after this runtime pass.

## Recent Runtime Pass — Notes

- **Resilient init.** `fn_initServer` now wraps each step in a per-step try/catch and records
  status into a `CO_initStepStatus` hashmap. A failure in one step (e.g. west-border
  enforcement) no longer silently aborts the rest of init — look at `diag_log` `[CO]` lines.
- **World density staggered.** Border forts, eastern front, west-border camps, and civilian
  spawn loops yield (`sleep` 0.15–0.25s) every few iterations to avoid choking the server.
- **Hostile bus aggression.** Buses now drive `AWARE`/yellow, aggro radius defaults to 260m
  (was 140m), polling is 1s, vehicle crews are valid targets, and trucks pursue civilian
  vehicles before stopping to dismount escorts. Every `CO_bus_patrolStopInterval` (default
  75s) a bus near a settlement pulls over, escort dismounts and patrols 30s, then reboards.
- **Melee.** Swing/flinch use `playActionNow` gestures broadcast globally, plus a body-impact
  sound. The previous `switchMove` was overridden by movement state and never visible.
- **Russian advance.** `CO_rus_advanceFront` is pre-broadcast before any wave; first wave
  triggers ~12s after server init (was 180s). Russian waves now spawn on north/central/south
  lanes near the front line, including a northern Krasnostav combat axis.
- **Border alert NPC path.** Civilians intercepted at the border no longer attempt a
  `wrangleMinigame` (which would block forever waiting for a key); they take melee hits until
  knocked out, then are transported to detention. Players still get the full minigame.
- **Disguise pickup.** Weapon caches now contain civilian uniforms (`U_C_Workman_01`,
  `U_C_Poor_1`, `U_C_Farmer`, `U_C_Driver_1`) and expose `Take Disguise (Worker/Farmer)`
  actions which fire the `co_main_disguise` CBA event and bump `CO_disguiseLevel`.
- **Lockpick.** Real `displayAddEventHandler "KeyDown"` handler in
  `fn_minigame_lockpick`, plus a self-action `Attempt to pick the lock` shown to the
  detained player while `CO_detainPhase == "detention"`.
- **Day/night cycle.** Server sets `setTimeMultiplier 6` so a Chernarus day is ~4 real hours.
  Clients start with `ItemMap`, `ItemCompass`, `ItemWatch` only — `ItemGPS`, `ItemRadio`,
  `B_UavTerminal` are stripped on init (per spec point 16).

## Round 9 Changes

- **Police polish.** Patrol cars now cruise on `LIMITED`/`SAFE`. On detain-trigger, the new
  `fn_policeFootChase` stops the car and force-dismounts both officers (driver +
  passenger) for an on-foot melee chase with the standard non-lethal capture handoff. The
  driver no longer races past targets while the partner sits in the cargo seat.
- **TCK truck idle fallback.** `fn_busAgroLoop` now uses speed-based idle detection
  (`speed _veh < 1.8 km/h`) instead of position-delta (which reset on AI brake/restart
  drift). Threshold raised to **20 s**. The 2-escort cap is removed — every mounted escort
  dismounts and hunts on foot. Player captures route via `spawnCaptureTransport`, NPC
  captures continue via the normal `transportToDetention` flow.
- **Training crate + visible targets.** Boot camp rifle range repositioned: rack at the
  firing-line sandbags, three quest targets at +55/60 m **east** of the field center,
  directly downrange from the existing visible static target line, each facing west toward
  the firing line. Per-target `mil_dot` markers added to the map labelled `TARGET 1/2/3`.
  Rack now also stocks 1000 `B_AssaultPack_rgr` backpacks and 1000 `V_HarnessO_brn` vests
  alongside the 900 AKMs and 100 000 magazines.
- **Krasnostav FPS fix.** New global cap `CO_rus_maxActive` (default 80) on live RUS_ADV
  units. Both wave spawner and replacement spawner short-circuit when the cap is reached.
  `fn_russianHostilityTick` throttled from 5 s → 8 s and limited to 5 nearest infantry +
  2 nearest vehicles per tick.
