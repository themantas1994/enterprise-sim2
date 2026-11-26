# ADR 0002: NCC-1701-D component ids and panel contract

Status: accepted for Phase 3, 2026-11-25. Builds on ADR 0001 (engine, SimHost, snapshot and commands).
If this file and ADR 0001 or `sim/core/sim.gd` disagree on a mechanic, ADR 0001 and the code win; report the
conflict in two lines instead of diverging silently, and this file is amended.

## Rules

- Ids are lower-case snake_case, `[a-z0-9_]` only, unique across the ship file. Ship data assigns them; panels
  never invent ids. A panel reads only the ids listed for it in the ship file's panel map and writes only
  through `SimHost.send(cmd)`.
- Units: one convention in the ship file, power in **MW** (`"power_unit": "MW"`). Canon values given in other
  units are converted in the file with the ledger id cited. Canon-scale figures that do not fit a playable
  grid (for example D-IMP-003, D-SHLD-016, D-NAVD-009) are not used as live values.
- Source gate: every Star Trek value carries a ledger id from `docs/sources.md`. Game tuning (heat rates, leak
  rates, countdown lengths, scenario thresholds, repair times, conduit capacities, shield facings) is marked
  `estimate` with a one-line reason, citing the estimate row where one exists (D-EPS-002, D-CORE-004,
  D-CORE-005, D-COOL-003, D-DMG-001). D-IMP-004 is unverified and is not used.
- Counts below come from the ledger. Derived values cite both source ids (for example one SIF generator is
  20 sources x 12 MW from D-SIF-003 and D-SIF-004).
- Panel map: `ships/1701d.json` carries a `panels` object, `panel_id -> { "title", "components": [ids] }`.
  Check the loader schema first; if it rejects an unknown section and `sim/core` must not change, ship the map
  as `ships/1701d_panels.json` with the same rules and report it.

## Component ids

| group | ids | ledger |
|---|---|---|
| warp core | `warp_core`; `warp_injector_matter_1`..`_6`; `warp_injector_antimatter_1`..`_3`; `warp_constrictor_upper`, `warp_constrictor_lower`; `warp_dilithium_frame`; `warp_nacelle_port`, `warp_nacelle_stbd` | D-WARP-001..020, D-NAC-001..010, D-SAFE-001..005, D-CORE-004 |
| coolant | `coolant_core`, `coolant_eps` (stores; leak is a fault on them) | D-COOL-001..003 |
| fuel | `antimatter_pod_01`..`_30`; `deuterium_tank_main`; `deuterium_aux_saucer`; `antimatter_generator` | D-FUEL-001..014, D-IMP-005 |
| EPS sources | `warp_core`; `impulse_main`; `impulse_saucer_1`, `impulse_saucer_2`; `aux_fusion_1`, `aux_fusion_2`; `battery_emergency` | D-EPS-001, D-IMP-001, -002, -009, -010 |
| EPS conduits | `eps_trunk_a`, `eps_trunk_b`, `eps_cross_link`, `eps_sub_saucer`, `eps_sub_engineering`, `eps_sub_nacelle`, `eps_sub_weapons` | D-EPS-001..003, D-PHAS-002, D-WARP-016 |
| impulse | `impulse_main`, `impulse_saucer_1`, `impulse_saucer_2`, `aux_fusion_1`, `aux_fusion_2`, `impulse_drive` (consumer: thrust) | D-IMP-001..010 (not -004) |
| shields | `shield_grid` (control: frequency, modulation, facing weights); generators `shield_gen_p1`..`p5` (Deck 10), `shield_gen_s1`..`s3` (Deck 31), `shield_gen_np1`, `_np2`, `shield_gen_ns1`, `_ns2`; `shield_backup_primary`, `shield_backup_secondary` (4 units each) | D-SHLD-001..021, D-BORG-001..003 |
| SIF | `sif_grid`; `sif_gen_p1`..`p3` (Deck 11), `sif_gen_s1`, `_s2` (Deck 32); `sif_backup_primary`, `sif_backup_secondary` (2 units each) | D-SIF-001..018 |
| IDF | `idf_grid`; `idf_gen_p1`..`p4` (Deck 11), `idf_gen_e1`, `_e2` (Deck 33); `idf_backup_primary`, `idf_backup_secondary` (3 units each) | D-IDF-001..014 |
| other loads | `nav_deflector`, `phaser_array`, `life_support` (estimate), `computer_core_p1`, `computer_core_p2`, `computer_core_e1` | D-NAVD-*, D-PHAS-*, D-COMP-* |
| damage control | `dc_team_1`..`dc_team_4` | D-DMG-001 |

Topology requirements (the ship data owner decides the rest): both trunks can feed the main loads; `eps_cross_link` joins the
trunks so that a cut of one trunk leaves a path for essential loads; the saucer impulse reactors and the
auxiliary generators can power the saucer submaster alone. The core solver is a greedy priority allocator, not
a max-flow: if this graph needs better routing, report it; do not rewrite the solver.

## Panels

Panel ids are the keys of the panel map; the station menu shows them in this order.

| panel id | reads (ids) |
|---|---|
| `msd` | one tile per group: `warp_core`, `coolant_core`, `coolant_eps`, `deuterium_tank_main`, `antimatter_pod_*` (summary), `eps_trunk_a`, `eps_trunk_b`, `shield_grid`, `sif_grid`, `idf_grid`, `impulse_main`, `impulse_saucer_1`, `impulse_saucer_2`, `nav_deflector`, `phaser_array`, `life_support`, `computer_core_*`; the situation monitor lists every off-nominal id of the whole map |
| `warp_core` | `warp_core`, `warp_injector_*`, `warp_constrictor_*`, `warp_dilithium_frame`, `warp_nacelle_*`, `coolant_core` |
| `fuel` | `antimatter_pod_01`..`_30`, `deuterium_tank_main`, `deuterium_aux_saucer`, `antimatter_generator` |
| `eps` | EPS sources, EPS conduits, `battery_emergency`, `coolant_eps`, and the consumer ids `shield_grid`, `sif_grid`, `idf_grid`, `impulse_drive`, `nav_deflector`, `phaser_array`, `life_support`, `computer_core_*` |
| `shields` | `shield_grid`, `shield_gen_*`, `shield_backup_*` |
| `impulse` | `impulse_main`, `impulse_saucer_*`, `aux_fusion_*`, `impulse_drive`, `deuterium_tank_main`, `deuterium_aux_saucer` |
| `sif_idf` | `sif_grid`, `sif_gen_*`, `sif_backup_*`, `idf_grid`, `idf_gen_*`, `idf_backup_*` |
| `damage_control` | `dc_team_1`..`dc_team_4`, plus every damaged id of the map (repair queue) |

The commands each panel sends (power allocation, priorities, reactor start, eject, frequency and modulation,
team assignment) are the generic commands of `sim/core/sim.gd` plus any ship command added in
`sim/systems`; each is documented in the header of `sim/systems/ship_runtime.gd`.

## Runtime wrapper and scenario interface (built by the systems side, consumed by the UI)

`sim/systems/ship_runtime.gd`, class `ShipRuntime` (RefCounted), the only object the host talks to:

- `ShipRuntime.create(ship_path: String, seed: int) -> ShipRuntime` loads the ship file through the core
  loader and builds the systems.
- `step()` advances one fixed tick of the sim, the ship systems and the active scenario.
- `snapshot() -> Dictionary`: the core snapshot plus a `ship` entry: `alert` (`green`, `yellow`, `red`),
  `mode` (`cruise`, `yellow_alert`, `red_alert`, `reduced_power`), `scenario` (`id`, `title`, `status`,
  `reason`, `tick`, `time_left`; `{}` when none).
- `send(cmd: Dictionary) -> Dictionary` applies a command and returns the sim's result (accepted or rejected
  with a reason).
- `start_scenario(id: String)`, `scenario_ids() -> Array`.

`sim/scenarios/scenario_base.gd`, class `ScenarioBase` (RefCounted): constants `RUNNING = "running"`,
`WON = "won"`, `LOST = "lost"`; fields `id`, `title`, `brief`, `status`, `reason`; methods `setup(runtime)` and
`update(runtime)`, called once per tick until `status` leaves `running`, after which the status is final.
`sim/scenarios/scenario_registry.gd`: `ids()` and `create(id)`. One class per scenario:

| id | file | intent (details and thresholds belong to the systems author, all tuning marked `estimate`) |
|---|---|---|
| `core_breach` | `scenario_core_breach.gd` | containment fails; the player must eject, contain (forcefield) or stabilise before the countdown ends (D-SAFE-003, D-SAFE-004, D-ENG-007, D-CORE-001..005); lost on breach |
| `borg_drain` | `scenario_borg_drain.gd` | a cube drains shields and adapts to the frequency in use; the player rotates frequency and modulation, reroutes power and keeps the ship alive until the timer ends (D-BORG-001..003, D-SHLD-018, D-SHLD-019); lost when shields and power collapse. The drain of ship power itself is a gameplay invention (D-BORG-004, estimate) |
| `coolant_leak` | `scenario_coolant_leak.gd` | a leak in a core or EPS coolant loop raises heat; the player isolates the loop, reroutes, assigns damage teams and cools down before breach (D-COOL-001..003, D-CORE-001); lost on breach |

Each scenario must be winnable and losable by scripted commands alone, with the same seed giving the same run.

## Test and screenshot sizes

- Desktop: 1280x720 px.
- 6-inch phone landscape (project assumption, derived): 2160x1080 px at about 402 dpi, which is 864x432 dp
  (density 2.5). Touch targets at least 48 dp (ENG-ANDROID-001), that is 120 px at this density.
- Fonts: Antonio (fallback Oswald), OFL 1.1, bundled with its notice and licence text (ENG-FONT-001..005).

## Paths

| owner | paths |
|---|---|
| ship data and systems | `ships/`, `sim/systems/`, `sim/scenarios/`, `tests/systems/`, `tests/scenarios/` |
| UI | `ui/`, the `SimHost` autoload line in `project.godot`, `tests/ui/` |
| shared, main session only | `docs/`, `scripts/`, `.github/`, `sim/core/` (changed only for a generic gap, with tests) |
