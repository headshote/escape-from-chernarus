# Chernarus Occupation — Gameplay Overhaul Plan

Goal: make the occupation feel **realistic** (forces behave like a coordinated security
apparatus), **smooth** (AI acts deliberately, no stutter/teleports/dead states), and
**thrilling** (escape is earned through planning and nerve, not by jogging in a straight
line for 75 seconds).

This plan is grounded in a code audit of the current systems. Part 1 is the diagnosis —
five root causes that explain all four reported symptoms. Part 2 is the idea catalog per
system. Part 3 is the phased implementation plan with acceptance criteria.

---

## Part 1 — Root-Cause Diagnosis

The four symptoms (distracted police, useless TCK escorts, bypassable checkpoints, empty
border forests) are mostly *surface expressions* of five structural problems:

### RC1. Command stomping — no arbitration between AI controllers
At least five independent server loops issue `doMove` / `setBehaviour` / `setCombatMode`
to **overlapping unit sets** on 2–5 s ticks:

| Loop | Tick | Scope |
|---|---|---|
| `fn_tckGlobalAggression` | 3 s | *every* CRN_ENF/POLICE unit on the map |
| `fn_guardAggroLoop` | 2.5 s | checkpoint/fort/detention groups |
| `fn_busAgroLoop` + per-escort hunter threads | 1.5–3 s | TCK escorts |
| `fn_policePatrols` behaviour loop | 5 s | police groups |
| west-border `_registerResponseGroup` loops | 2 s | border camps/patrols |

A police officer mid-chase can be grabbed by `fn_tckGlobalAggression` and sent at a
*different* civilian 40 m away; a checkpoint guard chasing a player gets his `doMove`
overwritten next tick. **This is the literal mechanism behind "distracted" AI.** Each
re-issued `doMove` also makes the AI pause ~0.5 s to re-path, which reads as stutter.

### RC2. The catch mechanic cannot catch a moving target
Capture requires **3 melee hits** at < 2.8 m, with a 0.9 s per-attacker cooldown, inside
an 8 s window (`fn_applyMeleeHit`) — against a sprinting player, delivered by AI that
re-paths every 1–1.5 s. AI foot speed ≈ player sprint speed, so the 3-hit chain
essentially never completes on anyone who holds W. On top of that, every chase has a
hard timeout that guarantees escape by simply running:

- police foot chase: **75 s** (`fn_policeFootChase:77`)
- tck global aggression chase: **25 s** (`fn_tckGlobalAggression:172`)
- bus escort dismount: **60 s** then reboard regardless (`BUS_DISMOUNT_DURATION`)
- bus escort hunt scan radius once dismounted: **28 m** (`fn_busAgroLoop:174`)

### RC3. The security apparatus has no memory and no network
Every detection is local and instantaneous; every escape is total. There is no
last-known-position, no search behavior after losing sight, no backup dispatch, no
radio-ahead to the next checkpoint, no persistent manhunt tied to wanted level.
Outrunning one 2-man team = clean slate. Real occupation forces are terrifying because
*information travels* — that entire layer is missing.

### RC4. No escalation ladder and no legal path
Checkpoints, buses, and patrols attack on proximity (`fn_guardAggroLoop` →
`fn_checkpointAlert` fires on any male within 90 m). There is **no way to comply**: no
ID check, no "stop, papers" interaction, no passing a checkpoint legally. So the game
collapses into binary avoid-or-fight, and since avoidance is trivial (RC2/RC5), tension
never builds. Recognition (`fn_policeRecognise`) is a memoryless random roll every 5 s —
the player gets no telegraph, no rising-suspicion feedback, no counterplay.

### RC5. Geometry doesn't create threat
- Checkpoints stamp at road-graph **midpoints** — usually open fields where a 20 m
  off-road detour defeats them, with zero consequence for bypassing.
- Border ATV patrols cruise the literal **map-edge line** (`fn_borderPatrol`); the alert
  loop only arms within 200 m of the edge.
- West-border forest camps detect from the **static camp center**
  (`fn_buildWestBorderEnforcement:55` scans `_center nearEntities`, not the live patrol
  position), so the roving patrols walking between camps detect *nothing* along their
  route, and the ~600 m gaps between camps are dead zones.
- Stuck-recovery **teleports** buses to a random nearby road (`fn_busAgroLoop:696`) —
  immersion-breaking and visible to players.

---

## Part 2 — Idea Catalog

### 2.0 Foundation (fixes all four symptoms at once)

**F1. Engagement arbiter (unit ownership tokens).**
One tiny API: `[_unit, "police_chase", _priority] call co_main_fnc_claimUnit` /
`releaseUnit`. Every controller loop must hold the claim before issuing orders and must
skip claimed units. Priorities: player-capture chase > retaliation > proactive stop >
ambient patrol. Kills RC1 with ~30 lines and makes every existing system instantly
smarter without touching its logic.

**F2. Chase movement kit** (shared helper used by police, TCK, border, checkpoint):
- `doMove` to a **predicted intercept point** (target pos + velocity × time-to-reach),
  not current position; re-issue only when the target has moved > 10 m from the last
  ordered destination — eliminates re-path stutter.
- `_chaser setAnimSpeedCoef 1.12` while chasing (reset on release) so a chaser is
  slightly faster than a sprinting player — the chase becomes about *breaking
  line-of-sight and endurance*, not raw speed.
- **Cordon assignment**: when ≥ 2 chasers, assign surround offsets (±60° ahead of the
  target's velocity vector) instead of everyone conga-lining to the same point.
- Tie into the existing endurance system: sprinting drains `CO_endurance`; AI gets a
  stamina pool too — a long chase becomes a **stamina duel** with a visible outcome.

**F3. Proximity tackle (replaces 3-punch capture for chases).**
If a chaser stays within 2.2 m for a cumulative 1.5 s, trigger a **grab**: for players,
launch the existing wrangle minigame (with difficulty scaled by remaining endurance —
exhausted = harder to win); for NPCs, instant knockdown. Keep `fn_applyMeleeHit` for
player-initiated melee. This single change makes every chase in the game actually
capable of ending in a capture.

**F4. Alert network / blackboard.**
A server-side `CO_alertNet` hashmap: `[suspectRef → [lastKnownPos, timestamp, source,
heatLevel]]`. Publishers: any TCK/police/checkpoint/border detection. Subscribers:
groups within "radio range" (e.g. 800 m town / 1500 m border) poll it and can be tasked
to converge, cordon, or search. Escapes now require breaking contact *and* clearing the
search, not outlasting a timer.

**F5. Search-after-lost behavior.**
When a chase loses line-of-sight for 10 s, the chase converts to a 2–4 min **search
state** around the LKP: units sweep buildings/bushes in an expanding ring (`doMove` to
`nearestTerrainObjects` hide-spot candidates), the patrol car circles the block. Player
gets a "You lost them — stay hidden" hint; being re-spotted during search resumes the
chase instantly at full alert. This is where the adrenaline lives — crouching in a bush
while a flashlight sweeps past.

**F6. Escalation ladder (global doctrine).**
`UNAWARE → SUSPICIOUS (hail/ID check) → PURSUIT (non-lethal, tackle) → WEAPONS (warning
shots after 20 s of flight or if target armed) → LETHAL (only at wanted ≥ 75 or after
taking fire; still filtered through `fn_installNonLethalDamage` into a downed state so
the conscription pipeline keeps working)`. Every system maps its behavior onto this
ladder so players can *read* the threat level and make decisions.

### 2.1 Police (symptom 1)

- **P1. Suspicion accumulation instead of dice rolls.** Replace the per-tick
  `fn_policeRecognise` roll with a per-officer suspicion meter that rises while the
  player is visible (rate scaled by wanted level, disguise, distance, running/weapon
  drawn, night) and decays out of sight. At 60%: officer hails ("Stop! Documents!") and
  walks toward the player — the player can comply (stand still → ID check → maybe pass,
  maybe detain if wanted ≥ 50), or run (instant PURSUIT + wanted +20). Telegraphed,
  counterplayable, tense.
- **P2. Vehicle pursuit.** If the target flees in/into a vehicle, officers reboard and
  pursue by car (driver claimed by the chase controller, `setSpeedMode FULL`, AWARE);
  the partner calls it in (F4) → nearest other patrol car converges; after 45 s of
  pursuit, a **spike strip / roadblock** is dispatched to a road-graph node *ahead* of
  the flight vector. Currently the car just parks — a bicycle beats the entire police
  force.
- **P3. Backup + escalation.** Chase running > 30 s → second unit dispatched from the
  town pool. Wanted ≥ 75 → lethal posture, and the town gains a temporary "lockdown"
  modifier (foot patrols actively sweep, suspicion rises faster) for 10 min.
- **P4. Sirens & light.** Loop a siren `playSound3D` + blue `#lightpoint` on the car
  while responding, off when patrolling. Cheap, massive presence gain. (If CUP police
  skins are available at mission level, use them; fall back to current Offroad.)
- **P5. Remove police from `fn_tckGlobalAggression` scope** (they have their own
  controller — with F1 this happens automatically via claims).
- **P6. Chase timeout → search conversion** (F5) instead of silent reboard-and-forget;
  wanted decays only while *not* in any group's suspicion memory.

### 2.2 TCK trucks (symptom 2)

- **T1. Fix the dismount dead-state.** Escort hunter scan radius 28 m → 80 m, seeded
  with the LKP of the target that triggered the stop (currently hunters spawn with
  `objNull` target and wander 30 m from the bus). Hunters use the F2 chase kit +
  F3 tackle.
- **T2. Adaptive dismount duration.** Stay dismounted while any candidate target is
  within 120 m or the alert net has a fresh LKP nearby; reboard after 20 s of genuine
  quiet — replaces the fixed 60 s window that expires mid-chase.
- **T3. Fireteam split.** On dismount, keep driver + 1 guard at the truck (it stays a
  stealable objective, but a defended one); the rest hunt with cordon offsets.
- **T4. Intercept driving.** In `approaching` state, drive to the predicted intercept
  point (F2 math applied to the vehicle) and attempt to **cut off** foot targets rather
  than chasing their tail; against fleeing vehicles, request a roadblock from the
  nearest other TCK truck via the alert net (dispatch it to a road node ahead).
- **T5. Kill the teleport.** Replace the stuck-recovery `setPos` with: re-plan route to
  the next reachable road node; after two consecutive failures, mark the route segment
  bad in `CO_busRoutes` (so all buses stop using it) and reverse out
  (`forceSpeed -1` + back waypoint). Teleporting vehicles is the single most
  prototype-feeling visual in the mod.
- **T6. Snatch-squad flavor.** When a bus makes a capture, brief megaphone bark +
  nearby NPC civs flee (already have `CO_civState = fleeing`) — makes town raids feel
  like events other civilians react to.

### 2.3 Checkpoints (symptom 3)

- **C1. Choke-point scoring.** After building the road graph, score each candidate:
  sample 8 points at ±40–80 m perpendicular to the road; count tree density
  (`nearestTerrainObjects`), surface water, and slope. High off-road resistance = high
  score. Stamp checkpoints only at the top-scoring positions (bridges and forest
  cuttings float to the top naturally). A checkpoint you *can't* drive around without
  entering a forest or river is a real obstacle.
- **C2. Legal passage (the big fun unlock).** Approaching slowly (< 20 km/h) triggers a
  stop interaction: halt at the barrier, engine off, 10–15 s inspection. Outcome by
  wanted level + disguise + (later) contraband in inventory: pass / fine / detain.
  Compliant players pass. Now checkpoints create a *decision* — comply and risk the
  check, or bypass and accept the consequences — instead of a mandatory detour.
- **C3. Bypass detection with consequences.** 350 m trigger radius: a vehicle that
  approaches, then U-turns or diverts off-road while under guard line-of-sight
  (`knowsAbout` / LOS check) → wanted +15, alert-net publish, and the checkpoint's
  **pursuit vehicle** (add 1 Offroad + 2 guards per checkpoint) launches. Radio-ahead:
  the next checkpoint along the flight vector goes to WEAPONS posture and deploys a
  spike strip.
- **C4. Barrier running.** Smashing through the barrier = wanted +30, immediate
  pursuit, warning shots, spike strip at the next checkpoint. Add a physical
  `Land_SpikeStrip_01_F`-style tire-kill (scripted `setHitPointDamage` on wheels when
  crossing a marked line) since vanilla has no functional spike object.
- **C5. Night dressing.** Working floodlight cone sweep + flare launch on alert.
  Checkpoint at night should be visible from 1 km — both a warning and a lure.

### 2.4 Border & forests (symptom 4)

- **B1. Fix detection anchors.** Response loops scan from the **live patrol leader
  position**, not the camp center (one-line fix in `_registerResponseGroup`), and
  include players regardless of side (currently `side _x == civilian` silently skips
  resistance-side players).
- **B2. Three-layer border zone** (replaces the single edge-line):
  1. **Outer belt (800–1500 m from edge):** roving 2–3 man foot patrols on randomized
     routes *through the forest* between camp anchors, using the F2/F3 kit. These are
     the "forest threat" the player should meet first.
  2. **Sensor line (~400 m):** scripted tripflares/wire every 150–250 m with small
     random gaps. Crossing one at night fires an actual flare + alert-net publish →
     nearest camp dispatches a hunter team to the crossing point. Gaps are findable by
     recon (binoculars, daylight scouting) — rewarding preparation.
  3. **Inner line:** existing posts/towers, but with **semi-random per-session
     placement jitter** (±200 m) so the safe path can't be memorized from a previous
     run — border crossing requires scouting *this* session.
- **B3. Tracker teams ("dogs").** While a player is border-flagged (crossed the sensor
  line or wanted ≥ 50 near the border), record their position every 5 s into a
  breadcrumb trail. A dispatched tracker team follows the *trail* (not the player
  directly) at `setAnimSpeedCoef 1.25`, with audible barking `playSound3D`. Counterplay:
  wading water, roads, or stolen vehicles breaks the trail. This is the "hunted through
  the woods" fantasy and it's ~100 lines.
- **B4. Night manhunt escalation.** Border alert at night with wanted ≥ 75 → helicopter
  with `searchlight` orbits the LKP for 5 min. Rare, loud, terrifying, and cheap to
  script (one heli, `doMove` orbit ring, gunner spotlight).
- **B5. Ambient dread.** Distant flares, occasional MG bursts from towers at night,
  searchlight sweeps on a timer even with no alert. The border should *feel* patrolled
  from 2 km away, before a single AI is actually in range.

### 2.5 Cross-cutting feel & feedback

- **X1. Heat HUD.** Small wanted/heat indicator (stars or bar) + state cues: "eyed by
  police" (suspicion rising), "PURSUIT", "they lost you — hide", "search called off".
  Players can't feel tension they can't see.
- **X2. Chase stingers.** `playMusic` layer on pursuit start / search / all-clear.
  Single biggest adrenaline multiplier per line of code.
- **X3. Difficulty presets.** Three admin-panel profiles (Quiet Occupation / Standard /
  Martial Law) mapping onto the existing `CO_*` globals + the new ones (suspicion rate,
  search duration, tracker speed, checkpoint density).
- **X4. Performance budget.** All new loops on CBA PFH with per-tick unit budgets; cap
  simultaneous chases (e.g. 6 map-wide, priority to players); the F1 arbiter itself
  reduces redundant command spam. KPI counters in `diag_log` (chases started / caught /
  lost / timeout per system) to tune from real data.

---

## Part 3 — Phased Implementation Plan

Each phase is shippable and playtestable on its own. Order matters: Phase 0 is the
multiplier — everything after it reuses the same primitives.

### Implementation Dashboard

Status key: `[DONE]` complete, `[PART]` partially complete, `[TODO]` not started.

Overall: `[##########] 100%`

| Phase | Status | Progress | Code state |
|---|---:|---:|---|
| Phase 0 — Foundation | `[DONE]` | `[##########]` | Claims, chase movement, AI stamina, proximity tackle, alert net, search behavior, and escalation doctrine implemented. |
| Phase 1 — Police | `[DONE]` | `[##########]` | Suspicion, hail/ID checks, vehicle pursuit, backup dispatch, sirens/lights, roadblocks, and search handoff implemented. |
| Phase 2 — TCK Trucks | `[DONE]` | `[##########]` | LKP-seeded hunts, adaptive quiet, fireteam split, intercept pressure, roadblocks, no-teleport recovery, and panic flavor implemented. |
| Phase 3 — Checkpoints | `[DONE]` | `[##########]` | Choke scoring, legal passage, bypass pursuit, barrier consequences, spikes, pursuit cars, and night flare dressing implemented. |
| Phase 4 — Border & Forest | `[DONE]` | `[##########]` | Live detection, layered border zone, patrol belts, sensor gaps, tripflares, trackers, heli manhunt, and ambience implemented. |
| Phase 5 — Feedback & Tuning | `[DONE]` | `[##########]` | Heat HUD, chase stingers, difficulty presets, public tuning values, chase caps, and KPI logging implemented. |

Step log:
- `[DONE]` 2026-07-02: Phase 0 helper registration and first chase retrofits.
- `[DONE]` 2026-07-02: Phase 0 completed with escalation state, endurance-scaled wrangle, AI chase stamina, and full foundation registration.
- `[DONE]` 2026-07-02: Phase 1 completed with server-authoritative police suspicion, hail/ID checks, foot/vehicle pursuit, backup, sirens, search, and roadblock dispatch.
- `[DONE]` 2026-07-02: Phase 2 completed with TCK adaptive hunts, split dismount teams, intercept/roadblock pressure, no-teleport recovery, bad-route memory, and civilian panic.
- `[DONE]` 2026-07-02: Phase 3 completed with checkpoint terrain scoring, compliant inspection, bypass/running consequences, pursuit vehicles, spike damage, and night alert dressing.
- `[DONE]` 2026-07-02: Phase 4 completed with layered western border patrols, sensor gaps, tripflares, breadcrumb trackers, night helicopter response, jittered inner line, and ambient flares.
- `[DONE]` 2026-07-02: Phase 5 completed with HUD threat cues, chase stingers, difficulty presets, public tuning variables, and KPI counters.
- `[DONE]` 2026-07-02: Rebuilt `addons/co_main.pbo`; `validate_build.ps1` and `validate_mission.ps1` passed.

### Phase 0 — Foundation (F1–F6)
New files: `fn_claimUnit/fn_releaseUnit`, `fn_chaseMove` (intercept + re-issue
threshold + speed coef + cordon), `fn_proximityTackle`, `fn_alertNet` (publish/query),
`fn_searchBehavior`, escalation-state helpers. Retrofit the five existing loops to
claim units and route their chases through the kit.
**Acceptance:** a lone player who sprints from 2 police officers on open ground is
tackled within ~20 s; the same player who breaks LOS in a village and hides indoors
survives the search; no unit visibly ping-pongs between two orders.

**Progress (2026-07-02):**
- Done: registered `fn_claimUnit`, `fn_releaseUnit`, `fn_chaseMove`,
  `fn_proximityTackle`, `fn_alertPublish`, `fn_alertQuery`, and `fn_searchBehavior`.
- Done: police foot chases, checkpoint alerts, border alerts, bus escort hunters, and
  TCK global aggression now use ownership claims before issuing chase orders.
- Done: retrofitted pursuit movement uses predicted intercepts, speed coefficient
  boosts, proximity tackle, and alert-net publishing in the active chase controllers.
- Done: police foot chase converts lost sight into `fn_searchBehavior` instead of a
  silent timeout.
- Done: F6 escalation-state helpers, police suspicion/ID flow, vehicle pursuit,
  sirens, endurance-scaled wrangle, AI chase stamina, and later phase systems are
  implemented.

### Phase 1 — Police overhaul (P1–P6)
Suspicion meter + hail/ID-check interaction, vehicle pursuit + backup dispatch + spike
dispatch, sirens, search conversion.
**Acceptance:** walking past police at wanted 0 is safe but watched; at wanted 60 the
player gets hailed before being chased; fleeing by car triggers an actual car chase
that can end in a roadblock; escaping requires hiding, and the town stays hot for
minutes afterward.

**Progress (2026-07-02):** Done in `fn_policePatrols`, `fn_policeFootChase`,
`fn_policeVehiclePursuit`, `fn_policeResponseFX`, `fn_dispatchRoadblock`,
`fn_setEscalationState`, and `fn_searchBehavior`.

### Phase 2 — TCK trucks (T1–T6)
Hunter radius/LKP seed, adaptive dismount, fireteam split, intercept driving,
roadblock requests, teleport removal.
**Acceptance:** a stopped truck near a player *always* produces a coordinated hunt
within 25 s; hunters cordon rather than conga-line; no vehicle ever teleports; a truck
chasing a fleeing car gets meaningful cut-off help from a second truck.

**Progress (2026-07-02):** Done in `fn_busAgroLoop`, `fn_chaseMove`,
`fn_proximityTackle`, `fn_alertPublish`, `fn_alertQuery`, `fn_dispatchRoadblock`, and
`fn_civilianPanic`.

### Phase 3 — Checkpoints (C1–C5)
Choke-point scoring, legal-passage interaction, bypass detection + pursuit car +
radio-ahead, barrier-run consequences, night dressing.
**Acceptance:** a compliant low-wanted player can pass a checkpoint; driving around one
in view of the guards gets you chased and flagged at the *next* checkpoint; at least
half of stamped checkpoints sit at genuinely hard-to-bypass terrain.

**Progress (2026-07-02):** Done in `fn_placeCheckpoints`, `fn_stampCheckpoint`,
`fn_checkpointControl`, `fn_policeVehiclePursuit`, and `fn_dispatchRoadblock`.

### Phase 4 — Border & forest (B1–B5)
Detection-anchor fix (do first — it's one line), three-layer zone, tripflares, tracker
teams, night heli, ambience.
**Acceptance:** moving through border forest produces at least one patrol contact per
km; crossing at night without scouting trips a flare and a manhunt; a scouted gap +
timed crossing succeeds — escape feels earned.

**Progress (2026-07-02):** Done in `fn_buildWestBorderEnforcement`,
`fn_buildBorderForts`, `fn_borderAlert`, and `fn_borderZone`.

### Phase 5 — Feedback & tuning (X1–X4)
Heat HUD, stingers, difficulty presets, KPI-driven balancing pass across all phases.
**Acceptance:** a new player can articulate their current threat state without reading
docs; KPI logs show chase catch-rate in the 40–70% band vs. fleeing players (thrilling,
not hopeless).

**Progress (2026-07-02):** Done in `fn_heatHud`, `fn_chaseStinger`,
`fn_applyDifficultyPreset`, `fn_kpi`, `fn_initServer`, `fn_initClient`, and
`CO_adminDefaults.sqf`.

### Quick wins (can ship immediately, before Phase 0)
1. ~~Bus escort hunt radius 28 → 80 m and seed hunters with the trigger target.~~ Done in `fn_busAgroLoop`.
2. ~~`setAnimSpeedCoef 1.12` on any unit in an active chase; reset after.~~ Done through `fn_chaseMove`/`fn_releaseUnit` for retrofitted chase controllers.
3. ~~Police chase deadline 75 s → 180 s.~~ Done in `fn_policeFootChase`, with search conversion on lost sight.
4. ~~Border response loops: scan from live leader position instead of camp center.~~ Done in `fn_buildWestBorderEnforcement`.
5. ~~Police excluded from `fn_tckGlobalAggression` (biggest single "distraction" source).~~ Done.
6. ~~Siren + blue light on responding police cars.~~ Done through `fn_policeResponseFX`.
