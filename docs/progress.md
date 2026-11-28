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
| Mae (M2 re-run) | second QA pass and new screenshots (same worker resumed) | sonnet | medium | 173 cases twice, 0 failures; all 3 scenarios lost with no input and a second scenario starts on a healthy ship; every new ship command accepted, raw repair/damage/add_heat rejected; APK builds (57.2 MB); emulator not verified; 3 low layout leftovers |
| Lyra (L1 layout round) | untruncated captions, text floor, re-shot screenshots (same worker resumed) | sonnet | medium | 174 cases; truncation and text-floor tests added; 18 screenshots re-shot and viewed |

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

### Verification (run 2026-11-25 and 2026-11-26 by the main session on the merged tree)

Each step ran with `set -o pipefail`, its own log, and its real exit status.

| step | exit |
|---|---|
| install Godot 4.7.2, GdUnit4 (pinned) | 0 / 0 |
| scripts/check_sim_purity.sh | 0 |
| scripts/check_ship_sources.py (ships/1701d.json) | 0 |
| scripts/selftest_checks.sh | 0 |
| scripts/run_tests.sh: 174 test cases, 0 errors, 0 failures, 0 orphans | 0 |
| QA: scripts/run_tests.sh twice, same counts (173 cases at the time) | 0 / 0 |
| QA: main scene with the real runtime, 300 ticks, no errors | 0 |
| QA: scripts/export.sh android debug (APK 57,212,892 B) | 0 |

Test growth: 45 cases before the phase; 141 after the first merge; 158 after the runtime fixes; 174 final.
Scenario win and loss paths are tested headless by command (tests/scenarios) and by panel buttons (tests/ui).
Screenshots: docs/screens/1701d/ (station menu and 8 panels, each at 1280x720 and phone landscape 2160x1080 px
at 402 dpi, 864x432 dp, with a UiScale override because xvfb has no 402 dpi). All 18 were looked at; the only
truncated text left is the scenario title in the phone status strip.

Not verified: the Android emulator smoke test (no /dev/kvm, no emulator binary, no system image in the
container; the APK was built but never installed or run); the GitHub Actions run on the PR (see the PR for its
status); the Windows export was not run on a real Windows machine; the manual-derived values listed in the notes
are estimates; the 3 "decode Variant" error lines in the test log come from a deliberate bad-data from_save test
and do not fail the suite.

### Plan check

Orson sonnet/high confirmed at session start. Spawns match the agent plan table (Iris sonnet/medium, Kit
sonnet/medium, Lyra sonnet/medium, Mae sonnet/medium, Greta sonnet/high) with these mismatches: (1) Kit, Lyra,
Greta and Nell ran as `general-purpose` because `implementer` and `reviewer` are not available in this session;
(2) Nell is planned as fable/high, her fable run failed on an API usage-credit error and the review ran on
sonnet/high instead; (3) spawns beyond the plan: Kit, Lyra and Mae were each resumed for fix rounds, Lyra twice;
(4) Iris could not source four value groups, so the main session wrote the estimate rows; (5) Lyra was hired for
this phase (roster entry in the config repo).

## Phase 4: NCC-1701-A (2026-11-26): partial, ship data held

Goal (PLAN.md section 8, milestone 4): the NCC-1701-A playable: ship data, film-era (tmp) widget kit with CRT
shader, panels and 3 scenarios (intermix imbalance, emergency manual restart, battle damage with the warp-fed
phaser rule). Accept: each scenario won and lost by command and by panel buttons; panels readable at 1280x720 and
on a 6-inch phone; all CI jobs green.

Status: NOT met. Under the new source rule (docs/sources.md, Rules) no Star Trek ship value may be used until it is
found and confirmed canon. The three 1701-A books could not be read, so ship data, panels and scenarios are held
and not built. Only the parts that use no ship value were built: the film-era kit and the CRT shader.

Orson's session check at start: `get_session` reported model claude-sonnet-5-5, effort high. The working branch was
at the Phase 1 commit; it was fast-forwarded to `main` (Phases 2 and 3 merged) before any work.

### Spawn log

One line per spawned worker: agent, task, model, effort, result.

| agent | task | model | effort | result |
|---|---|---|---|---|
| Iris (R1) | 1701-A source gate: ship values, 3 scenarios, font, Godot Compatibility facts | sonnet | medium | 45 rows: 3 scenarios, phaser/shield/torpedo/power/alert film rows, Exo 2 font (ENG-FONT-006..008), Godot rows (ENG-GODOT-019..022). All three books unreadable (lending-restricted, HTTP 401, or no copy online); StarTrek.com has no text; nothing bypassed; every book-only value NOT RECORDED |
| Orson (inline) | source rule in the ledger, ADR 0003 (partial contract), refit labels and transcript note after review | sonnet | high | ADR 0003 written before Lyra started; held systems listed in it |
| Lyra (L1) | tmp widget kit, Exo 2 font, CRT shader, kit gallery, tests, Compatibility screenshots (no panels) | sonnet | medium | 12 widget files, shader, gallery, 9 tests; font checksums match the ledger; 183 cases |
| Greta (G1) | review of `git diff origin/main...HEAD` | sonnet | high | 3 medium, 5 low; 8 of 8 film rows spot-checked match; all confirmed except two items left as documented (see notes) |
| Lyra (L1 fixes) | confirmed G1 findings (same worker resumed) | sonnet | medium | BackBufferCopy per overlay, drawn-size text-floor tests for all widgets, resize handling, token and banner fixes; 189 cases |
| Kit (K3) | not spawned | n/a | n/a | held: no confirmed canon for any ship system |
| Mae (M2) | not spawned | n/a | n/a | held: no panels to screenshot; emulator not possible here (no /dev/kvm, no emulator) |
| Nell (S1) | not spawned | n/a | n/a | held: no ships/1701a.json or 1701-A systems to review |

### Notes

- Agent types: `implementer` and `reviewer` are not available in this session, so Lyra and Greta ran as `general-purpose` with the planned model and effort (same mismatch as Phases 1 to 3).
- Source gate result: values RECORDED: phaser power through the main engines and cut off in an imbalance (A-PHAS-001), shield lower and re-raise time (A-SHLD-004), the wormhole, manual restart and Reliant battle sequences (A-SCN1/2/3-*), alert sequences, auxiliary power sequences. NOT RECORDED (books only): reactor layout, intermix chamber and shaft, dilithium frame role, reactor output, nacelle and conduit counts, reactor procedures; impulse engine count, location, output; phaser bank count, locations, output; torpedo tube count and stowage; shield layout, facings, output; navigational deflector location and rating; deuterium and antimatter storage, dilithium reserve; battery capacity; life support and gravity; damage control parties; green alert rule.
- The impulse half of the project rule ("phasers and impulse lose power when the warp reactor is in trouble") has no primary support: TMP shows phaser power cut in an imbalance while impulse stays usable (A-IMP-001); TWOK ties impulse only to restored auxiliary power (A-IMP-002). The phaser half is confirmed (A-PHAS-001). Needs the owner's decision or a book.
- Film rows were read from public fan-made transcripts (film not viewed, no timestamps); TMP, TWOK and TSFS rows show the refit NCC-1701 and say so; that the 1701-A carries the same design is a project assumption.
- G1 findings: fixed: overlays sharing the screen copy (BackBufferCopy per overlay; copy mode is viewport because rect mode rendered black on Compatibility under software GL), text-floor tests that did not pin the drawn sizes, stale scanline period after resize, weak shader and determinism tests, font cache, banner overdraw, missing refit labels in the ledger, transcript not named. Left as is: `TmpTokens.fit()` with width 0 or less returns the text uncut (same as the 1701-D kit, only at absurd widths).
- CRT shader on Compatibility: drawn correctly in a Linux software-GL run (gl_compatibility); Windows and Android Compatibility not run. Flicker not judged in motion. Headless tests cannot show the BackBufferCopy refreshing the screen texture; the screenshots do.
- Phase 3 backlog (1701-D rows D-EPS-001..003, D-CORE-004, D-IMP-009, D-IMP-010, D-COOL-003, D-DMG-001, D-IMP-004): no readable copy of the TNG Technical Manual was supplied, so they stay estimates or unverified and the 1701-D ship data is unchanged.
- No sim/core change, no change to ships/.

### Verification (run 2026-11-26 by the main session on the final tree)

Each step ran with `set -o pipefail`, its own log, and its real exit status.

| step | exit |
|---|---|
| install Godot 4.7.2, GdUnit4 v6.2.3 (pinned) | 0 / 0 |
| scripts/check_sim_purity.sh | 0 |
| scripts/selftest_checks.sh | 0 |
| scripts/check_ship_sources.py (ships/1701d.json) | 0 |
| scripts/run_tests.sh: 189 test cases (174 before the phase), 0 errors, 0 failures, 0 orphans | 0 |
| headless project start, `--quit-after 30`, 0 ERROR lines (run by the UI worker) | 0 |

Screenshots: docs/screens/1701a/ (kit gallery at 1280x720 and phone landscape 2160x1080 px at 402 dpi, 864x432 dp with a UiScale override); both viewed.

Not verified: the Android emulator smoke test (no /dev/kvm, no emulator binary); Windows and Android rendering of the CRT shader; the GitHub Actions run on the PR (see the PR for its status); everything about the 1701-A ship data, panels and scenarios, which are not built.

### Plan check

Orson sonnet/high confirmed at session start. Spawns match the agent plan table (Iris sonnet/medium, Lyra sonnet/medium, Greta sonnet/high). Mismatches: (1) Lyra and Greta ran as `general-purpose` because `implementer` and `reviewer` are not available; (2) Kit (K3), Mae (M2) and Nell (S1) were planned and not spawned, for the reasons in the log; (3) Lyra was resumed once for the fix round, beyond the plan; (4) the Phase 3 backlog was not touched (no readable copy).

## Phase 4b/5: NCC-1701-A and NCC-1701-E (2026-11-26): both tracks stopped after the source investigation

Goal: finish milestone 4 (1701-A: ship data, panels, 3 scenarios) and build milestone 5 (1701-E: ship data, late-LCARS
kit, panels, 3 scenarios), under the source rule in docs/sources.md (every Star Trek value found and confirmed canon
in an official source first).

Status: NOT built. Step 2 (source investigation) found no scenario of either ship with all its systems covered by a
readable source, so the stop rule applied to both tracks: only the two search reports and this entry are committed.
No change to ships/, sim/, ui/ or tests/.

Orson's session check at start: `get_session` reported model claude-sonnet-5-5, effort high. The working branch was at the
Phase 1 commit; it was fast-forwarded to `main` (ba99356, Phase 4 merged) before any work. Base commit for the track diffs: ba99356.

Inputs used: the manuals folder in the private config repo was empty (only placeholder files, index says nothing supplied),
so no book was readable. The prompt's input fields were unfilled placeholders, so defaults were used: scenarios as in the
plan; impulse rule held (not confirmed, not approved; the phaser half A-PHAS-001 stays usable); -E structure reuses the -D
only where an -E source says so; the 1701-D backlog left alone (rows D-EPS-001..003, D-CORE-004, D-IMP-009, D-IMP-010,
D-COOL-003, D-DMG-001, D-IMP-004 stay estimates or unverified; the 1701-D ship data is unchanged).

### Spawn log

One line per spawned worker: agent, task, model, effort, result.

| agent | task | model | effort | result |
|---|---|---|---|---|
| Iris (books) | books and official text for the held 1701-A values and the 1701-E systems: titles, editions, ISBNs, access status, value-to-source map (read-only) | sonnet | medium | 11 sources catalogued; 0 books readable (no supplied copy, lending-restricted or no preview); 2 StarTrek.com pages readable with no systems values; ISBN conflict for Mr. Scott's Guide noted |
| Iris (canon) | on-screen canon: new scenes for TMP to TUC and FC, INS, NEM, second reading per scene (read-only) | sonnet | medium | about 20 new 1701/1701-A rows and 26 FOUND plus 4 partial 1701-E rows from two transcript readings; film not viewed, no timestamps; 5 disagreements recorded |
| Orson (inline) | merged both reports into docs/decisions/1701a-source-search.md and 1701e-source-search.md; stop-rule decision | sonnet | high | both tracks stop; docs-only commit |
| Kit, Lyra, Mae, Greta, Nell (Tracks A and E) | not spawned | n/a | n/a | held by the stop rule: no ship data can be sourced |

### Notes

- Agent types: `implementer` and `reviewer` were not needed; both workers ran as `general-purpose` with the planned model and effort.
- Source gate result: no new ledger rows (R1 not run; the ledger changes only when a source has been read). The scene findings are in the two search reports under search ids (A-SRCH-n, E-SRCH-n).
- Held (needs a readable copy): 1701-A reactor and intermix layout, outputs, impulse, phaser, torpedo, shield and deflector data, fuel, batteries, life support, damage control, green alert; 1701-E warp core and its override, EPS, impulse, shields and armour behaviour, deflector, weapons, life support, damage control, computer, Main Engineering layout, alerts.
- Owner decisions still open: impulse rule (keep as a gameplay rule recorded as a design decision, drop, or source it); manual-restart procedure and numeric outputs for the -A; metaphasic effects on ship systems, armour behaviour and the -E structure choice; the disagreements listed in the two reports.
- PLAN.md was not updated (the stop rule limits this commit to the reports and this entry). Its -E line "more values will be marked estimate" is withdrawn by the source rule; milestone lines 4 and 5 and the sources note should be revised when a track builds.

### Verification (run 2026-11-26 by the main session)

Each step ran with `set -o pipefail` and its real exit status.

| step | exit |
|---|---|
| scripts/check_sim_purity.sh | 0 |
| scripts/check_ship_sources.py (ships/1701d.json) | 0 |
| scripts/selftest_checks.sh | 0 |

Not run: scripts/run_tests.sh and the Godot install (the commit changes only docs, no code or data; the 189 test cases of
Phase 4 are unchanged); the GitHub Actions run on the PR (see the PR for its status). No scenario, panel, ship file or
screenshot exists for either ship, so nothing about them is verified.

### Plan check

Orson sonnet/high confirmed at session start. The two Iris workers ran at sonnet/medium, matching the agent plan table. Mismatches: (1) the workers ran as `general-purpose` as planned for Iris; no `implementer` or `reviewer` types were used; (2) Kit, Lyra, Mae, Greta and Nell were planned for Tracks A and E and not spawned (stop rule); (3) the Android emulator and all build steps are not applicable.

## Phase 5: scope change to 1701-D only and manual audit (2026-11-28)

Goal (PLAN.md section 8, milestone 5): drop the NCC-1701-A and NCC-1701-E tracks and check every `D-*` ledger row
against the TNG Technical Manual (Sternbach and Okuda, 1991), the single source of truth. The manual wins over
dialogue and earlier ledger rows. Corrected values go into `ships/1701d.json` and `sim/systems/`.

Orson's session check at start: `get_session` reported model claude-sonnet-5-5, effort high. The working branch was
at the Phase 1 commit (33 commits behind, no unique work) and was fast-forwarded to `main` (9748b64) before any work.

### Acceptance criteria

1. No 1701-A or 1701-E file or reference is left. This progress file (old entries are history) and docs/PLAN.md
   (states the dropped scope) are excluded; the command must print no file name:
   `grep -rliE "1701-?a\b|1701-?e\b|themes/(tmp|fc)|tmp_kit|\| A-[A-Z]+-[0-9]{3}|Sovereign|Constitution|Haynes|Mr\. Scott" . --exclude-dir=.git --exclude=progress.md --exclude=PLAN.md`
2. Every `D-*` row in docs/sources.md cites the manual section and book page, or says "not in the manual" with
   the reason. Numbers taken from the manual were checked on the page image. No `A-*` row and no A/E source rule
   is left; the rules section follows PLAN.md section 1 (manual first).
3. Rows that were `estimate` or `unverified` and that the manual covers (D-EPS-001..003, D-CORE-004, D-IMP-004,
   D-IMP-009, D-IMP-010, D-COOL-003, D-DMG-001) hold the manual value, or state "not in the manual".
4. Every changed value is carried into `ships/1701d.json` and `sim/systems/` (tests first where behaviour
   changes); every ship value cites a ledger id that exists.
5. All of these exit 0, each run with `set -o pipefail`, its own log and its real exit status:
   - `scripts/install_godot.sh` and `scripts/install_gdunit4.sh`
   - `scripts/check_sim_purity.sh`
   - `python3 -I scripts/check_ship_sources.py`
   - `scripts/selftest_checks.sh`
   - `scripts/run_tests.sh` (0 errors, 0 failures, 0 orphans)
   - `scripts/export.sh` for linux, windows and android (debug)
6. Reviews: Greta (G1, `git diff main...HEAD`) and Nell (S1, ships/1701d.json and sim/systems against the updated
   ledger, manual pages spot-checked); confirmed findings fixed and step 5 re-run.
7. PR against `main` opened and CI green. README status line has no A/E mention.

### Spawn log

One line per spawned worker: agent, task, model, effort, result.

| agent | task | model | effort | result |
|---|---|---|---|---|
| Kit (K-clean) | remove every 1701-A/E file and reference (ui/themes/tmp and fc, test_tmp_kit, docs/screens/1701a, ADR 0003, two source-search reports); run the suite | sonnet | medium | all deleted, nothing from the 1701-D kit needed keeping; 174 test cases (189 minus the 15 in the removed kit test), 0 errors, 0 failures, 0 orphans; ran as `general-purpose` (no `implementer` type) |
| Iris (R1a) | manual check of chapters 1-4: D-DESIGN, D-SIF, D-IDF, D-ENG, D-DIAG, D-COMP (58 rows) | sonnet | medium | 58 match, 0 corrected; several ledger page numbers wrong (fixed); 51 new rows (D-SEP, D-COMP, D-SIF, D-IDF, D-DESIGN, D-ENG, D-DIAG); every number read on a page image |
| Iris (R1b) | manual check of chapter 5: D-WARP, D-NAC, D-FUEL, D-SAFE plus D-CORE-001/002/004/005, D-COOL-003, D-DMG-001 (55 rows) | sonnet | medium | 49 match, 6 not in the manual (core output, breach time and threshold, coolant, damage-control teams); 39 new rows (D-WARP, D-NAC, D-BUSS, D-FUEL, D-SAFE) |
| Iris (R1c) | manual check of chapters 6, 7, 11, 12, 15, 16: D-IMP, D-EPS, D-NAVD, D-TRAC, D-PHAS, D-TORP, D-SHLD, D-MODE (69 rows) | sonnet | medium | 61 match, 3 corrected (D-IMP-009, D-TORP-002, D-MODE-009), 2 new values for estimates (D-IMP-004 = 10^8 MW, D-EPS-001), 3 not in the manual (D-EPS-002, D-EPS-003, D-IMP-010); 93 new rows (one duplicate dropped) |
