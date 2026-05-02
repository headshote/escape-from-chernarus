# Chernarus Occupation — Gameplay Reference

Arma 3 multiplayer mission (1–32 players). Players start as ordinary Chernarus civilians
under military occupation by a pro-government enforcer faction (CRN_ENF). Russians (RUS_ADV)
are advancing from the east. The player's arc is: survive the occupation → get conscripted →
escape → join the resistance.

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
- Crowd resistance (`fn_crowdResistance`) can block or slow enforcers.
- If a guard closes to 2.5 m the **wrangle minigame** fires (`fn_wrangleMinigame`).
- Win wrangle → 3-second head-start, wanted level +30.
- Lose wrangle → `setCaptive true`, transport to detention.

---

## Hostile Buses

Buses run fixed routes derived from the road graph (nearby-settlement pairs). Each bus
carries `CO_bus_hostilesPerBus` guards (default 5). Large towns get a minimum of
`CO_bus_townGuaranteed` buses (default 3).

Bus agro loop (`fn_busAgroLoop`) detects players within range, triggers `fn_checkpointAlert`
using the bus guard group.

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

---

## Endurance Bar

Client-side HUD (`fn_enduranceBar`). Tracks sprint/stamina as `CO_endurance` (0–100).
Depletes on movement, recovers at rest. Below 20: `setCustomAimCoef 4` (penalty).
Displayed via `hintSilent` text bar, updates every 6 frames.

---

## Police System

Town police patrols in Chernogorsk, Elektrozavodsk, Berezino, Zelenogorsk, Stary Sobor.
- 2 police Offroads per town, pistol-armed, gendarmerie uniform.
- Every 5 s: check all players for `CO_wantedLevel ≥ 50` + positive recognition result.
- If triggered: pursue → wrangle → transport to detention.
- Traffic system also has random car stop checks at `CO_police_carStopChance` frequency.

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

---

## Civilian AI

40 NPCs spread across `CO_settlements`. Each reacts to nearby military:
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
