#!/usr/bin/env bash
# Proves that the two data/purity checks really fail on bad input (and pass on good input).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/sim" "$t/ships"
printf 'extends RefCounted\nvar x := 1\n' > "$t/sim/ok.gd"
scripts/check_sim_purity.sh "$t/sim" >/dev/null
for bad in 'var c: Control' 'var t = Time.get_ticks_msec()' 'var n = get_tree()' 'var i = Input.is_key_pressed(1)' 'var r = randi()'; do
  printf 'extends RefCounted\n%s\n' "$bad" > "$t/sim/bad.gd"
  if scripts/check_sim_purity.sh "$t/sim" >/dev/null 2>&1; then echo "purity check missed: $bad" >&2; exit 1; fi
done
printf 'extends Node\n' > "$t/sim/bad.gd"
if scripts/check_sim_purity.sh "$t/sim" >/dev/null 2>&1; then echo "purity check missed extends Node" >&2; exit 1; fi
printf 'extends RefCounted\nvar r := RandomNumberGenerator.new()\nfunc f(): return r.randi()\n' > "$t/sim/bad.gd"
scripts/check_sim_purity.sh "$t/sim" >/dev/null   # seeded rng.randi() is allowed

echo '{"a": {"value": 1, "source": "ID-1"}}' > "$t/ships/ok.json"
python3 -I scripts/check_ship_sources.py "$t/ships" - >/dev/null
echo '{"a": {"value": 1}}' > "$t/ships/bad.json"
if python3 -I scripts/check_ship_sources.py "$t/ships" - >/dev/null 2>&1; then echo "ship check missed missing source" >&2; exit 1; fi
echo '{"a": [{"value": 1, "source": ""}]}' > "$t/ships/bad.json"
if python3 -I scripts/check_ship_sources.py "$t/ships" - >/dev/null 2>&1; then echo "ship check missed empty source" >&2; exit 1; fi
printf '| id | v |\n|---|---|\n| D-X-001 | a | u | m | s | sec | by | 2026-11-28 | verified |\n| D-X-002 | a | u | m | s | sec | by | 2026-11-28 | unverified |\n| D-X-003 | a | u | m | s | sec | by | 2026-11-28 | estimate |\n| ENG-X-001 | a | u | m | s | sec | by | 2026-11-28 | verified |\n' > "$t/ledger.md"
echo '{"a": {"value": 1, "source": "D-X-001"}, "b": {"value": 2, "source": "D-X-001, estimate"}}' > "$t/ships/ok.json"
rm -f "$t/ships/bad.json"
python3 -I scripts/check_ship_sources.py "$t/ships" "$t/ledger.md" >/dev/null
echo '{"a": {"value": 1, "source": "D-X-999"}}' > "$t/ships/bad.json"
if python3 -I scripts/check_ship_sources.py "$t/ships" "$t/ledger.md" >/dev/null 2>&1; then echo "ship check missed unknown ledger id" >&2; exit 1; fi
echo '{"a": {"value": 1, "source": "D-X-001, D-X-002"}}' > "$t/ships/bad.json"
if python3 -I scripts/check_ship_sources.py "$t/ships" "$t/ledger.md" >/dev/null 2>&1; then echo "ship check missed unverified ledger id" >&2; exit 1; fi
echo '{"a": {"value": 1, "source": "D-X-003"}}' > "$t/ships/bad.json"
if python3 -I scripts/check_ship_sources.py "$t/ships" "$t/ledger.md" >/dev/null 2>&1; then echo "ship check missed an estimate row cited by id" >&2; exit 1; fi
echo '{"a": {"value": 1, "source": "ENG-X-001"}}' > "$t/ships/ok.json"; rm -f "$t/ships/bad.json"
python3 -I scripts/check_ship_sources.py "$t/ships" "$t/ledger.md" >/dev/null
if python3 -I scripts/check_ship_sources.py "$t/ships" "$t/nope.md" >/dev/null 2>&1; then echo "ship check missed a missing ledger" >&2; exit 1; fi
echo "selftest: OK"
