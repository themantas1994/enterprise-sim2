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
