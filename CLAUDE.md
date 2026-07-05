# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is an Arma 3 multiplayer mission (`@ChernOccupation`) written in SQF. Players
start as Chernarus civilians under military occupation and progress: survive →
conscripted → escape → resistance. Two deep reference docs already exist and are the
source of truth for behavior — read them before non-trivial work:

- **ARCHITECTURE.md** — init chain, road-graph system, globals table, dialog IDDs,
  build process, and a per-round changelog (R1–R8) describing why each subsystem is
  shaped the way it is.
- **GAMEPLAY.md** — player-facing mechanics (wanted level, checkpoints, buses,
  conscription pipeline, escape, police, Russian advance) with the tunables behind them.

## Build / run / validate

**Before completing any work that touches addon sources (`addons/main/**` — SQF, config.cpp,
or UI hpp), you MUST rebuild the PBO and run the validators, and report their output.**
SQF is not compiled at edit time, so an unbuilt change is unverified. The minimum gate is:

```powershell
tools\build_addon.ps1        # must print [OK] Rebuilt (or [OK] up to date)
tools\validate_build.ps1     # must pass
tools\validate_mission.ps1   # must pass when mission sources changed
```

Do not describe a change as "done" until the build succeeds and the validators pass. If a
build/validate step fails, fix it before reporting completion.

There is no unit-test framework. Full verification is: build → launch dedicated server →
grep the RPT. All tooling is PowerShell under `tools/` and is invoked by the launcher.

```powershell
# Rebuild the addon PBO (addons/main -> addons/co_main.pbo). Requires Arma 3 Tools installed.
tools\build_addon.ps1                 # -SkipIfUpToDate to build only when sources changed
tools\validate_build.ps1              # verify PBO prefix, no duplicate PBO, CfgFunctions path, embedded fn_*.sqf
tools\validate_mission.ps1            # verify mission.sqm + playable slots present

# Launch a local dedicated server. Auto-detects Arma3/Server/CBA/CUP installs on any Steam library.
# Stages the mission UNPACKED (no mission PBO needed for local iteration) and builds the addon first.
local_start_server.bat

# After a run, scan the newest RPT for regressions (returns exit 1 on failure).
tools\check_rpt.ps1                   # greps for script_errors, [CO][WATCHDOG], [CO][QA] FAIL, missing sounds
```

A healthy run has **zero** `[CO][WATCHDOG]` lines (each is a state-machine recovery) and
zero script errors. In-game QA assertions run via `["all"] call co_main_fnc_qaScenarios`
(server console / admin only) and log `[CO][QA] PASS/FAIL`.

### Build gotchas (these have each broken the build before — see ARCHITECTURE.md §Build)

- The internal PBO prefix (`$PBOPREFIX$`) is **`main`**, but the output file is
  **`co_main.pbo`** and the function namespace is **`co_main_fnc_*`**. A stray `main.pbo`
  in `addons/` will be loaded by Arma and override the good PBO with broken paths — the
  build script deletes it, but watch for it.
- Addon Builder must be told to copy `*.sqf;*.hpp` directly, or the PBO ships `config.bin`
  with no scripts. `build_addon.ps1` handles this via an include file.
- UI base classes (`RscText`, `RscSlider`, `RscCheckBox`, `RscButton`, `RscStructuredText`)
  must be declared in `config.cpp` **before** the `#include "ui/*.hpp"` lines, because Addon
  Builder parses without A3's default UI classes.
- VS Code will flag false-positive CBA namespace errors — these do not affect builds.

## Adding a function

Every function is one file `addons/main/functions/fn_NAME.sqf` **and** a matching
`class NAME {};` entry under `CfgFunctions/co_main/Main` in `config.cpp` (naming:
`fn_NAME.sqf` → `co_main_fnc_NAME`). Missing the config entry means the function silently
does not register. Call as `[args] call co_main_fnc_NAME`. Rebuild the PBO after.

## Cross-cutting conventions (the load-bearing ones)

- **Server authority + remoteExec.** Anything mutating world/mission state runs on the
  server. Client-callable functions start with `if (!isServer) exitWith { [...] remoteExecCall
  ["co_main_fnc_X", 2]; };`. Admin-gated functions additionally validate the caller
  server-side via `remoteExecutedOwner` → match `owner _x` in `allPlayers` → check
  `getPlayerUID` against `CO_adminUIDs` (see `fn_setDifficultyPreset` / `fn_qaScenarios`).
  `CO_adminUIDs` holds Steam64 UIDs **as strings** (`["76561198054336866"]`) to match
  `getPlayerUID`.

- **One controller per unit — the claim arbiter.** Multiple async loops compete to command
  AI. Any loop that orders a unit MUST `[unit, token, priority, ttl] call co_main_fnc_claimUnit`
  first and skip units it fails to claim; claims expire so a dead thread can't deadlock a
  unit. Priority doctrine (in `fn_claimUnit`): 10 ambient / 30 stop / 40 failsafe / 50 NPC
  chase / 70 player chase / 90 retaliation. `fn_tckGlobalAggression` refuses to touch any
  unit holding a claim ≥ 60. Bypassing this system is the usual cause of units teleporting,
  jittering, or marching off-map.

- **Faction disambiguation.** CRN_ENF (occupation) and CRN_FRONT (frontline military) are
  *both* BLUFOR `createGroup west`. Distinguish them at runtime by
  `(group unit) getVariable "CO_faction"` — never by side.

- **Globals vs per-player vars.** Tunable globals live in
  `missions/ChernOccupation.Chernarus/CO_adminDefaults.sqf`, are `publicVariable`-broadcast,
  and re-broadcast from `fn_initServer`. Adding a tunable means editing BOTH the defaults
  file's broadcast list and `fn_initServer`'s list. Per-player state (`CO_wantedLevel`,
  `CO_detainPhase`, `CO_isAWOL`, boot-camp/escape flags, etc.) is set via `setVariable`.

- **Respawn is a clean slate.** A server `EntityRespawned` EH in `fn_initServer` wipes every
  per-player pipeline flag on the new body. When you add a sticky per-player flag, add it to
  that wipe (and to any pipeline-recycle reset like `fn_awolConfrontation`'s detain path) or
  it will leak across deaths.

- **Non-lethal capture pipeline.** Captures knock out (`fn_applyKnockout`) rather than kill;
  `fn_installNonLethalDamage` caps damage except where a flag (e.g. `CO_awolExecution`) lifts
  it. `setHitPointDamage` does NOT fire the "Hit" EH — melee (`fn_applyMeleeHit`) is invisible
  to retaliation systems, so those paths mark targets explicitly.

- **Resilient init.** `fn_initServer` wraps each step in try/catch recording into
  `CO_initStepStatus`; one failing subsystem must not empty the whole map. Preserve that
  isolation when adding init steps.
