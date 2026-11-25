# Source ledger

Every Star Trek value (number, component name, behaviour) and every engine or platform fact used by the
project is recorded here with an official source and is referenced elsewhere by its `id`.
Code, ship data and tests cite ledger ids (for example `D-WARP-004`) instead of repeating the source.

## Rules

- Official sources, in order: licensed reference books (TNG Technical Manual, Haynes U.S.S. Enterprise
  manual, Mr. Scott's Guide to the Enterprise, Eaglemoss/Hero Collector Illustrated Handbooks), on-screen
  canon (episode or film named), StarTrek.com. Memory Alpha may only be used to find a primary source;
  the ledger records the primary source. Engine and platform facts: the vendor's own documentation for the
  exact version.
- Paraphrase only. Never copy book text or images into the repository.
- `id` format: `<SHIP>-<SYSTEM>-<NNN>` for ship values (`D` = 1701-D, `A` = 1701-A, `E` = 1701-E) and
  `ENG-<TOPIC>-<NNN>` for engine and platform facts.
- `status`: `verified` (checked against the cited source), `estimate` (no official source; say why in
  `meaning`), `unverified` (recorded but not yet checked).
- `verified_by`: who or what checked the value against the source, and how.

## Ledger

| id | value | unit | meaning | source | section/scene | verified_by | date | status |
|---|---|---|---|---|---|---|---|---|
