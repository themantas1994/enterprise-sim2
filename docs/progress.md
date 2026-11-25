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
