# Engine fact sheet (R2)

Researched 2026-11-25. Facts only: no recommendation, no ranking. Each fact has an id for the source
ledger. "not verified" = no vendor page found in this pass; do not rely on it. Vendor docs were fetched
live from the `stable`/`current` channel; the version shown is what the page itself reported.

Candidates: Godot 4 (GDScript), Flutter, Unity, and Bevy (Rust option; egui rejected, see ENG-RUST-001).

## 1. Version, licence, cost

| Id | Candidate | Fact | Source |
|---|---|---|---|
| ENG-GODOT-001 | Godot | Latest stable 4.7.2 (18 Aug 2026); 4.8 is beta5 (24 Nov 2026). | godotengine.org/download/archive/ |
| ENG-GODOT-002 | Godot | MIT licence; free for any purpose incl. commercial. | docs.godotengine.org/en/stable/about/faq.html (4.7) |
| ENG-FLUTTER-001 | Flutter | Latest stable 3.50.1, Dart 3.14.0 (20 Nov 2026). Docs describe Flutter 3.50. | storage.googleapis.com/flutter_infra_release/releases/releases_linux.json (the data behind docs.flutter.dev/install/archive); docs.flutter.dev/release/archive |
| ENG-FLUTTER-002 | Flutter | BSD 3-Clause licence, "Copyright 2014 The Flutter Authors". | github.com/flutter/flutter LICENSE (master) |
| ENG-UNITY-001 | Unity | Current docs are Unity 6.6 (6000.6); page also mentions Unity 6.7 LTS. Exact latest patch: not verified. | docs.unity.com/en-us/engine/current/manual/platform-specific/android/introducing/requirements-and-compatibility |
| ENG-UNITY-002 | Unity | Personal tier for up to $200,000 revenue and funding; Pro $2,310 per seat per year (rising 5% from 12 Jan 2026, so the current price is not verified); splash screen optional in Unity 6; runtime fee cancelled. | unity.com/products/pricing-updates |
| ENG-RUST-001 | Rust | Pick Bevy over egui: Bevy is a 2D/3D game engine (ECS, renderer, audio, input), while egui is an immediate-mode widget GUI toolkit that needs eframe for a window. Needs a human check on fit. | docs.rs/crate/bevy/latest; github.com/emilk/egui |
| ENG-RUST-002 | Bevy | Latest 0.20.1 (28 Oct 2026); MIT or Apache-2.0 dual licence; free. MSRV "generally close to the latest stable Rust". Pre-1.0: breaking changes per release (inference, not stated on the page). | docs.rs/crate/bevy/latest |
| ENG-RUST-003 | egui | eframe 0.37.0 (15 Oct 2026, crates.io registry); MIT or Apache-2.0; backends egui-wgpu or egui_glow. | crates.io/api/v1/crates/eframe; github.com/emilk/egui |

## 2. Android export and platform support

| Id | Candidate | Fact | Source |
|---|---|---|---|
| ENG-GODOT-003 | Godot | Exported games need Android 9.0 (Forward+/Mobile, Vulkan 1.0) or Android 7.0 (Compatibility, OpenGL ES 3.0); ARM and x86, 32/64-bit; 1 GB RAM; 150 MB storage. | docs.godotengine.org/en/stable/about/system_requirements.html (4.7) |
| ENG-FLUTTER-003 | Flutter | Android API 24 to 37 supported (x64, Arm32, Arm64; the page does not label the numbers as API levels, inferred); Windows 10 and 11 (x64, Arm64); Debian 10 to 13, Ubuntu 20.04 to 24.04 LTS (x64, Arm64). | docs.flutter.dev/reference/supported-platforms |
| ENG-UNITY-003 | Unity | Android min API 26 (Android 8.0); target API 35 or 36; Vulkan, OpenGL ES 3.1 minimum; URP supported, HDRP not; emulators not supported; 16 KB page-size devices supported. Editor on Linux: not verified. | docs.unity.com/en-us/engine/current/manual/platform-specific/android/introducing/requirements-and-compatibility (6000.6) |
| ENG-RUST-004 | Bevy | Android support, min API, build tooling (cargo-ndk or similar): not verified (repo example page could not be read). | github.com/bevyengine/bevy/tree/main/examples/mobile (listing only) |
| ENG-RUST-005 | egui | eframe is stated to support Android, Web, Linux, Mac, Windows; no setup steps given. | github.com/emilk/egui |

## 3. Export prerequisites (CI)

| Id | Candidate | Fact | Source |
|---|---|---|---|
| ENG-GODOT-004 | Godot | Android: OpenJDK 17 (higher supported); SDK Platform 35; Build-Tools 35.0.1; Platform-Tools 35.0.0 or later; Command-line Tools "latest"; CMake 3.10.2.4988404; NDK r28b (28.1.13356709). Gradle build only for AAB (Play Store); plain APK needs none. Env vars `GODOT_ANDROID_KEYSTORE_DEBUG_*` exist; whether a debug keystore is mandatory in CLI: not verified. | docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html (4.7) |
| ENG-GODOT-005 | Godot | Export templates must be installed (Editor > Manage Export Templates, or a .tpz from godotengine.org) or the preset must define a custom template. Templates need the matching editor version (inference). | docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html (4.7) |
| ENG-FLUTTER-004 | Flutter | Android Studio; SDK Platform API 36; SDK tools: Build-Tools, Command-line Tools, Platform-Tools, CMake, NDK (Side by side), Emulator; accept licences with `flutter doctor --android-licenses`. JDK not listed (Android Studio bundles one); exact build-tools/NDK versions: not verified. | docs.flutter.dev/platform-integration/android/setup (3.50) |
| ENG-UNITY-004 | Unity | 6000.6: OpenJDK 17; NDK r27c (27.2.12479018); SDK Build-Tools 36.0.0; Command-line Tools 16.0 (21.0 from 6000.6.8f1); Platform-Tools 36.0.0 or 37.0.1 depending on patch; CMake 3.22.1; no exact SDK platform required by the page. Needs the Android Build Support module. | docs.unity.com/en-us/engine/6000.6/manual/platform-specific/android/getting-started/sdksetup/supported-dependency-versions |
| ENG-UNITY-005 | Unity | Headless/CI build of a project (batchmode, licence activation for CI, GameCI): not verified in this pass. | - |
| ENG-RUST-006 | Rust | Android CI prerequisites (rustup targets, NDK version, cargo-ndk): not verified. | - |

## 4. Headless testing and CI export

| Id | Candidate | Fact | Source |
|---|---|---|---|
| ENG-GODOT-006 | Godot | `--headless` equals `--display-driver headless --audio-driver Dummy`; required on machines without a GPU (CI). `godot --headless --export-release "<preset>" <out>`; preset must exist in `export_presets.cfg`; output dir must already exist; `--path` selects the project. `--script` runs a SceneTree script. | docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html (4.7) |
| ENG-GODOT-007 | Godot | Test framework: GdUnit4 (MIT). Compatibility: master v7.0.0 with Godot 4.7, 4.7.1, 4.8.dev7; v6.2.x with 4.5 to 4.7.1. Latest release number not verified. Offers a CLI runner for CI, JUnit XML and HTML reports, and a GitHub Marketplace "gdunit4-action". Third-party, not a Godot vendor product. | github.com/MikeSchulze/gdUnit4 |
| ENG-GODOT-008 | Godot | GitHub Actions: no Godot-published workflow found. A generic job is: install JDK 17, Android SDK packages from ENG-GODOT-004, Godot editor and templates for the same version, then the ENG-GODOT-006 command. Workflow itself is not vendor-documented (not verified). | derived from ENG-GODOT-004/005/006 |
| ENG-FLUTTER-005 | Flutter | Unit and widget tests run with `flutter test` (package `flutter_test`, in the SDK, version = SDK 3.50.1), no device needed; `integration_test` ships with the SDK and needs a device or emulator; cannot touch native UI (Patrol suggested). Docs give no headless GitHub Actions recipe (not verified). | docs.flutter.dev/testing/overview (3.50) |
| ENG-UNITY-006 | Unity | Test framework (Unity Test Framework package, version): not verified. | - |
| ENG-RUST-007 | Bevy | Tests via `cargo test`; headless Bevy testing recipe and Android CI: not verified. | - |

## 5. Custom 2D drawing, shaders, audio

| Id | Candidate | Fact | Source |
|---|---|---|---|
| ENG-GODOT-009 | Godot | Shading language based on GLSL; `shader_type canvas_item` for 2D with `vertex()`, `fragment()`, `light()`. Custom drawing via CanvasItem `_draw()` (not fetched, not verified). | docs.godotengine.org/en/stable/tutorials/shaders/introduction_to_shaders.html (4.7) |
| ENG-GODOT-010 | Godot | Audio: any number of buses with effects, AudioStreamPlayer, dB scale, default layout `res://default_bus_layout.tres`. Supported file formats: not verified. | docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html (4.7) |
| ENG-FLUTTER-006 | Flutter | Custom 2D drawing (CustomPainter/Canvas), fragment shaders (FragmentProgram), audio (first-party plugin or package): not verified (pages not fetched). | - |
| ENG-UNITY-007 | Unity | 2D drawing, shader authoring in URP (Shader Graph/HLSL), audio: not verified (pages not fetched). Built-in pipeline deprecated, supported through the 6.7 LTS lifecycle. | requirements-and-compatibility page (ENG-UNITY-003) |
| ENG-RUST-008 | Bevy/egui | Bevy 2D rendering (wgpu, WGSL shaders), bevy_audio; egui painter and wgpu/glow backends: only the egui backend fact is verified (ENG-RUST-003). Rest not verified. | github.com/emilk/egui |

## 6. Build size (empty project)

| Id | Candidate | Fact | Source |
|---|---|---|---|
| ENG-GODOT-011 | Godot | Empty APK and desktop binary size: not verified. Vendor notes custom export templates can cut size; the editor needs about 1.3 GB for export templates when installed on Android. | exporting_for_android (4.7); system_requirements (4.7) |
| ENG-FLUTTER-007 | Flutter | Empty APK size: not verified. Only vendor baseline is an old iOS figure (Flutter 1.17: 5.4 MB compressed, 13.7 MB uncompressed), not usable for Android. Measure with `flutter build apk --analyze-size`; debug builds are not representative. | docs.flutter.dev/perf/app-size |
| ENG-UNITY-008 | Unity | Empty APK and desktop build size: not verified. | - |
| ENG-RUST-009 | Bevy/egui | Empty APK and binary size: not verified. | - |

## 7. Gaps to close before the ledger

- Not verified anywhere: all empty-build sizes, Unity CI/test framework, Bevy Android toolchain, Flutter audio and shaders.
- Unity pricing page figures predate Jan 2026; re-check the current price if cost matters.
- Flutter version comes from Google's release manifest (the archive page renders it by script), not the page text.
- GdUnit4 is third-party; Flutter's `flutter_test` and Bevy's `cargo test` are the built-in options.
