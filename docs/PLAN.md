# Enterprise Engineering Simulator 2: Plan

Status: plan rewritten 2026-11-28 after a change of scope. Phases 0 to 3 are built (see `docs/progress.md`).
Scope: a cross-platform (Windows, Linux, Android) engineering-station simulator for **one ship only: USS
Enterprise NCC-1701-D (Galaxy class)**. The NCC-1701-A and NCC-1701-E tracks are dropped; their code, data and
documents are removed in Phase 5.

## 1. Source of truth

**The single source of truth is *Star Trek: The Next Generation Technical Manual* (Rick Sternbach and Michael
Okuda, Pocket Books, 1991).** The maintainer supplies a readable copy (OCR text layer, 196 pages) to the
sessions that check values; it is never added to this repository.

Rules, in order:
1. Every Star Trek value (a number, a component name, a behaviour, a procedure) comes from the manual and is
   recorded in `docs/sources.md` with its section and book page. Where the manual gives a value, it wins over
   any other source, including dialogue and earlier ledger rows.
2. Where the manual is silent, an on-screen TNG episode (named, with the scene) may be used only for scenario
   flavour (for example the Borg or a coolant leak). Such rows say "not in the manual" in `meaning`.
3. Values that are not Star Trek facts (heat rates, countdown lengths, damage per hit, conduit losses the
   manual does not give) are `estimate` game-tuning rows that say why. They must never contradict the manual.
4. A value the manual should hold but the OCR text cannot read is checked against the page image. If it is
   still unreadable it stays `unverified` and is not used.
5. Engine and platform facts: the vendor's own documentation for the exact version (`ENG-*` rows).
6. Paraphrase only. Never copy text, tables, diagrams or artwork from the manual into the project. Panels are
   original drawings; fonts are free.

The OCR text has noise on numbers and tables (for example "10 s" for an exponent). Every number taken from the
manual is checked against the page image before it is marked `verified`.

## 2. Technology (decided, ADR 0001)

Godot 4.7.2, GDScript, Compatibility renderer; GdUnit4 for headless tests; GitHub Actions exporting Windows,
Linux and Android debug builds. Android needs the Android SDK, JDK 17 and, for releases, a keystore kept out of
the repo. The sim core in `sim/` has no UI imports (checked by `scripts/check_sim_purity.sh`).

## 3. Systems model

### Shared simulation core (built, Phase 2)
Fixed 10 Hz tick, deterministic from a seed; node graph of producers, stores, conduits and consumers with
priority shedding; heat, efficiency and integrity per component; reactor state machine; events and scenarios;
alert conditions that change power priorities.

### NCC-1701-D systems, with their manual sections

Built in Phase 3 (values to be re-checked in Phase 5) are marked **(built)**.

| System | Manual | What the sim models |
|---|---|---|
| Warp core / M/ARA **(built)** | 5.2 | matter injector (6 cross-fed sets, failed nozzle covered by the rest), antimatter injector (3 nozzles), constriction segments, dilithium articulation frame; start-up sequence (2.5 million K, first injection, 25:1 idle, 72,000 kPa); ratio to 1:1 from Warp 8; power mode and warp mode; dilithium alignment as a player control; EPS taps Type I/II/III |
| Nacelles | 5.3 | 18 coils per nacelle; plasma injector frequency and open time by warp factor; nacelle ejection |
| Antimatter storage and transfer **(built, partly)** | 5.4 | 30 pods on Deck 42 with containment power; pod assembly ejection |
| Deuterium supply **(built, partly)** | 5.5 | main tank, feeds and cross-feeds to the saucer tanks |
| Bussard ramscoop refuel | 5.6 | slow emergency refuel, tied to the navigational deflector |
| Onboard antimatter generation | 5.7 | 10 units of deuterium per unit of antimatter, very slow |
| Warp safety and emergencies **(built, partly)** | 5.8-5.10 | "overprotective" computer throttling with command override; normal shutdown sequence (cold in about 10 minutes, impulse takes ship power); annular forcefield; core ejection; pod ejection |
| Impulse **(built)** | 6.1-6.5 | main engine (Deck 23) and two saucer engines (Deck 10); fusion reactors that also feed the EPS; antimatter boost; 0.25c limit; impulse shutdown and emergency procedures |
| Utilities / EPS **(built)** | 7.1 | EPS grid fed by the warp core, impulse reactors and auxiliary fusion generators |
| Reaction control | 7.3 | RCS thrusters (station keeping, low-speed manoeuvre) |
| Navigational deflector | 7.4 | 3 generators; output grows with speed; high output blinds some sensors |
| Tractor beam | 7.5 | emitters, power draw |
| SIF and IDF **(built)** | 2.4-2.6 | generators per hull with backups; IDF lag; the failure ladder (2 lost: Yellow; 3-4: slow down and leave warp; all: Red, sublight) |
| Saucer separation | 2.7 | 18 latches, umbilicals deadfaced, power graph splits into two ships |
| Computer cores | 4.1 | 3 main cores, subprocessors, core load and failover |
| Engineering stations and diagnostics | 3.11, 3.13, 3.15 | Main Engineering layout; diagnostics Levels 1-5 (faster checks find fewer faults) |
| Phasers | 11.1-11.2 | arrays fed from EPS through flow regulators |
| Photon torpedoes | 11.3-11.4 | launchers, loading, power |
| Deflector shields **(built)** | 11.8 | generators per hull and nacelle with backups; Cruise and Alert levels; frequency and modulation rotation; warp coupling loss |
| Auto-destruct | 11.9 | command-authorised sequence, as a scenario end state |
| Environmental systems | 12.1-12.4 | life support, atmosphere, gravity, emergency environmental support |
| Fire suppression | 16.2 | per-section fire and suppression fields |
| Operating modes **(built, partly)** | 15.3-15.9 | Cruise, Yellow Alert, Red Alert, External Support, Separated Flight, Reduced Power, each changing priorities automatically |

Any row the manual does not support after the Phase 5 audit is dropped or marked as a documented gameplay
simplification.

## 4. Panels

Each panel is a Godot scene bound to the sim through the read/write interface in ADR 0001. LCARS only.

| Panel | Status | Main controls and readouts |
|---|---|---|
| Master Systems Display | built | ship cutaway with live system state, alerts |
| Warp core | built | ratio, injector flow, temperature, containment, start/stop, eject |
| Fuel | built | deuterium, antimatter pods, flow, transfer |
| EPS grid | built | sources, conduits, allocation, priorities, rerouting |
| Impulse | built | output, fuel, temperature |
| Shields | built | per-facing strength, frequency, modulation |
| SIF / IDF | built | field strength, generator load, backups |
| Damage control | built | teams, repair queue, ETA |
| Nacelles | Phase 6 | coil and injector readouts by warp factor |
| Deflector, tractor and sensors | Phase 6 | generator power, output, sensor blind zones |
| Weapons power | Phase 6 | phaser feed, torpedo launchers |
| Environment | Phase 6 | life support, atmosphere, gravity per deck, reserve time, fire |
| Computer and diagnostics | Phase 6 | core load and status, diagnostics level runner |
| Engineering log | Phase 6 | bridge orders, event history |

Navigation: station menu plus quick tabs; on large screens two or three panels side by side.

## 5. Design language: TNG LCARS

Black background, flat colour, no bevels; rounded elbow frames, pill buttons, horizontal bars with numeric
labels; pastel palette (peach, salmon, lavender, pale blue, tan) with red for alerts; tall condensed upper-case
sans (Antonio, OFL); all touch with short chirps; alert states change colour and blink. Colour-blind safe alerts
(shape and blink, not colour only). One theme and widget kit in `ui/themes/tng/`.

## 6. Platforms and input

Windows and Linux: mouse and keyboard, resizable, fullscreen, minimum 1280x720. Android: landscape, phones and
tablets, touch targets at least 48 dp. Keyboard shortcuts on desktop, haptic tick on Android, volume and
reduced-motion options.

## 7. Project layout

```
enterprise-sim2/
  project.godot
  sim/core/        # tick loop, node graph, power solver, heat, damage (no UI imports)
  sim/systems/     # 1701-D systems
  sim/scenarios/   # scripted events
  ships/1701d.json # every value with a ledger id
  ui/widgets/  ui/themes/tng/  ui/panels/
  tests/           # GdUnit4
  docs/            # PLAN.md, sources.md, decisions/, progress.md, screens/1701d/
  scripts/  .github/workflows/build.yml
```

## 8. Milestones

Each phase ends with its acceptance checks passing locally and in CI.

0-3. **Done**: repository, engine and CI, simulation core, 1701-D playable (8 panels, 3 scenarios: core
   breach, Borg drain, coolant leak). The Phase 4 work for the 1701-A and 1701-E is superseded.

5. **Scope change and manual audit**
   - Remove everything for the 1701-A and 1701-E: `ui/themes/tmp/`, `ui/themes/fc/`, their fonts, shaders,
     gallery and tests, the `A-*` ledger rows and the A/E source rules, ADR 0003 and the two source-search
     reports, and any A/E references in README, scripts, CI and project settings. Git history keeps them.
   - Check every `D-*` ledger row against the manual (section and book page, number checked on the page
     image). Correct wrong values; replace `estimate` rows with manual values where the manual has them
     (EPS sources and capacities, core output, impulse reactors, coolant, damage control, D-IMP-004).
   - Carry corrected values into `ships/1701d.json` and `sim/systems/`, tests first where behaviour changes.
   Accept: no A/E file or reference left (grep check); every `D-*` row cites manual section and page or says
   why it is not in the manual; all checks and tests pass; CI green.

6. **Complete the 1701-D systems**: the Phase 6 rows of sections 3 and 4 (nacelles, Bussard and antimatter
   generation, cold start, RCS, deflector, tractor, saucer separation, computer and diagnostics, weapons power,
   environment, fire suppression, all operating modes) and the new panels. Scenarios: antimatter pod
   containment loss, SIF/IDF generator cascade, saucer separation at warp, cold start from auxiliary power,
   Bussard emergency refuel, Reduced Power Mode survival.
   Accept: each scenario can be won and lost, tested headless by command and by panel buttons; panels
   readable at 1280x720 and on a 6-inch phone; realism review against the ledger passes.

7. **Polish and platforms**: runtime save/load, theme rebuild on resize and rotation, audio, accessibility
   options, free-play mode with random faults, Android emulator smoke test, Windows check.

8. **Extras (optional)**: LAN multi-station mode, scenario editor, signed Android release.

## 9. Verification

- `scripts/check_sim_purity.sh`, `scripts/check_ship_sources.py`, `scripts/selftest_checks.sh`.
- `scripts/run_tests.sh` (GdUnit4 under `godot --headless`, real exit status).
- `scripts/export.sh` for Linux, Windows and Android debug builds.
- Android smoke test: install the APK on an emulator, start it, check logcat, screenshot each panel (needs
  KVM; report "not verified" with the reason if it is missing).
- Source check: every ship value has a ledger id; every `D-*` row cites the manual or says why not.

## 10. Legal note

Fan project. Star Trek names, ships and designs belong to Paramount/CBS. Non-commercial, original artwork, free
fonts, a "fan-made, not affiliated" notice, and no text or images from the manual or the shows.

## 11. Open questions

1. Audience: private use or a public release (affects Android signing and store listing)?
2. Is LAN multi-station mode wanted, or dropped?
