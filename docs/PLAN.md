# Enterprise Engineering Simulator 2: Plan

Status: draft plan, 2026-11-25. Nothing is built yet.
Scope: a cross-platform (Windows, Linux, Android) engineering-station simulator for three ships:
USS Enterprise NCC-1701-A, NCC-1701-D and (optional) NCC-1701-E. Each ship has its own panels, its own
systems model and the visual language of its era.

## 1. Sources

| Ship | Primary source | Secondary sources |
|---|---|---|
| 1701-A (refit Constitution) | *Mr. Scott's Guide to the Enterprise* (Shane Johnson, 1987); *The U.S.S. Enterprise NCC-1701 Illustrated Handbook* (Eaglemoss/Hero Collector, covers 1701 and 1701-A) | Films TMP to TUC (engine room, intermix chamber, dialogue), *Star Fleet Technical Manual* (Franz Joseph, 1975) for the older TOS layer only |
| 1701-D (Galaxy class) | *Star Trek: The Next Generation Technical Manual* (Sternbach and Okuda, 1991) | Haynes manual; episodes (engineering scenes, Master Systems Display) |
| 1701-E (Sovereign class) | No dedicated technical manual exists. Use the *Haynes U.S.S. Enterprise Owners' Workshop Manual* (2010, covers NX-01 to 1701-E, Okuda as consultant) | TNG Tech Manual chapter "Future Directions: The Road to 1701-E"; films FC, INS, NEM |

Important limits:
- 1701-D: the TNG Technical Manual was read (archive.org OCR text, 2026-11-25) for chapters 2.4-2.7,
  3.11-3.15, 4.1, 5.2-5.10, 6.1-6.2, 7.1-7.5, 11.1, 11.3, 11.8 and 15.5-15.9. The values in Appendix A
  come from it, paraphrased, with section numbers. Chapter 17.2 ("Road to 1701-E") was written before
  the Sovereign class existed and gives nothing usable for the -E.
- 1701-A and 1701-E: those sources were not read. Their sections are from general knowledge and must be
  checked against the maintainer's own copies. Data files carry a `source:` field per value (book + section, or
  `estimate`).
- Do not copy text, diagrams or artwork from the books into the project. Use them for systems, names and
  behaviour, then draw your own panels.

## 2. Recommended technology

The engine is decided in Phase 1 from a researched fact sheet (`docs/decisions/engine-facts.md`) and
recorded in `docs/decisions/0001-engine.md`. The leading candidate going in:

**Godot 4 (GDScript), one codebase, three exports.**

Going-in assessment: Godot 4 - cross-platform 2D UI + animation + audio + touch for Win/Linux/Android -
free (MIT), one project exports to all three targets, strong custom-drawing and theming, headless mode
for tests and CI. GDScript rather than C# because Godot's Android support for C# is less mature.

Alternatives considered:
- Flutter: very good custom painting and also targets all three, but audio, game-loop timing and
  shader effects (CRT glow, scanlines) are more work.
- Web stack (Tauri + Capacitor): two wrappers to maintain; touch latency on Android is worse.

Supporting pieces:
- Tests: GdUnit4 for the simulation core, run headless (chosen in `docs/decisions/0001-engine.md`).
- CI: GitHub Actions with a headless Godot export image; artifacts: Windows `.exe`, Linux x86_64
  binary, Android `.apk` (debug) and later a signed `.aab`.
- Android needs the Android SDK, JDK 17 and a release keystore (kept out of the repo).

## 3. Systems model per ship

The simulation is the same engine for all three ships; each ship is a data file that wires up nodes.

### Shared simulation core
- Fixed tick (10 Hz), independent of frame rate, deterministic given a seed (for tests and replays).
- **Node graph**: producers (reactors), stores (fuel tanks, batteries), conduits (with capacity, loss,
  heat and damage), consumers (engines, shields, weapons, life support). Each consumer has a priority;
  when supply is short, power is shed lowest-priority first.
- **Heat and wear**: each component has temperature, efficiency and integrity; overload raises heat;
  heat lowers efficiency and integrity; damage can cut a conduit and force rerouting.
- **State machines** for the big components (reactor: cold, startup, standby, online, overload,
  containment failing, breach, ejected).
- **Events/scenarios**: scripted or random faults, combat damage, orders from the bridge.
- **Alert conditions**: green, yellow, red; each changes power priorities and panel lighting.

### NCC-1701-A (refit Constitution, film era)
- Warp reactor: vertical matter/antimatter intermix chamber and horizontal intermix shaft; dilithium
  crystal articulation frame; intermix ratio and imbalance (TMP wormhole incident as a scenario).
- Impulse engines draw from the warp reactor (film-era behaviour). Gameplay rule: warp reactor trouble
  also cuts impulse power and phaser power ("phasers are fed from the warp engines").
- Deflector shields (single bubble with fore/aft/port/starboard strengths), navigational deflector.
- Weapons power: phaser banks, photon torpedo tubes.
- Fuel: deuterium supply, antimatter pods; emergency batteries.
- Life support, gravity, environmental systems; damage control parties.
- Scenarios: intermix imbalance, wormhole, coolant leak, Reliant-style battle damage, radiation in the
  reactor room, emergency manual restart (Wrath of Khan), cloaked attacker (TUC, torpedo hits).

### NCC-1701-D (Galaxy class), based on the TNG Technical Manual (numbers in Appendix A)
- Warp core (M/ARA, 5.2) as four modelled parts: matter injector (6 redundant injector sets, any can
  fail and the rest dilate to compensate), antimatter injector (3 pulsed nozzles), upper and lower
  magnetic constriction segments, reaction chamber with the dilithium crystal articulation frame.
- Core start-up as a real sequence the player runs (5.2): heat to 2.5 million K using EPS power and
  the matter injector, first antimatter injection, idle at 25:1 matter/antimatter, then raise pressure
  to 72,000 kPa. The ratio moves toward 1:1 as warp rises and stays 1:1 from Warp 8 up.
- Two core modes (5.2): power mode (energy to the EPS grid at sublight) and warp mode (dilithium
  positioned for the pulse frequency sent to the nacelles). Dilithium alignment is a player control.
- Power transfer conduits to the nacelles, with EPS taps along them (Type I, II, III, 5.2).
- Nacelles (5.3): 18 coils and plasma injectors per nacelle; injector firing frequency and open time
  change with warp factor (gives the nacelle panel real readouts).
- Fuel (5.4-5.7): 30 antimatter pods on Deck 42, each needing containment power; deuterium tank;
  Bussard collectors (slow emergency refuel, works with the deflector); onboard antimatter generator
  (10 units of deuterium per unit of antimatter, very slow).
- Safety (5.9-5.10): computer is deliberately "overprotective" and throttles back; command override
  allowed at reduced levels. Normal shutdown: close plasma to coils, close injectors, vent; cold in
  about 10 minutes, impulse takes over ship power. Last resorts: annular containment forcefield, core
  ejection (manual or automatic), antimatter pod assembly ejection (automatic only in practice).
- Impulse (6.1-6.2): main impulse engine (Deck 23) plus two saucer engines (Deck 10); fusion reactors
  that also generate power; antimatter boost allowed in emergencies; normal limit 0.25c.
- Power distribution (7.1): EPS grid fed by the warp core, impulse reactors and auxiliary fusion
  generators (these keep power up when both engines are off).
- Shields (11.8): generators in the saucer (5), engineering hull (3) and nacelles (2 each), with
  backups; 5% output in Cruise Mode, at least 85% at Alert; frequency and modulation rotation (player
  control, Borg adaptation mechanic); shields cost warp efficiency (up to 32% coupling loss at maximum).
- SIF and IDF (2.4-2.6): separate generator sets per hull, with backups at reduced power; the IDF has
  a response lag (crew thrown about on sudden hits); the manual's failure ladder maps straight to game
  rules: 2 generators lost means Yellow Alert, 3-4 means slow down and drop out of warp, all lost
  means Red Alert and immediate drop to sublight.
- Navigational deflector (7.4) with three generators; output needs grow with speed; high output
  blinds some sensors. Tractor beam (7.5).
- Weapons (11.1, 11.3): phaser arrays fed from the EPS through flow regulators; photon torpedoes.
- Saucer separation (2.7): 18 docking latches, umbilicals deadfaced, power graph splits into two ships
  (saucer: impulse, shields, SIF/IDF, two antimatter pods on Deck 10, no antimatter transfer between
  sections).
- Computer (4.1): three main cores (two saucer, one engineering hull).
- Operating modes (15.4-15.9): Cruise, Yellow Alert (core to at least 20%), Red Alert (core to 75%,
  diagnostics every 5 minutes), Separated Flight (core above 90%), External Support (docked), Reduced
  Power (shut the warp core if not at warp, impulse at minimum). These become selectable game states
  that change power priorities automatically.
- Diagnostics (3.13): five levels, from Level 5 (about 2.5 s, automatic) to Level 1 (hours, crew
  verified). Good mechanic: faster checks find fewer faults.
- Scenarios: core breach countdown with forcefield and ejection, antimatter pod containment loss, SIF/
  IDF generator cascade failure, Borg shield adaptation, coolant leak, saucer separation at warp, cold
  start from auxiliary power, Bussard emergency refuel, Reduced Power Mode survival.

### NCC-1701-E (Sovereign class, optional, phase 5)
- Same structure as the D, with upgraded values and a few new mechanics: quantum torpedoes, more
  phaser arrays, ablative/regenerative shield behaviour (to be confirmed in the Haynes manual),
  manual override of the warp core, ship-wide Borg assimilation scenario (First Contact), metaphasic
  radiation scenario (Insurrection), Scimitar battle damage (Nemesis).
- Because there is no dedicated manual, more of its values will be marked `estimate`.

## 4. Panels

Each panel is a Godot scene bound to the sim through a small read/write interface. Not every panel exists
on every ship; the ship data file lists the panels and their layout.

| Panel | 1701-A | 1701-D | 1701-E | Main controls and readouts |
|---|---|---|---|---|
| Master systems overview | engine room status board | Master Systems Display ("pool table") plus master situation monitor (wall cutaway highlighting off-nominal systems), warp and impulse status wall schematics (3.15) | MSD | ship cutaway with live system state, alerts |
| Warp reactor / core | intermix chamber | warp core | warp core | ratio, injector flow, plasma temp, containment, start/stop, eject |
| Fuel | deuterium, antimatter | deuterium, antimatter pods | same | levels, pod containment, flow, transfer |
| Power distribution | power transfer board | EPS grid | EPS grid | sources, conduits, per-system allocation sliders, priorities, rerouting |
| Impulse | impulse (warp-fed) | fusion reactors | fusion reactors | output, fuel, temperature |
| Shields | deflector screens | shield grid | shield grid | per-facing strength, frequency, modulation |
| Structural / damping | - | SIF, IDF | SIF, IDF | field strength, generator load |
| Deflector & sensors | nav deflector | main deflector, sensors | same | power, configuration |
| Weapons power | phasers, torpedoes | phaser arrays, torpedoes | + quantum torpedoes | capacitor charge, feed priority |
| Life support | environmental | life support, gravity | same | per-deck status, reserve time |
| Damage control | repair parties | damage control teams | same | assign teams, repair queue, ETA |
| Computer | - | computer cores | computer cores | load, core status |
| Engineering log / comms | - | - | - | bridge orders, Chief's log, event history |

Navigation between panels: a top-level station menu, plus quick tabs; on large screens two or three panels
can show at once.

## 5. Era design language

Use the look of each era, but with original artwork and free fonts. No studio logos, insignia or copied
screen graphics.

### 1701-A: film era (TMP to TUC)
- Dark grey/brown hardware panels with rows of rectangular backlit push-buttons and small translucent
  coloured legends (red, amber, blue, green, white).
- CRT monitors: green or blue vector wireframes, schematic line art, scrolling numeric tables, slight
  glow, scanlines and flicker (shader).
- Physical-looking controls: toggles, sliders, rotary knobs, indicator lamps; buttons look pressed.
- Type: squared, extended sans (free analogues: Michroma, Orbitron, Exo 2).
- Sound: chirps, relay clicks, the deep throb of the intermix chamber.
- Note: by TUC some screens already move toward early flat touch graphics; offer this as a sub-theme.

### 1701-D: TNG LCARS
- Black background, flat colour, no bevels. Rounded "elbow" frames, pill-shaped buttons, horizontal bars
  with numeric labels.
- Pastel palette: peach/orange, salmon, lavender, pale blue, tan; red for alerts.
- Tall, condensed sans in upper case (free analogue: Antonio; also Oswald, League Gothic).
- All touch; short chirps on press; alert states change colour and add blinking.

### 1701-E: late LCARS (First Contact onward)
- Same LCARS grammar, but darker and cooler: deep blues, greys and burnt orange, thinner frames, more
  animated graphs and cutaways, subtle gradients and bevels on panels.
- Denser information per screen, smaller type.

Implementation: one Godot `Theme` + colour tokens + a small widget kit per era (button, bar gauge,
frame/elbow, readout, schematic view, alert banner). Panels are written once against the widget
interface; the era kit decides how they look. Bonus option: let the player choose any era skin for any
ship.

## 6. Platforms and input

- Windows and Linux: mouse and keyboard, resizable window, fullscreen; minimum 1280x720.
- Android: landscape, phones and tablets; touch targets at least 48 dp; layout scales with screen size.
- Shared: keyboard shortcuts on desktop, haptic tick on Android, audio volume and reduced-motion option,
  colour-blind safe alert patterns (shape and blink, not colour only).
- Later option (phase 6): LAN multi-station mode, where one device hosts the sim and other devices (for
  example tablets) each show one panel, like a real engineering room.

## 7. Project layout

```
enterprise-sim2/
  project.godot
  sim/              # pure simulation core, no UI imports (tested headless)
    core/           # tick loop, node graph, power solver, heat, damage
    systems/        # reactor, fuel, shields, impulse, SIF/IDF, weapons, life support
    scenarios/      # scripted events
  ships/            # data: 1701a.json, 1701d.json, 1701e.json (values with source fields)
  ui/
    widgets/        # era-independent widget interfaces
    themes/tmp/ tng/ fc/   # era kits: theme, fonts, colours, sounds, shaders
    panels/         # one scene per panel
  tests/            # GdUnit4 tests
  export_presets.cfg
  .github/workflows/build.yml
```

The repository also holds `docs/sources.md` (the source ledger), `docs/decisions/` (decision records and
the engine fact sheet) and `docs/progress.md` (a per-phase work log).

## 8. Milestones

Each phase ends with its acceptance checks passing in CI.

0. **Repository**: create `enterprise-sim2` on GitHub (MIT licence, fan-made notice in the README).
1. **Research, engine decision, skeleton**: 1701-D source ledger, engine decision record, project in the
   chosen engine, CI exporting Windows, Linux and Android debug builds; one empty panel opens on all
   three.
   Accept: CI produces three artifacts; the APK installs and starts on an Android device or emulator.
2. **Simulation core**: tick loop, node graph, power solver with priorities, heat/damage, reactor state
   machine, save/load. No UI.
   Accept: GdUnit4 tests cover power shortage shedding, conduit cut and reroute, reactor overload to breach,
   ejection; same seed gives the same run.
3. **1701-D first** (best documented ship): ship data, LCARS kit, panels for MSD, warp core, fuel, EPS,
   shields, impulse, SIF/IDF, damage control; 3 scenarios (core breach, Borg drain, coolant leak).
   Accept: each scenario can be won and lost; panels readable at 1280x720 and on a 6-inch phone.
4. **1701-A**: film-era kit (buttons, CRT shader), its ship data and panels; warp-fed impulse and phaser
   rule; 3 scenarios.
5. **1701-E** (optional): late LCARS kit, data marked with estimates where no source exists, 3
   scenarios.
6. **Extras**: LAN multi-station mode, scenario editor, free-play mode with random faults, cross-era
   skins, Android release signing.

## 9. Verification plan

- GdUnit4 command-line runner under `godot --headless` for the sim core (exact command in the CI workflow; exit status
  kept in CI).
- `godot --headless --export-debug "<preset>"` for each platform in CI (debug builds in Phase 1;
  `--export-release` is used once release signing exists).
- Android smoke test: install the APK on an emulator, start it, check logcat for errors, take a
  screenshot of each panel.
- Data check: a script that fails if a ship value lacks a `source` field.

## 10. Legal note

This is a fan project. Star Trek names, ships and designs belong to Paramount/CBS. Keep it
non-commercial, use original artwork and free fonts, add a "fan-made, not affiliated" notice, and don't
ship any text or images from the books or shows.

## 11. Open questions

1. Engine: decided in Phase 1 and recorded in `docs/decisions/0001-engine.md`, unless fixed earlier.
2. Audience: private use, or a public release (affects the legal care and Android store signing)?
3. Is LAN multi-station mode (several devices as one engine room) a must or a later extra?
4. Should each ship always use its own era look, or may the player swap skins?

## Appendix A: 1701-D reference values (TNG Technical Manual)

Paraphrased facts, section numbers in brackets. Use these as the `source:` values in `ships/1701d.json`.
The verified values live in `docs/sources.md`; where this appendix and the ledger differ, the ledger wins
(Phase 1 checks found a few small differences, for example the phaser segment output is 5.1 MW).

**Design targets** [1.1, 5.1]: normal cruise Warp 6 until fuel runs out; maximum cruise Warp 9.2;
Warp 9.6 for up to 12 hours. Ship mass about 4.96 million tonnes. Defensive shielding rated above
7.3 x 10^5 kW dissipation. Phaser emitter segments 5.1 MW each.

**Warp core** [5.2]
- Matter injector: 6 cross-fed injector sets; slush deuterium preburned to about 10^6 K; a failed
  nozzle is covered by the others.
- Antimatter injector: 3 pulsed gas flow separators, each to one nozzle.
- Constriction segments: upper 18 m, lower 12 m, both 2.5 m diameter; add 200-300 m/s to the streams.
- Dilithium frame holds about 1,200 cm3 of crystal, positioned in six degrees of freedom.
- Start-up: 2,500,000 K first; idle at 25:1 matter/antimatter; operating pressure 72,000 kPa;
  reaction temperature 2 x 10^12 K; ratio reaches 1:1 at Warp 8 and stays 1:1 above.
- EPS taps on each power transfer conduit at 5, 10 and 20 m aft of the ejection shear joints;
  Type I takes 0.1 of the flow (high-energy systems), Type II 0.01 (experimental), Type III low power.
- Major core inspection every 10,000 operating hours (starbase only).

**Nacelles** [5.3]: 18 coils per nacelle. Plasma injector firing: Warp 1-4 at 30-40 Hz, open
25-30 ns; Warp 5-7 at 40-50 Hz, open 30-40 ns; Warp 8-9.9 at 50 Hz, longest safe open time 53 ns.
Nacelle ejection by 10 explosive latches at 30 m/s.

**Fuel** [5.4-5.7]
- 30 antimatter pods on Deck 42, 100 m3 each, 3,000 m3 total, about 3 years. Pod assembly ejected at
  40 m/s on containment loss.
- Deuterium tank 63,200 m3, normal load 62,500 m3, slush at 13.8 K, about 3 years; 4 feeds to the
  matter injector, 4 to main impulse, 8 cross-feeds to saucer tanks.
- Antimatter generator: 0.08 m3/h; costs 10 units of deuterium per unit of antimatter.

**Warp safety** [5.9-5.10]: cold shutdown in about 10 minutes; impulse then carries ship power.
Ejection when damage breaches the safety forcefield or threatens the SIF. Pod ejection is in practice
automatic only.

**Impulse** [6.1-6.2]: main engine Deck 23; saucer engines Deck 10; reactor output throttleable from
10^5 to 10^11 MW (OCR reads "10 s"; check); saucer auxiliary tanks 113 m3 each; normal limit 0.25c;
efficiency near 85% below 0.5c; above 0.75c needs the saucer engines too.

**SIF** [2.4]: 3 generators (Deck 11) + 2 (Deck 32); each twenty 12 MW graviton polarity sources and
two 250 millicochrane amplifiers; 2 backups per hull, 12 h at 55%; duty cycle 36 h on, 24 h off;
raises structural strength up to 125,000%; Cruise needs at least one per hull.

**IDF** [2.5]: 4 generators (Deck 11) + 2 (Deck 33); each twelve 500 kW sources and two 150
millicochrane amplifiers; 3 backups per hull, 12 h at 65%; duty cycle 48 h on, 12 h off; field about
75 millicochranes; response lag about 295 ms; Cruise needs at least two per hull.

**SIF/IDF failure rules** [2.6]: without them the ship and crew survive only about 3 g; full impulse
exceeds 1,000 g. 2 generators lost: Yellow Alert. 3-4 lost: Yellow Alert, slow down, drop out of warp
by simple field collapse. All lost: Red Alert, immediate drop to sublight, then power conservation.

**Shields** [11.8]: 5 generators (Deck 10), 3 (Deck 31), 2 in each nacelle; each twelve 32 MW
sources and two 625 millicochrane amplifiers; 4 backups per hull, 24 h at 65%. Cruise output 1,152 MW
at about 5% of rated output; Alert at least 85%, up to 7 generators phase-locked for 2,688 MW
continuous; single-generator peak about 473,000 MW for 170 ms. Frequencies and modulation rotate at
Alert; matching an enemy weapon's frequency raises efficiency. Shields at maximum cost up to 32% of
warp force coupling. No transporting through shields.

**Navigational deflector** [7.4]: 3 generators on Deck 34, each six 128 MW sources and two 550
millicochrane amplifiers; about 27 MW at low sublight (52 MW surge); up to 80% of normal output at
Warp 8 (675,000 MW surge); above about 55% output some sensors go blind.

**Tractor beam** [7.5]: main emitters built on two 16 MW sources, each with two 450 millicochrane
amplifiers.

**Phasers** [11.1]: emitter segments 5.1 MW; fed from EPS primary trunks through an EPS submaster
flow regulator (iris response 0.01 s, magnetic gate 0.0003 s).

**Photon torpedoes** [11.3]: maximum effective range about 3,500,000 km; launchers forward and aft
in the battle section plus one in the saucer.

**Computers** [4.1]: 3 cores (two saucer, Decks 5-14; one engineering, Decks 30-37); LCARS polls each
panel every 30 ms.

**Main Engineering** [3.15]: Deck 36; master systems display table with two workstations, warp and
impulse status wall schematics, master situation monitor, Chief Engineer's office next to the core,
isolation doors and containment forcefields; can take over Conn, Ops and Tactical.

**Operating modes** [15.5-15.9]: Yellow Alert: core to at least 20%, Level 4 diagnostics, one backup
reactor hot, secondary deflectors partial standby. Red Alert: core to 75%, Level 3 diagnostics then
Level 4 every 5 minutes, all backups hot. Separated flight: core above 90%, saucer SIF/IDF high.
Reduced Power: cold-shut the core unless at warp, impulse at minimum, backup fusion on standby.

**Diagnostics** [3.13]: Level 1 hours (crew verified) ... Level 3 about 10 min ... Level 4 under 30 s
... Level 5 about 2.5 s, at least daily.
