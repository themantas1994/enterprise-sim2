# 0001: Engine and language

Status: accepted 2026-11-25, provisional on the skeleton checks below. Inputs: `engine-facts.md`
(cited by ENG id) and `PLAN.md`. Facts marked "not verified" in the sheet are treated as unknown.

## Decision
**Godot 4.7.2 (stable, ENG-GODOT-001), GDScript, one project exported to Windows, Linux and Android.**
1. Three targets: one project, Android down to 7.0 on the Compatibility renderer or 9.0 on Vulkan
   (ENG-GODOT-003). Android CI prerequisites are documented exactly (ENG-GODOT-004). The only candidate
   whose Android toolchain and minimum versions are documented in full.
2. Headless core: `--headless` runs without a GPU and exports from the CLI (ENG-GODOT-006).
3. 2D shaders: `canvas_item` shaders with `fragment()` (ENG-GODOT-009); audio buses (ENG-GODOT-010).
4. Maintenance: MIT, no fees, no seat licence (ENG-GODOT-002); one language for sim and UI.
5. Build size: unknown for every candidate (ENG-GODOT-011, FLUTTER-007, UNITY-008, RUST-009); it does
   not separate them. The skeleton CI records artifact sizes.
- Rendering method: **Compatibility** (OpenGL ES 3.0, Android 7.0+), as the panels are 2D only.
  Fallback: Mobile (Vulkan 1.0, Android 9.0+), if check C2 fails.
- Test framework: **GdUnit4** (MIT, CLI runner, JUnit XML, GitHub action; ENG-GODOT-007). PLAN.md
  names GUT, but the sheet has no GUT facts, so GUT is unknown. PLAN.md sections 2, 7 and 9 need updating.

## Pinned versions for the skeleton
- Godot editor and export templates: 4.7.2, same version for both (ENG-GODOT-001, ENG-GODOT-005).
- GdUnit4: the newest release whose compatibility table lists Godot 4.7.2 (v7.0.0 line per
  ENG-GODOT-007; release number not verified). If none lists 4.7.2, see check C1.
- Android (ENG-GODOT-004): OpenJDK 17; SDK Platform 35; Build-Tools 35.0.1; Platform-Tools 35.0.0;
  Command-line Tools latest; CMake 3.10.2.4988404; NDK r28b (28.1.13356709). Debug APK without the
  Gradle build; Gradle only later for the `.aab`.

## Unknowns that affect the decision (close them in the skeleton task)
- C1 GdUnit4 on 4.7.2: ENG-GODOT-007 lists 4.7 and 4.7.1 only. Check: one trivial test via the GdUnit4
  CLI under `--headless` on 4.7.2. If it fails, pin Godot 4.7.1 (listed for v6.2.x and v7.0.0).
- C2 Shaders on Compatibility: parity with Vulkan not on the sheet. Check: the empty panel draws a
  scanline `canvas_item` shader; screenshot on Linux, Windows and the Android emulator.
- C3 `_draw()` custom drawing: not verified (ENG-GODOT-009). Check: same panel draws lines and rects in
  `_draw()`. Fallback: shader-only or Line2D/Polygon2D drawing.
- C4 Debug keystore in CLI export: not verified (ENG-GODOT-004). Check: CI export without the
  `GODOT_ANDROID_KEYSTORE_DEBUG_*` vars; if it fails, create one with `keytool` in CI and set them.
- C5 CI workflow: not vendor-documented (ENG-GODOT-008). Check: the skeleton job itself, step by step.
- C6 Build size: record `.exe`, Linux binary and `.apk` sizes from the first CI run.
If C2 and C3 both fail, revisit this record before Phase 2.

## Rejected
- Flutter: custom painting, shaders and audio all not verified (ENG-FLUTTER-006), so criterion 3 is
  unknown; strong only on headless tests (ENG-FLUTTER-005).
- Unity: Linux editor, CI batch build, licence activation and test framework not verified
  (ENG-UNITY-003, -005, -006); no Android emulator support (ENG-UNITY-003) conflicts with the Phase 1
  emulator smoke test; revenue cap and price changes (ENG-UNITY-002).
- Bevy (Rust): Android toolchain and min API not verified (ENG-RUST-004, -006), headless test recipe
  not verified (ENG-RUST-007), pre-1.0 breaking releases (ENG-RUST-002).
- egui: widget toolkit, not a game engine (ENG-RUST-001).
- Godot with C#: PLAN.md section 2 (less mature Android support); GDScript avoids a second toolchain.

## Consequences
- PLAN.md sections 4, 5 and 7 stand as written (scenes, `Theme`, `project.godot`, `export_presets.cfg`).
- Every engine upgrade moves editor, templates and GdUnit4 together; templates match the editor.
- CI must install JDK, Android SDK packages, editor and templates (ENG-GODOT-008), so CI setup is ours.

## Sim/UI interface sketch (PLAN.md sections 3, 4, 7)
- `sim/` classes extend `RefCounted` or `Resource`, never `Node`. No `Control`, `CanvasItem`, `Input`,
  `get_tree()`, autoloads or `Time` in `sim/`. A CI grep fails the build on any of these.
- `Sim.new(ship_data: Dictionary, seed: int)`; one `RandomNumberGenerator` seeded from `seed`, never
  global `randi()`. Time is an integer `tick` (10 Hz, 0.1 s per tick); no wall clock.
- `sim.submit(cmd: Dictionary)` queues e.g. `{type="set_allocation", target="shields", value=0.8}`.
  `sim.step()` applies the queue in arrival order, then advances one tick. Seed plus the command log
  replays a run exactly. Invalid commands are rejected and reported as events, never thrown.
- `sim.snapshot() -> Dictionary`: a deep copy, `{tick, alert, mode, components: {id: {state, power,
  temp, integrity, ...}}, events: [...]}`. Panels never hold references to live sim objects.
- `ui/sim_host.gd` (autoload Node, UI side): owns the `Sim`, accumulates frame delta, calls `step()`
  every 0.1 s, emits `snapshot_ready(snap, prev)`. Panels connect to it, read only the component ids the
  ship data assigns them, may interpolate `prev` to `snap`, and write only through `SimHost.send(cmd)`.
- Tests (GdUnit4) build `Sim` directly with no SimHost and no scene tree: submit commands, step N
  ticks, assert on snapshots; same seed and commands give identical snapshots (same-platform claim;
  cross-platform float determinism is not claimed).
