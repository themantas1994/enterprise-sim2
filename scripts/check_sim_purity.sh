#!/usr/bin/env bash
# ADR 0001 rule: sim/ is pure simulation. It must not reference Control, CanvasItem, Input, get_tree, Time,
# must not extend Node, and must not use the global random functions (one seeded RandomNumberGenerator only).
# Usage: scripts/check_sim_purity.sh [dir, default sim]    Exit 1 on any hit.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
dir="${1:-sim}"
[ -d "$dir" ] || { echo "no such dir: $dir" >&2; exit 2; }
fail=0
check() { # $1 = description, $2 = extended regex
  if grep -rnE --include='*.gd' --include='*.tscn' --include='*.tres' "$2" "$dir"; then
    echo "FAIL: $1" >&2; fail=1
  fi
}
check "forbidden engine reference (Control, CanvasItem, Input, get_tree, Time)" '\b(Control|CanvasItem|Input|get_tree|Time)\b'
check "sim classes must not extend Node" '^\s*extends\s+Node\b'
check "global random functions are forbidden; use a seeded RandomNumberGenerator" '(^|[^.[:alnum:]_])(randi|randf|randomize|randi_range|randf_range)\('
if [ "$fail" -eq 0 ]; then echo "sim purity: OK ($dir)"; fi
exit "$fail"
