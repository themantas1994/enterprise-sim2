# ADR 0003: NCC-1701-A component ids, panel contract and what is held

Status: partly accepted, 2026-11-26 (Phase 4). Builds on ADR 0001 (engine, SimHost, snapshot, commands) and ADR 0002
(component rules, `ShipRuntime`, `ScenarioBase`, test sizes). If this file and ADR 0001/0002 or the code
disagree on a mechanic, those and the code win; report the conflict in two lines and amend this file.

## Why most of this contract is held

Phase 4 uses the source rule in `docs/sources.md` (Rules): a Star Trek value is used only once it is found and
confirmed canon in an official source. The 1701-A source gate (R1) could read none of the three books
(*Mr. Scott's Guide to the Enterprise*, the Eaglemoss/Hero Collector Illustrated Handbook, the Haynes manual):
the only copies found are lending-restricted (HTTP 401) or not online, and StarTrek.com has no text pages.
Nothing was bypassed. The ledger therefore holds film-scene rows (`A-SCN1-*`, `A-SCN2-*`, `A-SCN3-*`, `A-PHAS-*`,
`A-SHLD-*`, `A-IMP-*`, `A-TORP-*`, `A-NAVD-*`, `A-PWR-*`, `A-MODE-*`, `A-WARP-001..003`) and platform rows
(`ENG-FONT-006..008`, `ENG-GODOT-019..022`), but no layout, count, deck or rating for any ship system.

Consequence: no component id, count, deck, topology or rating of the 1701-A is defined here. Inventing them
would put unconfirmed Star Trek facts into the ship data. They are defined in an amendment of this file once a
readable copy of the books is supplied.

## What is covered (usable now)

| topic | ledger | usable as |
|---|---|---|
| phaser power runs through the main engines and is cut off in an anti-matter imbalance | A-PHAS-001, A-PHAS-002 | scenario/system rule: warp-reactor trouble removes phaser power |
| impulse during the imbalance | A-IMP-001, A-IMP-002 | no primary support that impulse is lost with the reactor; the impulse half of the project rule is NOT confirmed |
| intermix, imbalance as the cause of the wormhole; timings of the wormhole sequence | A-WARP-001, A-SCN1-001..008 | scenario 1 events and film timings (scenario thresholds stay game tuning) |
| radiation, 3-minute window, entry into the reactor room, mains back online | A-SCN2-001..005 | scenario 2 events; the restart steps are not spoken, so the steps are game design |
| battle damage state after the first Reliant attack | A-SCN3-001..004 | scenario 3 events |
| shield lower and re-raise time 15.5 s | A-SHLD-004 | one confirmed shield timing |
| alert sequences (yellow, red, shields up) | A-MODE-001..003 | sequences only; no stated per-alert power rule, no green alert line |
| font: Exo 2, OFL 1.1, pinned commit and SHA-256 | ENG-FONT-006..008 | film-era kit font |
| CRT shader features on Compatibility | ENG-GODOT-019..022 | CRT/scanline shader |

TMP, TWOK and TSFS rows describe the refit NCC-1701; that the -A carries the same design is a project assumption
(recorded in each row). TFF and TUC rows are the -A.

## Held (no confirmed canon; blocked until a readable book copy is supplied)

Warp reactor layout, intermix chamber and shaft, injectors, dilithium frame role, output, nacelle and conduit
counts, reactor states and procedures (W1..W6, W8); impulse engine count, location and output (I1, I3); phaser bank
count, locations and output (P1, P3); torpedo tube count and stowage (P4); shield layout, facings and output
(S1, S3); navigational deflector location and rating (S4); deuterium and antimatter storage and dilithium reserve
(F1, F2, F4); emergency battery capacity (F3); life support and gravity (L1); damage control parties (L2); green
alert rule (M1). Panels, component ids and ship systems for these are held with them. No `estimate` row stands in
for any of them.

## Held contract parts (to be written on unblock)

- Component id table and per-panel read lists (panels per PLAN section 4 for the 1701-A: engine room status
  board, intermix chamber, fuel, power transfer board, impulse, deflector screens, navigational deflector, weapons
  power, life support, damage control).
- `ShipRuntime` interface: the contract of ADR 0002 stays valid (`create`, `step`, `snapshot`, `send`,
  `start_scenario`, `scenario_ids`; `ship.alert`, `ship.mode`, `ship.scenario`). The 1701-A runtime sits beside the
  1701-D one in `sim/systems`, with the same public interface; SimHost gets a ship choice when it exists.
- Scenario ids: `intermix_imbalance`, `manual_restart`, `battle_damage` (classes in `sim/scenarios`). Each must be
  winnable and losable by scripted commands and by panel buttons. No raw repair, damage or add_heat for players;
  starting a scenario resets the ship; every float command rejects NaN and inf.

## Film-era kit (not held: it uses no ship values)

`ui/themes/tmp/` holds the film-era widget kit: a `WidgetKit` subclass (`TmpKit`) returning the era's widgets in
the same method set as `TngKit` (button, gauge, frame, readout, schematic, alert banner, slider, caption), colour
tokens, a theme, the Exo 2 font (Regular and Bold) with its OFL text and notice, and a CRT shader.

- Look (PLAN section 5): dark grey/brown hardware panels, rectangular backlit push-buttons with coloured legends
  (red, amber, blue, green, white) that look pressed, indicator lamps, CRT line art in green or blue with scanlines,
  glow and flicker. Original artwork only; no screen graphics.
- Font: Exo 2 only (ENG-FONT-006..008), fetched from the pinned commit with its checksum checked (same method as
  the Antonio font); the licence file and a notice ship next to the font.
- CRT shader: a `canvas_item` shader using only features that ENG-GODOT-019..022 confirm on the Compatibility
  renderer (screen-texture read, SCREEN_UV, TIME, FRAGCOORD); no values above 1.0 are relied on (RGBA8, no 2D HDR);
  uniforms for scanline period, strength, glow, flicker and a reduced-motion switch (flicker off). It must run
  headless without errors and be drawn correctly under `--rendering-method gl_compatibility`.
- Touch targets at least 48 dp (ENG-ANDROID-001); captions never truncated and no text under the size floor at
  1280x720 and at the phone size below; panels, when they exist, write only through `SimHost.send(cmd)`.

## Test and screenshot sizes

Same as ADR 0002: desktop 1280x720 px; 6-inch phone landscape 2160x1080 px at about 402 dpi (864x432 dp, density
2.5), touch targets 120 px at that density.

## Paths

| owner | paths |
|---|---|
| ship data and systems (held) | `ships/`, `sim/systems/`, `sim/scenarios/`, `tests/systems/`, `tests/scenarios/` |
| UI (kit now, panels later) | `ui/`, `tests/ui/` |
| shared, main session only | `docs/`, `scripts/`, `.github/`, `sim/core/` (changed only for a generic gap, with tests) |
