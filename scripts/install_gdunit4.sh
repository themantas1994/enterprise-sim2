#!/usr/bin/env bash
# Fetch GdUnit4 at the pinned commit into addons/gdUnit4 (git-ignored, not vendored).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
dest="$REPO_ROOT/addons/gdUnit4"
if [ -f "$dest/plugin.cfg" ] && [ -f "$dest/.pinned-$GDUNIT4_COMMIT" ]; then echo "GdUnit4 $GDUNIT4_TAG present"; exit 0; fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
git clone -q --filter=blob:none --no-checkout "$GDUNIT4_REPO" "$tmp/g"
git -C "$tmp/g" checkout -q "$GDUNIT4_COMMIT"
[ "$(git -C "$tmp/g" rev-parse HEAD)" = "$GDUNIT4_COMMIT" ]
rm -rf "$dest"; mkdir -p "$REPO_ROOT/addons"
cp -r "$tmp/g/addons/gdUnit4" "$dest"
touch "$dest/.pinned-$GDUNIT4_COMMIT"
echo "GdUnit4 $GDUNIT4_TAG installed at $dest"
