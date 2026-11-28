# NCC-1701-E source search (milestone 5, step 2)

Date: 2026-11-26. Status: complete for this session; result: no scenario has all its systems covered by a readable
source, so the 1701-E ship data, widget kit, panels and scenarios are not built. The earlier plan to mark missing
-E values as estimates is withdrawn: a Star Trek value no source states is recorded "not stated", and the game-scale
number that then has to exist is a tuning row or a design decision the owner approves in writing. This report adds
no ledger rows. Ids `E-SRCH-n` below are search ids, not ledger ids.

Method as in `docs/decisions/1701a-source-search.md`: no copy of any book was supplied; books were looked up in
catalogues and on StarTrek.com; films were read through public dialogue transcripts as a reading aid (film not
viewed, no timestamp). CH = chakoteya.net transcript, SS = springfieldspringfield.co.uk subtitle transcript; a
scene is FOUND only when both agree. Draft shooting scripts of First Contact and Nemesis differ strongly from the
films and were not used. StarTrek.com film pages hold one-sentence synopses only. Memory Alpha was not used.

## 1. Books and official text

| source | access | note |
|---|---|---|
| Haynes *U.S.S. Enterprise Owners' Workshop Manual* (UK 2010, ISBN-13 9781844259410; US 9781451621297) | not readable (no contents or sample) | StarTrek.com says it covers the ships in order up to the 1701-E, with a cutaway and systems overview each (defences, deflectors, shuttles, computers named). The only listed book that covers the -E |
| *Star Trek: The Next Generation Technical Manual* (Sternbach and Okuda, Pocket Books, 1 Nov 1991, ISBN-13 9780671704278, 192 pp) | not readable | predates the Sovereign class; a "Future Directions" chapter was not found in the one chapter list seen (unverified, unusable); the project already holds that chapter 17.2 gives nothing for the -E |
| *Star Trek Encyclopedia* (editions 1994, 1999, 2016) | not readable | listings only |
| *Star Trek: Ships of the Line* (2006) | not readable | picture book, unlikely to carry systems values; title not publisher-verified |
| StarTrek.com "Sector 001: Federation Starships of First Contact" (2017) | readable | qualitative only: Sovereign class, flagship, designed by John Eaves, debut in First Contact; no systems values |
| StarTrek.com database page for the Sovereign class | none found | |
| official technical guides or magazine articles for FC, INS, NEM | not located as verifiable titles | not cited |

Values actually read from a book: none.

| system the -E needs | books that plausibly state it | note |
|---|---|---|
| warp core and its manual override | Haynes (P) | the Technical Manual cannot state -E values |
| EPS grid, impulse | Haynes (?), Encyclopedia (?) | |
| shields, ablative or regenerative behaviour | Haynes (P for defences) | behaviour may only be on screen |
| deflector dish and sensors | Haynes (P) | |
| phasers and quantum torpedoes | Haynes (P), Encyclopedia (P, entry level) | |
| fuel and antimatter | Haynes (?) | |
| life support, damage control | Haynes (?) | |
| computer | Haynes (P) | |
| Main Engineering layout | Haynes (P, cutaway) | |
| alert levels | Haynes (?), Encyclopedia (?) | |

## 2. On-screen canon (FC, INS, NEM; the ledger holds no -E film rows)

| id | film | scene | what it states | status |
|---|---|---|---|---|
| E-SRCH-1 | FC | observation lounge | maximum-warp trip to Earth takes 3 h 25 min | FOUND |
| E-SRCH-2 | FC | after the temporal vortex | shields down, long-range sensors off-line, main power holding | FOUND |
| E-SRCH-3 | FC | Borg sphere over Earth | quantum torpedoes fired at the sphere; count not stated | FOUND |
| E-SRCH-4 | FC | engineering, then Worf's report | environmental system fails over a whole deck, maybe EPS conduits; deck 16 humidity up 73% | FOUND (ten-degree rise single reading) |
| E-SRCH-5 | FC | bridge, deck 16 lost | contact with deck 16 lost; deck 16 sealed with security at every access point; pressure +2 kPa, 92% humidity, 39.1 C before loss | FOUND |
| E-SRCH-6 | FC | same | weapons, shields and propulsion control rerouted through main engineering; main computer isolated with a fractal encryption code; Borg cut power to all decks but 16; deck 16 (engineering) taken first | FOUND (main engineering = deck 16 is implied, not stated) |
| E-SRCH-7 | FC | armoury | Borg will form a collective in engineering; firing there risks the warp core; plan to puncture a plasma coolant tank (coolant liquefies organic matter); phasers on rotating modulation, at most 12 shots before adaptation | FOUND |
| E-SRCH-8 | FC | outside engineering | manual door release works; regroup on decks 14 and 15 | release FOUND; deck numbers single reading |
| E-SRCH-9 | FC | bridge | Borg control spans decks 26 up to 11, then stops; deck 11 holds hydroponics, stellar cartography and deflector control; more than half the ship within hours; checkpoint report every ten minutes | FOUND (see disagreement 1) |
| E-SRCH-10 | FC | Lily and Picard | ship has 24 decks, nearly 700 m long; Earth held by a forcefield | FOUND |
| E-SRCH-11 | FC | bridge | Borg turn the deflector dish into an interplexing beacon; deflector control and shuttles unreachable; the dish carries antiprotons, firing at it could destroy half the ship | FOUND |
| E-SRCH-12 | FC | hull EVA | three maglocks released; beacon destroyed by phaser rifle | maglocks FOUND; EVA details single reading |
| E-SRCH-13 | FC | Daniels | Borg overran three checkpoints, took decks 5 and 6, adapted to every weapon modulation | FOUND |
| E-SRCH-14 | FC | auto-destruct | three officers authorise; 15-minute silent countdown; Borg Queen has it deactivated | FOUND |
| E-SRCH-15 | FC | engineering, Queen | quantum torpedoes locked on the Phoenix; plasma coolant conduit broken, engineering floods (stage direction) | lock FOUND; count and flooding single reading |
| E-SRCH-16 | FC | beacon | no dialogue states dish power or signal band | not stated |
| E-SRCH-17 | INS | Briar Patch chase | shields at 60%; manifolds cannot handle full impulse in the Patch; engineering burning deuterium | FOUND |
| E-SRCH-18 | INS | subspace tear | core pulls the tear; options eject or detonate the core; impact in 15 then 10 s; core ejected then detonated; "fresh out of warp cores" | FOUND |
| E-SRCH-19 | INS | after the tear | transceiver assembly down for sending; Son'a ships 18 min away; 36 min to transmission range | FOUND (extra hour single reading) |
| E-SRCH-20 | INS | ramscoop manoeuvre | metreon gas collected; storage cells at maximum; helm to manual; ramscoop blown out | FOUND |
| E-SRCH-21 | INS | metaphasic radiation | rings regenerate genetic structure; effect on a child at maturity; extreme flux near the rings; collection starts a thermolytic reaction that leaves the planet uninhabitable; particles throughout the Briar Patch | FOUND (crew-effect lines single reading) |
| E-SRCH-22 | INS | same | no line states any effect on ship systems, exposure limits or controls aboard the -E | not stated |
| E-SRCH-23 | NEM | Scimitar decloaks | enemy: 52 disruptor banks, 27 torpedo bays, two shield sets (not the -E); Riker orders shields up | FOUND |
| E-SRCH-24 | NEM | Bassen Rift ambush | first shot hit the warp drive, impulse only | FOUND (warp-core stage direction single reading) |
| E-SRCH-25 | NEM | fight | dorsal shields lost; aft shields to 40%, auxiliary power to forward shields; forward shields to 10% | FOUND |
| E-SRCH-26 | NEM | after help | structural integrity lost on decks 12 to 17, sections 4 to 10; emergency forcefields hold; field power rerouted to forward shields | FOUND |
| E-SRCH-27 | NEM | boarding | ventral shielding lost on deck 29; security to deck 29 | FOUND (see disagreement 2) |
| E-SRCH-28 | NEM | bridge hit | bridge breach sealed by a forcefield (stage direction only) | single reading |
| E-SRCH-29 | NEM | before the ram | photon torpedo complement exhausted; phasers at 4%; Scimitar shields at 70% | FOUND |
| E-SRCH-30 | NEM | the ram | all power to engines, from life support if needed; brace for impact | order FOUND; collision details single reading |
| E-SRCH-31 | NEM | aftermath | auto-destruct omega off-line; transporters down; targeting sequence about seven minutes; warp engines ready later (time not stated) | FOUND |
| E-SRCH-32 | NEM | early scenes | warp five, warp eight, maximum warp courses; forcefield initiated by engineering | FOUND |
| E-SRCH-33 | FC, INS, NEM | alerts | red alert called (FC, INS); battle stations only (NEM); green and yellow not stated | red FOUND; rest not stated |
| E-SRCH-34 | FC, INS, NEM | armour, life support, gravity, EPS | regenerative or ablative armour not stated; EPS only "maybe EPS conduits"; artificial gravity not stated | not stated |

Not stated in any dialogue read: warp core status or manual override procedure; per-deck Borg timings; deflector
signal frequency or power; torpedo count; armour behaviour; -E phaser bank or tube counts; repair times; life-support
and EPS numbers; any effect of metaphasic radiation on the ship. Visual-only facts (engineering layout, the dish
and beacon, the bridge breach, on-screen displays) cannot be confirmed from transcripts and need a real viewing.
Star Trek: Picard season 3 shows the -E again; it was not read and is a possible later source only.

## 3. Scenario coverage

| scenario | covered by canon | not stated | buildable now |
|---|---|---|---|
| Borg assimilation of the ship (FC) | deck 16 first, sealing, control rerouted through main engineering, computer lock-out, decks 26 to 11, deck 11 contents, decks 5 and 6, checkpoints, 12-shot phaser limit, manual door release, beacon on the dish, auto-destruct with 15-minute countdown | warp core status and manual override, per-deck takeover times, deflector power, EPS route, life support numbers, torpedo count, the deck count (see disagreement 1) | no |
| metaphasic radiation (INS) | effects on people and planet; Briar Patch ship facts (shields 60%, manifold limit, deuterium, core eject) | any effect on ship systems, exposure limits, controls | no |
| Scimitar battle damage (NEM) | warp drive hit, impulse only, shield percentages, power rerouting, decks 12 to 17, deck 29, torpedoes exhausted, phasers 4%, ram, transporters down | armour, bank and tube counts, hit count, repair times, EPS, impulse and life-support state | no |

The stop rule applies: each scenario needs a ship component graph (core, EPS, impulse, shields, deflector,
weapons, life support, damage control) and no count, layout or rating of any of them is covered by a readable source.

## 4. Disagreements (recorded, none picked; owner decides)

1. FC: Daniels says Borg control spans decks 26 up to 11 while Picard says the ship has 24 decks (both lines in both readings).
2. FC (24 decks) against NEM (ventral shielding lost on deck 29, damage on decks 12 to 17): not reconciled.
3. FC and NEM draft shooting scripts differ strongly from the aired dialogue and were not used.

## 5. Acquisition list (to unblock the 1701-E)

1. Haynes *Enterprise Owners' Workshop Manual*: the only listed book for the -E, plausible for nine of the ten system groups above (all but possibly fuel). Supply the 1701-E section (cutaway, systems overview, defences, deflectors, computers, crew facilities, engineering) and the contents page, as text or PDF. The same book also serves the 1701-A.
2. A Star Trek Encyclopedia (state the edition) entries for the Sovereign class, quantum torpedo and alert conditions, for cross-checking.
3. For the on-screen items, a real viewing (disc or streaming) of FC, INS and NEM, noting timestamps for the scenes in section 2; optionally Picard season 3 if the warp core or its restart is needed.

Values no book plausibly covers (they need the owner's written design decision, recorded as a game-design
decision, never an estimate): ablative or regenerative shield behaviour; the warp core manual-override procedure and
timings; any effect of metaphasic radiation on ship systems; numeric outputs; the structure choice (which -D runtime
parts the -E may reuse: only where an -E source says so, otherwise the owner decides per system).

Systems each scenario needs: Borg scenario: main engineering and warp core, computer, deflector dish, shields,
phasers, quantum torpedoes, life support, decks and doors; metaphasic scenario: shields, sensors, life support,
EPS, warp core and impulse; Scimitar scenario: shields and their power rerouting, phasers, torpedoes, warp and
impulse, structural integrity, damage control, life support.
