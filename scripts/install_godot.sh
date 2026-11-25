#!/usr/bin/env bash
# Install the pinned Godot editor and the export templates this project needs into $GODOT_HOME.
# Every download is verified against the official SHA512-SUMS.txt of the same release.
# Usage: scripts/install_godot.sh        (GODOT_HOME defaults to ~/.cache/enterprise-sim2/godot)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"

editor_zip="Godot_v${GODOT_RELEASE_TAG}_linux.x86_64.zip"
tpz="Godot_v${GODOT_RELEASE_TAG}_export_templates.tpz"
dl="$GODOT_HOME/download"
mkdir -p "$dl" "$GODOT_HOME/bin" "$TEMPLATES_DIR" "$XDG_CONFIG_HOME"

if [ -x "$GODOT_BIN" ] && [ -f "$TEMPLATES_DIR/version.txt" ] && [ -f "$GODOT_HOME/.verified-$GODOT_VERSION" ]; then
  echo "Godot $GODOT_VERSION already installed in $GODOT_HOME"
  "$GODOT_BIN" --version
  exit 0
fi

curl -fsSL --retry 3 -o "$dl/SHA512-SUMS.txt" "$GODOT_BASE_URL/SHA512-SUMS.txt"
for f in "$editor_zip" "$tpz"; do
  if ! ( cd "$dl" && grep -F "  $f" SHA512-SUMS.txt | sha512sum -c --status - ) 2>/dev/null; then
    echo "downloading $f"
    curl -fSL --retry 3 -o "$dl/$f" "$GODOT_BASE_URL/$f"
  fi
  ( cd "$dl" && grep -F "  $f" SHA512-SUMS.txt | sha512sum -c - )
done

unzip -oq "$dl/$editor_zip" -d "$dl/editor"
install -m 755 "$dl/editor/Godot_v${GODOT_RELEASE_TAG}_linux.x86_64" "$GODOT_BIN"

# Only the templates for Linux x86_64, Windows x86_64 and Android (non-Gradle APK).
unzip -oqj "$dl/$tpz" \
  templates/version.txt templates/icudt_godot.dat \
  'templates/linux_debug.x86_64' 'templates/linux_release.x86_64' \
  'templates/windows_debug_x86_64.exe' 'templates/windows_release_x86_64.exe' \
  'templates/windows_debug_x86_64_console.exe' 'templates/windows_release_x86_64_console.exe' \
  'templates/android_debug.apk' 'templates/android_release.apk' \
  -d "$TEMPLATES_DIR"
[ "$(cat "$TEMPLATES_DIR/version.txt")" = "${GODOT_VERSION}.stable" ] || { echo "template version mismatch" >&2; exit 1; }
touch "$GODOT_HOME/.verified-$GODOT_VERSION"
"$GODOT_BIN" --version
