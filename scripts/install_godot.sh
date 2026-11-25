#!/usr/bin/env bash
# Install the pinned Godot editor and the export templates this project needs into $GODOT_HOME.
# Every download is verified against the SHA512 values pinned in scripts/pins.env (not against a
# checksum file fetched from the same server as the download).
# Usage: scripts/install_godot.sh        (GODOT_HOME defaults to ~/.cache/enterprise-sim2/godot)
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"

editor_zip="Godot_v${GODOT_RELEASE_TAG}_linux.x86_64.zip"
tpz="Godot_v${GODOT_RELEASE_TAG}_export_templates.tpz"
dl="$GODOT_HOME/download"
umask 022
mkdir -p "$dl" "$GODOT_HOME/bin" "$TEMPLATES_DIR" "$XDG_CONFIG_HOME"
touch "$GODOT_HOME/.gdignore"   # keep Godot from scanning tools if this dir sits inside the project

if [ -x "$GODOT_BIN" ] && [ -f "$TEMPLATES_DIR/version.txt" ] && [ -f "$GODOT_HOME/.verified-$GODOT_VERSION" ]; then
  echo "Godot $GODOT_VERSION already installed in $GODOT_HOME"
  "$GODOT_BIN" --version
  exit 0
fi

fetch() { # $1 file name, $2 expected sha512
  if ! echo "$2  $dl/$1" | sha512sum -c --status - 2>/dev/null; then
    echo "downloading $1"
    curl --proto '=https' --tlsv1.2 -fSL --retry 3 -o "$dl/$1" "$GODOT_BASE_URL/$1"
  fi
  echo "$2  $dl/$1" | sha512sum -c -
}
fetch "$editor_zip" "$GODOT_EDITOR_SHA512"
fetch "$tpz" "$GODOT_TEMPLATES_SHA512"

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
