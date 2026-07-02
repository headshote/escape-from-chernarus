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

Status key: `[DONE]` complete **and verified in game**, `[CODE]` code exists but
failed or is unverified in live play, `[PART]` partially complete, `[TODO]` not started.

> **2026-07-02 playtest verdict (Chernogorsk): the city loop does not work.**
> Police drive by or park dead in the road, TCK ignore being massacred at
> point-blank range, pedestrian police are inert, and the HUD shows
> contradictory heat/wanted. Root causes are catalogued in
> **Part 4 — Round 2 Audit** below. The previous "100%" claims were
> code-written claims, not play-verified claims. Do not trust a phase as done
> until its Part 3 acceptance test passes in a live session.

Overall (play-verified): `[##--------] ~20%`

| Phase | Status | Verified in game | Notes |
|---|---:|---:|---|
| Phase 0 — Foundation | `[CODE]` | No | Helpers exist and are called, but chase-cap logic is broken (R2-13), stuck-flag leaks lobotomize controllers (R2-3/4), no watchdog. |
| Phase 1 — Police | `[CODE]` | **Failed** | Suspicion thresholds unreachable in normal play; vehicle pursuit never resumes patrol; urban foot police have no controller at all. |
| Phase 2 — TCK Trucks | `[CODE]` | **Failed** | No under-fire reaction (mounted TCK are skipped by every aggression path); captive-cap deadlocks the state machine; nearest-target rule means players are never picked in crowds. |
| Phase 3 — Checkpoints | `[CODE]` | No | Control loop + pursuit car exist; per-tick COMBAT/RED spam will ruin chases; no leash; unverified. |
| Phase 4 — Border & Forest | `[CODE]` | No | Unverified; same thread-death and flag-leak risks apply. |
| Phase 5 — Feedback & Tuning | `[PART]` | **Failed** | HUD renders via fading hintSilent (flashes, then vanishes); heat vs wanted contradiction confuses rather than informs; wanted economy has no crime inputs. |

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
5. ~~Police excluded from `fn_tckGlobalAggression` (biggest single "distraction" source).~~ Done — **but see R2-5: this orphaned the urban police foot patrols.**
6. ~~Siren + blue light on responding police cars.~~ Done through `fn_policeResponseFX`.

---

# Part 4 — Round 2 Audit (post-playtest) & Repair Plan

Playtest report (Chernogorsk, 2026-07-02): cops drive by or park dead mid-road and do
nothing; pedestrian cops only hassle NPC civilians; a full magdump into a TCK truck
cabin (2 dead, 1 wounded, 2 witness trucks nearby) produced **zero** response; HUD
showed `Heat [***--]` alongside `Wanted 0`.

Every one of those observations is reproduced by the code below. This part is in three
sections: **4.1** the exact defects behind each symptom, **4.2** latent bugs found on
the way, **4.3** the repair plan (phases R1–R4) with acceptance tests that must pass
in a live session before anything is marked done again.

## 4.1 Why the city felt dead — defect-by-symptom

### Symptom 1 — "Cops drive by, never get out; sometimes stop dead and do nothing"

**R2-1. A clean player can never trip the suspicion meter — and there is no other
police interaction left.** `fn_policePatrols.sqf:104-128`: suspicion needs ~5–10
*consecutive* 5-second ticks of unbroken line-of-sight from the (moving) patrol car to
reach the 60 threshold; a single obscured tick decays −15, being 190 m away decays
−10. A cruising car holds LOS on a walking player for maybe 2–3 ticks. Meanwhile the
old random traffic-stop mechanic (`CO_police_carStopChance` on players) was removed in
the rewrite — the remaining random stop (`fn_policePatrols.sqf:164`) fires ~once per
2 min per car **and only targets NPC civilians**. Net: at wanted 0 the police have
*no* code path that ever engages a player. "Safe at wanted 0" was the design, but
with no ID-check pressure at all, the city reads as "police are decorative."

**R2-2. After a vehicle pursuit ends, the patrol car is abandoned wherever it stopped.**
`fn_policeVehiclePursuit.sqf:115-126`: on timeout/failure it releases claims and sets
a SEARCH state — but never issues the resume-patrol epilogue that `fn_policeFootChase`
has (reboard, `setCurrentWaypoint`, `forceSpeed -1`, SAFE/LIMITED). The car keeps its
last `doMove` destination and parks there forever. That is the "stopped dead in the
middle of the road, doing nothing" car.

**R2-3. One SQF error permanently lobotomizes a patrol — and there is no watchdog.**
The chase threads set sticky state *before* doing risky work:
`CO_policeFootChaseActive` / `CO_vehiclePursuitActive` (checked at
`fn_policePatrols.sqf:78-79` — while true, the patrol brain skips **everything**),
`_car forceSpeed 0`, `CO_responseActive`, and broadcast `CO_captureInProgress` on the
target. If the thread dies (any runtime error in `chaseMove` / `searchBehavior` /
`kpi` / remote wrangle), none of that is ever cleared: the group never scans again,
the car never moves again, and — worst — the *player* keeps
`CO_captureInProgress = true`, which makes **every aggression system on the map skip
them forever** (bus scan `fn_busAgroLoop.sqf:575`, tck global
`fn_tckGlobalAggression.sqf:133`, checkpoint alert `fn_checkpointAlert.sqf:8`,
police random stop). One early broken chase = the player becomes a ghost for the rest
of the session. This is the most likely master-cause of "nobody ever tried me."
(Note: the try/catch wrappers in `fn_initServer` only catch `throw` — SQF runtime
errors abort the thread without being caught.)

**R2-4. `CO_responseActive` leak keeps the siren/light loop alive forever** on the
same failure paths (set at `fn_policeFootChase.sqf:44`, cleared only on clean exit).

### Symptom 2 — "Pedestrian cops busy chasing civilians, never tried me"

**R2-5. Urban POLICE foot patrols have no brain.** `fn_spawnUrbanFootPatrols.sqf:5-7`
says they "rely on existing aggression systems (tckGlobalAggression +
checkpointAlert)" — but this same commit **removed POLICE from tckGlobalAggression**
(`fn_tckGlobalAggression.sqf:64-66`) and nothing replaced it. Gendarmerie foot pairs
now walk waypoints and can never engage anyone. The "cops" you saw chasing civilians
were the CRN_ENF (TCK) foot groups.

**R2-6. Nearest-target rule means players never get picked in a crowd.**
`fn_tckGlobalAggression.sqf:155-156` and the bus hunters sort candidates purely by
distance. In a populated Chernogorsk there is almost always an NPC civilian man
closer to the patrol than you are, so TCK foot groups spend the whole session
knocking out civilians and statistically never select a player. There is no weighting
for `isPlayer`, wanted, heat, or being armed.

### Symptom 3 — "Magdumped a TCK cabin, killed 2 — nothing happened"

**R2-7. Mounted TCK are unreachable by every reaction path.** The only
return-fire/retaliation logic lives in `fn_tckGlobalAggression`, which (a) skips the
entire bus group while its truck is alive (`:78-81`), and (b) skips any mounted unit
(`:86`). `fn_busAgroLoop` itself has **no under-fire handling at all** — its own
header comment (lines 31–35) describes Hit/Killed handlers flipping escorts to
AWARE/RED, but that code does not exist anywhere in the file. The `Hit` EH from
`fn_initHostileUnit` dutifully records `CO_retaliateTarget` on the group — and nothing
ever consumes it for bus groups. Result: you can execute a mounted squad point-blank
and the survivors sit in their seats.

**R2-8. Violence has no consequences in the wanted economy.** Grep of all
`CO_wantedLevel` writers: capture events, checkpoint interactions, fleeing an ID
check, desertion. **Killing or wounding TCK/police raises nothing** — no wanted, no
heat, no `alertPublish`, no witness reaction from the two trucks sitting next to the
massacre. `CO_hasFiredWeapon` is set client-side on firing, but only the police
suspicion sweep reads it (and only within 190 m of a patrol car). The single most
extreme act of defiance in the game is invisible to the game.

**R2-9. Bus captive-cap deadlock.** `fn_busAgroLoop.sqf:396-401`: once the truck
holds `CO_bus_maxCaptives` (3) NPC captives, the main loop `continue`s **before** the
state machine — but delivery to detention is only triggered from the reboard path
*inside* the state machine. If the cap is reached while dismounted (trivial in a
dense town during a 60 s hunt window), the truck freezes in `dismounted` state
forever: engine idling, escorts' hunt threads expiring, everyone standing around the
truck. This is the "TCK just standing around their truck / sitting in an idling
truck" picture.

### Symptom 4 — "Heat [***--] but Wanted 0 — is this broken?"

**R2-10. Heat and wanted are two disconnected currencies and the HUD max()es them.**
`fn_heatHud.sqf:21`: stars = `max(wanted, heat) / 20`. Heat is written by
`fn_setEscalationState` (hail = 25, checkpoint inspection = 35, fled-inspection = 65,
failed papers = 75) with **max-merge, never reduced by events**, decaying only 5/min
once the state expires to CLEAR. Driving anywhere near a checkpoint once → 3 stars
for ~13 minutes, while wanted stays 0 because wanted only moves on captures. The two
numbers answer different questions and the HUD never says which. (Your `***--` +
`Wanted 0` = you brushed a checkpoint inspection trigger, probably without noticing
the systemChat line.)

**R2-11. The HUD is a fading hint, not a HUD.** `hintSilent` fades out after a few
seconds and `fn_heatHud` only re-renders **when the text changes**
(`fn_heatHud.sqf:46-49`) — so the display appears for one hint-lifetime per change
and then vanishes: the "tooltip that flashes occasionally." It also shares the single
hint channel with anything else that hints.

## 4.2 Latent bugs found during the audit (will bite even after 4.1 is fixed)

- **R2-12. checkpointAlert reintroduces command-stomping on itself:**
  `fn_checkpointAlert.sqf:120-125` re-issues `doTarget` + `setCombatMode RED` +
  `setBehaviour COMBAT` on every claimed unit **every 0.7 s** — the exact per-tick
  spam RC1 was about, and COMBAT behaviour makes chasers bound/crawl tactically, so
  checkpoint chases will look broken the moment they're actually exercised. Also no
  leash: static checkpoint guards will sprint cross-country for 180 s.
- **R2-13. `fn_claimUnit` chase-cap is dead code:** the inner
  `if (...) exitWith { false }` (`fn_claimUnit.sqf:60-62`) exits only the
  `then {}` block, not the function — execution falls through and grants the claim.
  The `CO_maxSimultaneousChases` cap never rejects anything.
- **R2-14. Wrangle minigame has no mutex:** bus hunters run one thread per escort
  aimed at the same target; several can tackle-trigger in the same second, each
  remoteExec'ing `wrangleMinigame`. The second `createDialog` fails →
  `CO_wrangleResult` defaults to "captured". Player gets captured by a dialog bug.
- **R2-15. Checkpoint guards firing at occupied vehicles**
  (`fn_checkpointAlert.sqf:150-157`) can destroy the vehicle — occupants die from the
  explosion, bypassing the non-lethal doctrine entirely.
- **R2-16. `fn_policeVehiclePursuit` driver handling:** `_driver` resolved once; if
  the driver dies mid-pursuit nobody replaces him (loop keeps doMove'ing a corpse's
  car).
- **R2-17. Escalation states only expire via `fn_getEscalationState`, which runs
  exclusively in the player's own HUD loop** — NPC states never expire server-side,
  and if the HUD isn't running (dedicated server objects) heat never decays.

## 4.3 Repair plan

Ordering rule: R1 makes the city *react* (the playtest failures), R2 makes the game
*legible*, R3 builds the verification harness so "done" can't drift from reality
again, R4 finishes the remaining original phases against that harness.

### Phase R1 — Make the city react (fixes symptoms 1–3)

> **Status 2026-07-02: R1 code complete** (all items a–h below), PBO rebuilt,
> `validate_build.ps1` + `validate_mission.ps1` passed. Marked `[CODE]` — each
> item's acceptance test still needs a live Chernogorsk session before it can be
> crossed off as `[DONE]`. New functions: `fn_reportCrime`,
> `fn_installCrimeWitness`, `fn_runWrangle`, `fn_stateWatchdog`,
> `fn_policeBrain`, `fn_policeResumePatrol`.

- `[CODE]` **R1-a. Crime & witness system (new `fn_reportCrime`).** Server-side `Killed`/`Hit`
  EH on every TCK/POLICE unit (extend `fn_initHostileUnit`) and a `FiredNear`-based
  gunshot witness check: if any TCK/POLICE/civilian has LOS within ~120 m of the
  crime, the shooter gets wanted +40 (wound) / +60 (kill, cumulative to 100), heat to
  match, an `alertPublish` with high heat, and the town alert level rises. Unwitnessed
  crimes stay unwitnessed — sneaky kills remain viable. This single system makes the
  magdump scenario produce: both witness trucks dump escorts, police converge, WEAPONS
  posture. *Acceptance: kill a TCK in view of another truck → visible armed response
  within 15 s, wanted ≥ 60, HUD shows it.*
- `[CODE]` **R1-b. TCK under-fire doctrine in `fn_busAgroLoop`.** Group-level `Hit`/`Killed`
  reaction (consume the existing `CO_retaliateTarget` group var): immediate emergency
  dismount (reuse the existing full-dismount block regardless of state), escorts claim
  at priority 90, WEAPONS escalation via the chase kit against the attacker.
  Remove the mounted-unit blanket skip for retaliation cases in
  `fn_tckGlobalAggression`. *Acceptance: shoot at any TCK truck → full dismount +
  return pressure within 10 s.*
- `[CODE]` **R1-c. Fix the bus captive-cap deadlock:** when the cap is reached, force the
  delivery path (reboard + `transportToDetention`) instead of `continue`
  (`fn_busAgroLoop.sqf:401`). *Acceptance: a truck that reaches 3 captives drives to
  detention within 60 s.*
- `[CODE]` **R1-d. Stuck-state watchdog (server loop, 30 s tick).** Every sticky flag gets a
  timestamp when set (`CO_policeFootChaseActive`, `CO_vehiclePursuitActive`,
  `CO_responseActive`, `CO_captureInProgress`, `CO_grpEngaging`, `forceSpeed 0` cars,
  broken `CO_busState`). The watchdog clears any flag older than its owner's maximum
  legitimate lifetime, restores `forceSpeed -1`, and logs `[CO][WATCHDOG]` so thread
  deaths become visible instead of permanent. *Acceptance: kill a chase thread
  artificially → patrol resumes within 60 s; player never stays permanently invisible.*
- `[CODE]` **R1-e. Vehicle pursuit epilogue:** shared `fn_policeResumePatrol` (reboard +
  waypoint restore + SAFE/LIMITED + forceSpeed −1) called from every exit path of
  both pursuit functions. *Acceptance: after any failed pursuit the car is cruising
  again within 60 s.*
- `[CODE]` **R1-f. Urban police controller:** run the same suspicion/hail/ID-check brain for
  foot police groups (extract the patrol-loop body from `fn_policePatrols` into a
  shared `fn_policeBrain` taking [group, car-or-null]); foot police respond to
  alertNet entries within 400 m. Restore player random ID checks using
  `CO_police_carStopChance` (a compliant check should be a 15-second tension beat,
  not a capture). *Acceptance: standing near a foot patrol at wanted 0 eventually
  produces a papers check; at wanted 60+ it produces a chase.*
- `[CODE]` **R1-g. Target selection weighting:** replace nearest-only sorting in
  `fn_tckGlobalAggression` and bus hunters with score = distance − (isPlayer ? 40 : 0)
  − heat×0.5 − (armed ? 25 : 0). Players stop being statistically invisible in
  crowds. *Acceptance: player and NPC civ equidistant from a TCK patrol → player is
  picked when heat > 0.*
- `[CODE]` **R1-h. Wrangle mutex + grab ownership:** `CO_wrangleActive` (timestamped) on the
  target; only one grab owner may open the dialog; other chasers hold cordon during
  the wrangle. Fix the `fn_claimUnit` cap fall-through (restructure without nested
  `exitWith`). Fix checkpointAlert per-tick RED/COMBAT spam (posture once, AWARE, let
  `chaseMove` own movement) and add a 250 m leash + return-to-post.

### Phase R2 — Make it legible (fixes symptom 4)

> **Status 2026-07-02: R2 code complete**, PBO rebuilt and validated. Marked
> `[CODE]` pending a live session. New: `ui/threat_hud.hpp` (RscTitles layer,
> idd 9400) + `RscStructuredText` base in `config.cpp`; `fn_heatHud` rewritten
> onto a persistent cutRsc layer (wanted stars + posture chip + stamina, always
> visible, no hintSilent); escalation expiry + heat decay moved into the server
> maintenance loop in `fn_stateWatchdog` (`fn_getEscalationState` is now
> read-only); `fn_chaseStinger` shows auto-fading transition toasts on a
> dedicated layer alongside the throttled music; siren path is runtime-verified
> with `fileExists` and falls back to config-derived horn blasts
> (`fn_policeResponseFX`, `fn_civilianPanic`).

- `[CODE]` **R2-a. One threat model, one display.** Wanted = the persistent legal standing
  (crimes, captures); heat/escalation = the *current* posture toward you. HUD: stars
  = wanted; a colored state chip (CALM/WATCHED/ID CHECK/PURSUIT/SEARCH/WEAPONS) =
  escalation; both always visible. Replace `hintSilent` with a persistent `cutRsc`
  layer (dedicated RscTitle HUD in `ui/`), stamina bar included. Server-side heat
  decay loop (fixes R2-17).
- `[CODE]` **R2-b. Event toasts:** short systemChat/toast lines on every transition the player
  caused ("Witnessed: murder of an enforcer — wanted increased", "ID check passed",
  "They lost you"). The tension loop must be readable without the docs.
- `[CODE]` **R2-c. Sound sanity pass:** verify `A3\Sounds_F\sfx\alarm.wss` actually resolves
  on dedicated (RPT check); fall back to horn-pulse siren if not.

### Phase R3 — Verification harness (why Round 1 "passed" while broken)

- **R3-a. Scenario self-tests.** `fn_qaScenarios` (admin-triggered or
  `-serverMod` param): spawns a dummy target with configurable wanted/heat near a
  chosen system (police car, TCK truck, checkpoint, border camp), drives it on a
  scripted path, and logs `[CO][QA] PASS/FAIL <scenario> <reason>` by asserting
  observable outcomes (dismount happened, chase started, capture or search occurred,
  car resumed patrol, flags cleared). Run after every build; a failing scenario blocks
  "done".
- **R3-b. RPT triage as a gate.** Any script error in a session is a P0 (per R2-3, one
  error = one lobotomized controller). `tools/check_rpt.ps1` greps the newest RPT for
  `Error in expression` / `[CO][WATCHDOG]` / missing-sound lines and prints a summary.
- **R3-c. KPI assertions.** Extend `fn_kpi` logging with derived rates; a healthy
  session must show chases started > 0, catch-rate 40–70 %, zero watchdog recoveries.

### Phase R4 — Finish the original vision (re-scoped, against the harness)

- Checkpoints: verify legal-passage flow end-to-end with the pursuit car; leash;
  spike-strip consequence chain (C2–C4 acceptance from Part 3).
- Town lockdown (P3) after violent crimes: temporary suspicion multiplier + extra
  foot patrols for 10 min in the affected town — pairs with R1-a.
- Border: run the Part 3 Phase-4 acceptance walk (patrol contact per km, tripflare +
  manhunt at night, scouted-gap crossing) and fix what fails; audit `fn_borderZone`,
  `fn_borderAlert` rewrites with the same claim/flag-leak lens as 4.1.
- Feel: chase stingers only on state *transitions the player can see*; difficulty
  presets exposed in the admin panel; final KPI-driven tuning pass.

### Suggested implementation order

1. R1-d watchdog + R1-h claim/wrangle/spam fixes (they de-risk everything else),
2. R1-a crime system + R1-b TCK under-fire + R1-c deadlock (the playtest's core rage),
3. R1-e/f/g police lifecycle + urban brain + targeting,
4. R2 HUD/legibility,
5. R3 harness, then re-run the Chernogorsk playtest script before touching R4.
