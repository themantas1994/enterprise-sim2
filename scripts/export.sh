#!/usr/bin/env bash
# Headless export of one preset (ENG-GODOT-006). The output directory must exist (created here).
# Usage: scripts/export.sh windows|linux|android [debug|release]    (default: debug)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$REPO_ROOT"
case "${1:?platform: windows|linux|android}" in
  windows) preset="Windows Desktop"; out="build/windows/enterprise-sim2.exe" ;;
  linux)   preset="Linux";           out="build/linux/enterprise-sim2.x86_64" ;;
  android) preset="Android";         out="build/android/enterprise-sim2-debug.apk" ;;
  *) echo "unknown platform" >&2; exit 2 ;;
esac
mode="${2:-debug}"
[ "$mode" = debug ] || [ "$mode" = release ] || { echo "mode: debug|release" >&2; exit 2; }
mkdir -p "$(dirname "$out")"
"$GODOT_BIN" --headless --path . --import || true
"$GODOT_BIN" --headless --path . "--export-$mode" "$preset" "$out"
test -s "$out" || { echo "export produced no file: $out" >&2; exit 1; }
