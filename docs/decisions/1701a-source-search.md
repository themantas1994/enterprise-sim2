# NCC-1701-A source search (milestone 4, step 2)

Date: 2026-11-26. Status: complete for this session; result: no scenario has all its systems covered by a readable
source, so the 1701-A ship data, panels and scenarios stay held. This report adds no ledger rows. Ledger rows
(`A-<SYSTEM>-nnn`) are written only when a source has been read (docs/sources.md Rules).

Method: no copy of any book was supplied for this session. Books were looked up in publisher, library and
bookseller catalogues and on StarTrek.com (titles, editions, scope). Films were read through public dialogue
transcripts as a reading aid; no film was viewed and no legal viewing source gave timestamps, so every film row
says "film not viewed, no timestamp". A scene is FOUND only when two independent readings agree. Paraphrase only.
Memory Alpha was not used. Ids `A-SRCH-n` below are search ids, not ledger ids.

## 1. Books and official text

| # | title | edition / ISBN | how verified | access |
|---|---|---|---|---|
| 1 | *Mr. Scott's Guide to the Enterprise* (Shane Johnson), Pocket Books | 1987, 125 pp; ISBN-10 067163576X (Open Library) vs 0671704982 in other listings; 2003 Titan reissue 1852860286 (one listing). The ISBNs conflict: settle them from the copyright page of a supplied copy | Open Library, listings | not readable: Open Library shows it unavailable, no preview found |
| 2 | *Star Trek: The U.S.S. Enterprise NCC-1701 Illustrated Handbook* (Robinson, Riley, Hugo), Hero Collector (Eaglemoss) | 2019, 160 pp; ISBN-13 9781858755786 | bookseller listings (publisher page returned 404) | not readable: no preview, no contents list; seller text mentions isometric key locations, plan views, technical details |
| 3 | *U.S.S. Enterprise Owners' Workshop Manual* (Robinson, Riley; Okuda consultant), Haynes; subtitle "2151 onwards (NX-01, NCC-1701, NCC-1701-A to NCC-1701-E)" | UK 21 Oct 2010, 160 pp, ISBN-13 9781844259410; US ISBN-13 9781451621297 (listing only); eBook 9781451625264 | StarTrek.com article (scope), publisher and seller pages | not readable: no contents list or sample. StarTrek.com says each ship has a cutaway and systems overview. One publisher blurb lists fewer ships than the UK subtitle, so confirm the -A and -E sections from a copy |
| 4 | *Star Trek Encyclopedia* (Okuda, Okuda, Mirek); editions 1994, 1999 (ISBN-10 0671034758), 2016 (9780062371324) | as listed | listings only | not readable |
| 5 | *Star Trek Chronology* (Okuda, Okuda) | ISBN 0-671-53610-9, unconfirmed | secondary list | not readable, not verified |
| 6 | Franz Joseph, *Star Fleet Technical Manual* and blueprints (1975) | not verified | not searched | not readable; older layer only, not a source for the -A |
| 7 | StarTrek.com article about the Haynes manual (Oct 2010) | official page | fetched | readable; scope only, no ship values |
| 8 | StarTrek.com database page for the 1701-A | n/a | placeholder page ("Coming Soon") | no text |

No official film text commentary or magazine article for the -A could be identified as a verifiable title. Google
Books previews and WorldCat/Library of Congress were not reached (quota error), so a retry may still turn up a
legal preview. Values actually read from a book: none.

### Value groups and the books that plausibly state them (from catalogue scope only; nothing read)

P = plausible, ? = unknown without a contents list.

| held value group | Scott's Guide | Hero handbook | Haynes | notes |
|---|---|---|---|---|
| reactor layout, intermix chamber and shaft, injectors, dilithium frame role | P | P | P | |
| reactor output | ? | ? | ? | no listing mentions a number |
| nacelle and conduit counts | P | P | P | |
| reactor states and procedures (start, shutdown, emergency restart) | ? | n | n/? | probably on-screen only |
| impulse engine count, location, output | P | P | ? | |
| phaser bank count, locations, output | P | P | P | phaser power path is already confirmed on screen (A-PHAS-001) |
| torpedo tube count and stowage | P | P | P | |
| shield layout, facings, output | P | ? | P | |
| navigational deflector location and rating | P | P | P | |
| deuterium, antimatter storage, dilithium reserve | P | ? | ? | |
| emergency battery capacity | ? | ? | ? | possibly not covered |
| life support and gravity | P | ? | P | |
| damage control parties | ? | ? | ? | possibly not covered |
| green alert rule | ? | ? | ? | alert levels mostly on screen |
| does impulse lose power with the warp reactor in trouble | ? | ? | ? | no listing mentions it |

## 2. On-screen canon (new scenes only; the ledger's A-SCN*, A-PHAS, A-IMP, A-TORP, A-SHLD, A-NAVD, A-PWR, A-MODE, A-WARP rows are not repeated)

Readings: CH = chakoteya.net film transcript (base); SS = springfieldspringfield.co.uk subtitle transcript (second
reading for TSFS, TFF, TUC). Draft shooting scripts differ from the aired dialogue and count as a second reading
only where a line matches CH word for word. StarTrek.com film pages hold one-sentence synopses only. TMP's CH
transcript is the Director's Edition, so most TMP rows are single readings. TMP, TWOK and TSFS show the refit NCC-1701,
not the -A (that the -A carries the same design stays a project assumption); TFF and TUC show the -A; TVH shows no
1701 system in dialogue.

| id | film | scene | what it states | status |
|---|---|---|---|---|
| A-SRCH-1 | TMP | tractor beam before the V'Ger iris | ship has a fraction of the power needed to break free; 15 s before burn-up (Scott); main drive and navigation relays disengaged | single reading |
| A-SRCH-2 | TMP | same | forcefield circuits E-10 to E-14 ready for reactivation; meaning of the numbering not stated | single reading |
| A-SRCH-3 | TMP | self-destruct order | Kirk readies Starfleet order 2005; Scott says matter and anti-matter together would take the intruder with them | exchange FOUND; "2005" single reading |
| A-SRCH-4 | TMP | all-decks readout | 172 at stations, 248 off duty, 11 in sickbay | single reading |
| A-SRCH-5 | TMP | inside V'Ger | deck four temperature should read 1013 (unit not stated) | single reading |
| A-SRCH-6 | TMP | alerts | red-alert klaxon; computer "Intruder Alert"; no alert-level rule | intruder alert FOUND; klaxon single reading |
| A-SRCH-7 | TMP | pre-launch checks | space matrix restoration coils, dilithium crystals, faulty modules called out; no counts | single reading |
| A-SRCH-8 | TMP | early | engines not yet tested at warp power; crew lacks transition time with the new equipment | single reading |
| A-SRCH-9 | TWOK | Kobayashi Maru simulation | simulated: energiser hit, auxiliary power, shields collapse, phasers get no power. Training simulation, not the ship's real state | FOUND (as simulation) |
| A-SRCH-10 | TWOK | training cruise | out of dock on quarter impulse; later warp five | FOUND |
| A-SRCH-11 | TWOK | Mutara Nebula entry | static clouds the tactical display; shields useless there; energiser bypassed, Scott cannot take many bumps | FOUND |
| A-SRCH-12 | TWOK | nebula battle, second pass | full stop, Z minus 10,000 m, torpedoes ready, two fired; no tube or torpedo count | FOUND |
| A-SRCH-13 | TWOK | after the nebula fight | systems inoperative below C-deck; partial main power after two hours | FOUND |
| A-SRCH-14 | TWOK | reactor room (draft script directions only) | glass-walled reactor compartment, damping rods, manual control, "ten minutes" until radiation clears: draft only, not in the aired dialogue read | single reading (draft) |
| A-SRCH-15 | TSFS | Scott on automation | ship fully automated by docking; a chimpanzee and two trainees could run her (ties to A-SHLD-003, A-PHAS-003) | FOUND |
| A-SRCH-16 | TSFS | Chekov's energy reading | source is C deck, inside Spock's quarters | FOUND |
| A-SRCH-17 | TSFS | theft from Spacedock | yellow alert, moorings automatic, warp drive standing by, full impulse then warp | FOUND |
| A-SRCH-18 | TSFS | destruct sequence | three officers give codes in turn, then a one-minute countdown | sequence FOUND; audible count single reading |
| A-SRCH-19 | TVH | Klingon Bird of Prey (not the 1701) | generic dilithium behaviour (de-crystallising, cannot be re-crystallised, photons proposed) on a Klingon ship | FOUND, not a 1701-A fact |
| A-SRCH-21 | TFF (-A) | shakedown | engine fine but half the doors fail; transporter inoperative; turbolift doors fail | FOUND |
| A-SRCH-22 | TFF (-A) | Sybok takes the ship | warp 7; 6.7 hours at present speed | FOUND |
| A-SRCH-23 | TFF (-A) | brig escape | turboshaft three closed for repair; emergency sender in the forward observation room | FOUND (level 13 single reading) |
| A-SRCH-24 | TFF (-A) | Galileo docking | manual flight without the tractor beam; shields lowered on Kirk's call | FOUND |
| A-SRCH-25 | TFF (-A) | after Sha Ka Ree | instruments back online; torpedo armed and fired; transporter at partial power takes two | FOUND |
| A-SRCH-26 | TUC (-A) | Gorkon rendezvous | shields raise asked; two torpedoes hit Gorkon's ship after the bridge queries the torpedo room | FOUND |
| A-SRCH-27 | TUC (-A) | Khitomer battle | half impulse; third torpedo -> auxiliary power -> auxiliary circuits destroyed (A-PWR-002); shields weaken then collapse; hull compromised; no hit count in dialogue | FOUND |
| A-SRCH-28 | TUC (-A) | torpedo bay | Spock and McCoy hand-modify a torpedo, fired on Kirk's order | FOUND |
| A-SRCH-29 | TUC (-A) | range countdowns | transporter range in 57 s counting down; distance readings 209, 206, 203, then 158 | FOUND |
| A-SRCH-30 | TUC (-A) | Valeris | no one can fire an unauthorised phaser aboard a starship | FOUND |

Not stated in any dialogue read: green alert and any alert-level rule (red and yellow alerts are called, no rule);
gravity; life support (only the simulation voice in A-SRCH-9); battery capacity beyond the ledger rows; reactor
chamber values; counts of torpedoes, tubes or phaser banks; the warp-feed rule outside TMP. Visual-only facts
(reactor room, engine room layout, displays) cannot be confirmed from transcripts and need a real viewing.

## 3. Scenario coverage (what the scenes state, what they do not)

| scenario | covered by canon | not stated (needs a book or a written design decision) | buildable now |
|---|---|---|---|
| intermix imbalance (TMP wormhole) | intermix set, warp 0.7 to 1, phasers cut off in the imbalance (A-PHAS-001), torpedoes used instead, navigational deflectors and helm lost (A-NAVD-001), repair in under three hours | reactor and chamber layout, ratios, flows, timings inside the chamber, dilithium role, impulse engines (count, output), torpedo tubes, deflector location and rating | no |
| emergency manual restart (TWOK) | mains taken off the line for radiation, reactor-room entry, mains back online (A-SCN2-*) | any restart steps, reactor layout, fuel, coolant, control rods (visual or draft only), battery capacity | no |
| battle damage with warp-fed phasers | batteries and auxiliary power, shields lost, automation centre knocked out, auxiliary circuits destroyed, hull compromised; phaser power through the main engines (A-PHAS-001) | battery capacity, shot and torpedo counts, bank and tube counts, shield layout and output, the impulse half of the rule | no |

The stop rule applies: every scenario needs a ship component graph (reactor, impulse, phasers, torpedoes,
shields, deflector, batteries) and no count, layout or rating of any of them is covered by a readable source.
Building them on `estimate` values is not allowed for Star Trek facts.

## 4. Disagreements between sources (recorded, none picked; owner decides)

- TUC: one reading has impulse power "for Khitomer only", the other "for Khitomer orbit".
- TWOK: a draft script has a ten-minute radiation figure and a shaken-loose energiser; the transcript read does not.
- TSFS: the audible nine-to-one countdown appears in one reading only; a draft script shows a 1:59 display.
- TMP: transcript is the Director's Edition; the draft script lacks the 172/248/11 count, deck four 1013, circuits E-10 to E-14 and order 2005.
- ISBN conflict for *Mr. Scott's Guide* (see table).

## 5. Acquisition list (to unblock the 1701-A)

Ranked by how many held value groups the source plausibly covers (plausibility from catalogue scope; no contents
list was visible for any book, so nothing here is confirmed):

1. *Mr. Scott's Guide to the Enterprise*: plausible for 9 of 14 groups (layout, nacelles and conduits, impulse, phasers, torpedoes, shields, navigational deflector, fuel and dilithium, life support and gravity). Supply the engineering chapters (or the whole 125 pages) as text or PDF, plus the copyright page for the ISBN.
2. Haynes *Enterprise Owners' Workshop Manual*: plausible for 7 of 14 and the only listed source for the 1701-E as well, so it also serves milestone 5. Supply the 1701 and 1701-A sections (cutaway, systems overview) and the contents page.
3. Hero Collector *Illustrated Handbook* (1701 and 1701-A): plausible for 6 of 14. Supply the technical details, key locations and plan-view sections for engineering, impulse, weapons and defences.

Values no book plausibly covers (they need the owner's written design decision, recorded as a game-design decision,
never as a Star Trek fact or an estimate): the manual-restart procedure steps and timings; whether impulse loses
power with the warp reactor (the phaser half is confirmed on screen); numeric outputs (MW) of reactor, impulse,
phasers and shields; emergency battery capacity; damage-control party counts. The game-scale numbers these
scenarios need (heat rates, countdowns, thresholds, repair times) remain separate tuning rows.

Systems each scenario needs, for the order of work once a source is supplied: intermix scenario: warp reactor and
intermix chamber, impulse, phasers, torpedoes, navigational deflector, alert; restart scenario: reactor room and
mains, auxiliary power and batteries, radiation, life support; battle scenario: shields, phasers, torpedoes, batteries
and auxiliary power, damage control, impulse.
