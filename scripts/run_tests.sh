#!/usr/bin/env bash
# Run the GdUnit4 suite headless (check C1). Reports go to build/reports (JUnit XML + HTML).
# Usage: scripts/run_tests.sh [test dir, default res://tests]
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
cd "$REPO_ROOT"
"$GODOT_BIN" --headless --path . --import || true   # first import builds the class cache; may exit non-zero
mkdir -p build/reports
"$GODOT_BIN" --headless --path . -s -d res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --add "${1:-res://tests}" --report-directory res://build/reports --ignoreHeadlessMode --continue
