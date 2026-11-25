#!/usr/bin/env bash
# Print the size of every export artifact (check C6) and append it to the job summary if present.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
dir="${1:-build}"
out="$(mktemp)"; trap 'rm -f "$out"' EXIT
find "$dir" -type f \( -name '*.exe' -o -name '*.x86_64' -o -name '*.apk' -o -name '*.pck' \) -print0 \
  | xargs -0 -r stat -c '%s bytes  %n' | tee "$out"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then { echo '```'; cat "$out"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"; fi
