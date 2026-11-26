# Progress log

## Phase 1: research, engine decision, skeleton (2026-11-25)

Goal: source ledger for the 1701-D, the engine decision, and a project skeleton that builds for Windows,
Linux and Android in CI.

### Spawn log

One line per spawned worker: agent, task, model, effort, result.

| agent | task | model | effort | result |
|---|---|---|---|---|
| Iris (R1) | 1701-D source ledger: every Appendix A value checked against the TNG Technical Manual OCR text | sonnet | medium | 171 ledger rows (170 verified, 1 unverified: D-IMP-004, OCR unreadable); 6 differences from the plan appendix reported, phaser value corrected in PLAN |
| Iris (R2) | engine fact sheet (Godot, Flutter, Unity, Bevy/egui) | sonnet | medium | docs/decisions/engine-facts.md, 79 lines; build sizes and several items marked "not verified" |
| Dara (A1) | engine decision from the fact sheet and PLAN only | opus | high | ADR 0001: Godot 4.7.2, GDScript, Compatibility renderer, GdUnit4; unknowns C1 to C6 listed |
| Kit (K1) | project skeleton, headless test runner, CI workflow | sonnet | medium | skeleton built; Linux, Windows and Android debug exports and tests ran locally; C1 to C4 closed (see notes) |
| Nora (N1) | CI, keystore and signing review of the K1 commit | sonnet | high | no high findings; 2 medium, 4 low confirmed, 3 plausible; all 5 action pins matched their tags |
| Kit (K1 fixes) | fix confirmed N1 findings (same worker resumed) | sonnet | medium | fixes 1 to 6, 8, 9, 10 applied plus SDK root change; re-run from clean state |

### Notes

- Opus use (Dara): the engine choice fixes the whole project on three platforms and is costly to reverse; it was one bounded call on a prepared fact sheet.
- Agent types: the plan names `implementer` and `reviewer` types. This session only offers `general-purpose` (an `implementer` call was rejected as not found), so Kit and Nora ran as `general-purpose` with the model and effort of the plan.
- Source gate: the engine decision cites ENG ids from the fact sheet; the engine facts the skeleton uses were copied into `docs/sources.md` as `ENG-GODOT-*` rows, and Kit appended `ENG-CI-*` rows for action pins and tool downloads.
- Open from N1 (not fixed): finding 7 (cached download marker; covered by the pinned checksums) and CODEOWNERS (needs a named owner).

### Verification (run 2026-11-25 from a clean state, fresh tool directory, build/, addons/ and .godot/ removed)

Each step ran with `set -uo pipefail`, its own log, and its real exit status.

| step | exit |
|---|---|
| install Godot 4.7.2 editor and templates (checksums pinned in scripts/pins.env) | 0 |
| install GdUnit4 (pinned commit) | 0 |
| scripts/check_sim_purity.sh | 0 |
| scripts/check_ship_sources.py | 0 |
| scripts/selftest_checks.sh (both checks fail on bad input) | 0 |
| scripts/run_tests.sh: 3 test cases, 0 errors, 0 failures (JUnit XML) | 0 |
| export Linux / Windows / Android debug (0 ERROR lines in each log) | 0 / 0 / 0 |
| Android SDK and debug keystore setup (scripts/setup_android.sh) | 0 |

Artifact sizes: Linux 73,710,816 B; Windows exe 103,183,728 B; Android APK 56,968,369 B.
No keystore, tool directory or build output is tracked in git.

Not verified: the GitHub Actions workflow has not run on GitHub (YAML parse only); the exports were not run
on a real Windows machine or an Android emulator; the Android APK has not been installed on a device.

### ADR 0001 checks

- C1 GdUnit4 on Godot 4.7.2: passes with v6.2.3 (README lists 4.7 and 4.7.1 only); no fallback to 4.7.1.
- C2 and C3 (scanline shader on Compatibility, `_draw()`): drawn correctly on Linux in a software-GL screenshot;
  not yet run on Windows or Android.
- C4 debug keystore in CLI export: the export generated its own when the variables were unset; CI still creates one.
- C5 workflow: unrun on GitHub. C6 sizes: recorded above.

### Plan check

Spawns match the model and effort of the agent plan (Orson sonnet/high confirmed at session start; Iris sonnet/medium;
Dara opus/high; Kit sonnet/medium; Nora sonnet/high). One mismatch: Kit and Nora ran as the `general-purpose` agent type
because `implementer` and `reviewer` are not available in this session. One spawn beyond the plan: Kit was resumed once
to fix the confirmed review findings, as requested.

## Phase 2: simulation core (2026-11-25)

Goal: the ship-independent simulation core with tests, no UI (PLAN.md section 3, milestone 2).
Accept: GdUnit4 tests cover power shortage shedding, conduit cut and reroute, reactor overload to breach,
ejection, and same seed gives the same run; all CI jobs on the PR are green.

Orson's session check at start: `get_session` reported model claude-sonnet-5-5, effort high.

### Spawn log

One line per spawned worker: agent, task, model, effort, result.

| agent | task | model | effort | result |
|---|---|---|---|---|
| Kit (K2) | sim core in sim/core with tests first (shedding, reroute, overload to breach, ejection, determinism, save/load) | sonnet | medium | 33 test cases pass; purity, selftest and ship-source checks exit 0; no real ship values in sim/ or tests/ |
| Mae (M1) | full headless suite twice, same seed; snapshot comparison across two processes, different seed, save/load continuation (no code changes) | sonnet | medium | all four comparisons PASS (identical JUnit results, byte-identical 600-tick snapshot hashes, different seed differs, save/load and JSON round trip continue identically) |
| Greta (G1) | review of `git diff main...HEAD` (commit 02f7120) | sonnet | high | no blockers, 2 major, 7 minor (4 more dropped); 6 confirmed and fixed, 3 not acted on (see notes) |
| Kit (K2 fixes) | fix confirmed G1 findings 1 to 6, tests first (same worker resumed) | sonnet | medium | 45 test cases pass; purity, selftest and ship-source checks exit 0 |

### Notes

- Agent types: the plan names `implementer` and `reviewer` types. This session only offers `general-purpose`, so Kit and Greta ran as `general-purpose` with the model and effort of the plan (same mismatch as Phase 1). Mae is `general-purpose` in the plan.
- Order: the checks, Mae and Greta ran serially on the committed diff; Kit was resumed once for the confirmed findings, as requested.
- G1 findings fixed: (1) dead or ejected nodes still passed power along a path; (2) `from_save` validated only top-level keys; (3) `set_priority`, `set_output` and `set_demand` accepted huge values and `set_output` overwrote the hard maximum (now a separate `output_limit`); (4) loader coerced wrong types; (5) startup countdown not pinned by its test; (6) breach damage "applied once" test too weak.
- G1 findings not acted on: destroyed conduit reports state "cut" (documented ambiguity, cosmetic); path-search iteration guard on very lossy or very large graphs (unconfirmed); the remark about this log naming agents (this file is the one place the spawn log lives).
- Eject question from Mae's run: the scripted `reactor_eject` at tick 450 was correctly rejected because the reactor had already reached breach at tick 23; an accepted eject before the breach tick ends in `ejected` with no breach (probe-confirmed by G1).
- Solver limitation (documented in `sim/core/power_solver.gd`): greedy nearest-source allocation in priority order, not a global max-flow. Fine for the Phase 2 criteria; revisit in Phase 3 if a real ship graph needs optimal routing.
- Source gate: no Star Trek or platform values were used; the fixtures are invented placeholders. Real ship values stay for Phase 3 via `docs/sources.md`.

### Verification (run 2026-11-25 by the main session, after the fixes)

Each step ran with `set -o pipefail`, its own log, and its real exit status.

| step | exit |
|---|---|
| install Godot 4.7.2 editor and templates, install GdUnit4 (pinned) | 0 / 0 |
| scripts/check_sim_purity.sh | 0 |
| scripts/run_tests.sh: 45 test cases, 0 errors, 0 failures, 0 orphans | 0 |
| scripts/selftest_checks.sh | 0 |
| scripts/check_ship_sources.py | 0 |

Baseline before the phase: 3 test cases, all passing. After Kit's first pass: 33. After the review fixes: 45.

Not verified: the GitHub Actions run on the PR (see the PR for its status); cross-platform float determinism is not claimed (same-platform claim from ADR 0001).

### Plan check

Spawns match the model and effort of the agent plan (Orson sonnet/high confirmed at session start; Kit sonnet/medium; Mae sonnet/medium; Greta sonnet/high). One mismatch: Kit and Greta ran as the `general-purpose` agent type because `implementer` and `reviewer` are not available in this session. One spawn beyond the plan: Kit was resumed once to fix the confirmed review findings.

## Phase 3: NCC-1701-D playable (2026-11-25)

Goal: ship data, TNG LCARS widget kit, panels for MSD, warp core, fuel, EPS grid, shields, impulse, SIF/IDF and
damage control, and 3 scenarios: core breach, Borg drain, coolant leak (PLAN.md section 8, milestone 3).
Accept: each scenario can be won and lost (headless GdUnit4 tests for both paths); panels readable at 1280x720
and on a 6-inch phone; all CI jobs on the PR green.

Orson's session check at start: `get_session` reported model claude-sonnet-5-5, effort high.

### Spawn log

One line per spawned worker: agent, task, model, effort, result.

| agent | task | model | effort | result |
|---|---|---|---|---|
| Iris (R1) | ledger gaps for the 1701-D ship data, 3 scenarios, font licence and platform facts | sonnet | medium | 22 rows (Borg, coolant, core breach on-screen canon; Antonio and Oswald OFL 1.1; 48 dp; Godot 4.7 UI facts). EPS, core output, impulse reactors and damage control could not be sourced: the manual text is lending-restricted (HTTP 401), nothing bypassed |
| Orson (inline) | 9 `estimate` ledger rows for the unsourced groups (D-EPS-001..003, D-CORE-004/005, D-IMP-009/010, D-COOL-003, D-DMG-001) and the component contract (ADR 0002) | sonnet | high | rows labelled estimate with the reason; ADR 0002 written before Kit and Lyra started |
| Kit (K3) | ships/1701d.json, sim/systems, 3 scenarios, tests (own worktree) | sonnet | medium | 135 components, ShipRuntime, 3 scenarios, 126 tests; one generic core change (`add_heat`, 3 tests); greedy solver sufficient |
| Lyra (L1) | tng kit, 8 panels, station menu, scenario select and status, SimHost (own worktree, parallel with Kit) | sonnet | medium | 15 UI tests; Antonio font from the pinned commit, checksum matches; UI built against a fake runtime |
| Mae (M2) | tests, real-runtime run, panel screenshots at both sizes, panel-to-sim check, Android | sonnet | medium | 141 cases pass twice; all 3 scenarios lost with no input; found no UI controls for ship commands, scenario state carried over, phone layout cut off; APK builds, emulator not verified (no KVM, no emulator binary, no system image) |
| Greta (G1) | review of `git diff main...HEAD` | sonnet | high | 3 major (UI cannot win 2 scenarios; raw repair bypasses damage control; second scenario inherits a destroyed ship), 6 minor; all confirmed, fixed |
| Nell (S1), first run | realism review | fable | high | failed at start: API 429, fable usage credits exhausted; no result |
| Nell (S1), stand-in | realism review | sonnet | high | 1 high (shield level below Alert minimum), 4 medium, 8 low, read-only (Godot not run); 12 acted on, 3 documented as simplifications |
| Kit (K3 fixes) | confirmed findings from Greta and Nell, tests first (same worker resumed) | sonnet | medium | 158 cases; send() rejects raw repair, damage, add_heat; scenario start resets the ship in place; shield level 0.85..1; per-hull SIF/IDF rule |
| Lyra (L1 fixes) | confirmed UI findings (same worker resumed) | sonnet | medium | ship-command controls on every panel, layout fixes, SimHost validity and dispose, UI-driven win tests for all 3 scenarios; 173 cases |
| Mae (M2 re-run) | second QA pass and new screenshots (same worker resumed) | sonnet | medium | see Verification |

### Notes

- Agent types: the plan names `implementer` and `reviewer` types; this session offers `general-purpose` (and a few unrelated ones). Kit, Lyra, Greta and Nell ran as `general-purpose` with the model and effort of the plan (same mismatch as Phases 1 and 2).
- Model deviation: Nell is planned as fable/high. Her fable run died on an API usage-credit error before producing anything, so the review was re-run on sonnet/high. This is a deviation from the plan table; a fable review of ships/1701d.json is still outstanding.
- Source gate: the TNG Technical Manual text could not be read in this session (the only online text copy is lending-restricted). Everything the ship file takes from EPS, core and nacelle power, impulse reactors, backup generators, coolant loops and damage control is `estimate` (rows D-EPS-*, D-CORE-004/005, D-IMP-009/010, D-COOL-003, D-DMG-001). D-IMP-004 stays unverified and unused. These rows should be checked against a readable copy of the manual.
- Power unit is MW. Canon-scale rows (D-IMP-003, D-SHLD-016, D-NAVD-009) do not drive live values. Cruise shield draw is the ledger's 1,152 MW (D-SHLD-011).
- Core change: `add_heat` command in sim/core (generic; coolant needs to add and remove heat), with tests.
- Solver: the greedy priority allocator was sufficient for the 1701-D graph (trunk cut reroutes through `eps_cross_link`, shedding follows priority). Known side effect: the nearest source is always preferred, so load balancing between reactors is done with setpoints.
- Documented simplifications: core ejection is manual only (D-SAFE-003..005); no shield backup service timer (D-SHLD-009); Borg shield adaptation is a gameplay mapping of D-BORG-001/002 and the power drain is a gameplay invention (D-BORG-004, estimate); Separated Flight and diagnostics (D-MODE-009/010, D-DIAG) are not modelled; runtime and system state have no save/load.
- Open: theme is built once at startup (no rebuild on window resize or rotation); tank fill bars scale against the highest level seen because the snapshot has no tank capacity; the Android emulator smoke test is not verified.
- Repo hygiene: the existing Phase 1 convention names agents in this file and in the `verified_by` column of older ledger rows; no new file outside this log names an agent, memory or the config repo.
