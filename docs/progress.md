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
