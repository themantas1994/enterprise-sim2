#!/usr/bin/env bash
# Android prerequisites for the debug APK export (ENG-GODOT-004), plus a throwaway DEBUG keystore (check C4).
# Needs JDK 17 (JAVA_HOME or java on PATH) and the Android SDK command-line tools (sdkmanager).
# The keystore is created in $GODOT_HOME, never in the repo, with random passwords held only in the
# environment (written to $GITHUB_ENV in CI, or printed as export lines to $GODOT_HOME/android-env.sh locally).
# Usage: ANDROID_HOME=/path/to/sdk scripts/setup_android.sh
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
: "${ANDROID_HOME:?set ANDROID_HOME to the Android SDK root}"
sdkm="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
[ -x "$sdkm" ] || sdkm="$(command -v sdkmanager)"
set +o pipefail; yes | "$sdkm" --licenses >/dev/null; set -o pipefail
"$sdkm" "platform-tools" "platforms;${ANDROID_PLATFORM}" "build-tools;${ANDROID_BUILD_TOOLS}" \
  "cmdline-tools;latest" "cmake;${ANDROID_CMAKE}" "ndk;${ANDROID_NDK}"
# Pin platform-tools: sdkmanager installs the newest; report what is there (ENG-GODOT-004 asks >= 35.0.0).
grep -m1 '^Pkg.Revision' "$ANDROID_HOME/platform-tools/source.properties" || true

java_home="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
ks="$GODOT_HOME/debug.keystore"
if [ ! -f "$ks" ]; then
  pw="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
  [ -z "${GITHUB_ACTIONS:-}" ] || echo "::add-mask::$pw"
  "$java_home/bin/keytool" -genkeypair -v -keystore "$ks" -alias androiddebugkey -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass "$pw" -keypass "$pw" -dname "CN=Android Debug,O=Android,C=US" >/dev/null
  printf '%s' "$pw" > "$GODOT_HOME/.debug-keystore-pw"; chmod 600 "$GODOT_HOME/.debug-keystore-pw"
fi
pw="$(cat "$GODOT_HOME/.debug-keystore-pw")"

# Editor settings that tell Godot where the SDK and JDK are (headless export reads them).
mkdir -p "$XDG_CONFIG_HOME/godot"
cat > "$XDG_CONFIG_HOME/godot/editor_settings-4.7.tres" <<TRES
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$java_home"
export/android/android_sdk_path = "$ANDROID_HOME"
TRES

vars=(
  "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$ks"
  "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
  "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=$pw"
)
if [ -n "${GITHUB_ENV:-}" ]; then printf '%s\n' "${vars[@]}" >> "$GITHUB_ENV"; fi
umask 077
{ for v in "${vars[@]}"; do echo "export $v"; done; } > "$GODOT_HOME/android-env.sh"
echo "wrote $GODOT_HOME/android-env.sh (source it before scripts/export.sh android)"
