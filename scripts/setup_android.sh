#!/usr/bin/env bash
# Android prerequisites for the debug APK export (ENG-GODOT-004), plus a throwaway DEBUG keystore (check C4).
# Needs JDK 17 (JAVA_HOME or java on PATH).
#
# The SDK goes into a directory this script controls (ANDROID_SDK_DIR, default $GODOT_HOME/android-sdk),
# never into a preinstalled, possibly read-only SDK. sdkmanager is bootstrapped from the pinned
# cmdline-tools zip, verified with the SHA-256 published on developer.android.com/studio (pins.env).
# Limitation: the SDK packages that sdkmanager then installs are verified by sdkmanager itself
# (checksums from Google's repository XML over HTTPS), not by values pinned here. platform-tools cannot be
# pinned by sdkmanager; the installed version is checked against ANDROID_PLATFORM_TOOLS_MIN.
#
# The keystore is created in $GODOT_HOME, never in the repo. Its random password is held only in the
# environment (GITHUB_ENV in CI, masked) or in a 0600 file under $GODOT_HOME (local runs).
# Usage: scripts/setup_android.sh
set -euo pipefail
umask 077
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
ANDROID_SDK_DIR="${ANDROID_SDK_DIR:-$GODOT_HOME/android-sdk}"
export ANDROID_HOME="$ANDROID_SDK_DIR" ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
mkdir -p "$GODOT_HOME"
touch "$GODOT_HOME/.gdignore"

sdkm="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$sdkm" ]; then
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  curl --proto '=https' --tlsv1.2 -fSL --retry 3 -o "$tmp/cmd.zip" \
    "https://dl.google.com/android/repository/$ANDROID_CMDLINE_TOOLS_ZIP"
  echo "$ANDROID_CMDLINE_TOOLS_SHA256  $tmp/cmd.zip" | sha256sum -c -
  unzip -q "$tmp/cmd.zip" -d "$tmp/x"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv "$tmp/x/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
fi
set +o pipefail; yes | "$sdkm" --sdk_root="$ANDROID_HOME" --licenses >/dev/null; set -o pipefail
"$sdkm" --sdk_root="$ANDROID_HOME" "platform-tools" "platforms;${ANDROID_PLATFORM}" \
  "build-tools;${ANDROID_BUILD_TOOLS}" "cmdline-tools;latest" "cmake;${ANDROID_CMAKE}" "ndk;${ANDROID_NDK}"
pt="$(sed -n 's/^Pkg.Revision=//p' "$ANDROID_HOME/platform-tools/source.properties" | head -1)"
echo "platform-tools installed: $pt (minimum $ANDROID_PLATFORM_TOOLS_MIN)"
[ "$(printf '%s\n%s\n' "$ANDROID_PLATFORM_TOOLS_MIN" "$pt" | sort -V | head -1)" = "$ANDROID_PLATFORM_TOOLS_MIN" ] \
  || { echo "platform-tools older than $ANDROID_PLATFORM_TOOLS_MIN" >&2; exit 1; }

java_home="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
ks="$GODOT_HOME/debug.keystore"
if [ ! -f "$ks" ]; then
  KS_PW="$(head -c 24 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)"
  export KS_PW
  # -storepass:env / -keypass:env keep the password off the command line.
  "$java_home/bin/keytool" -genkeypair -v -keystore "$ks" -alias androiddebugkey -keyalg RSA -keysize 2048 \
    -validity 10000 -storepass:env KS_PW -keypass:env KS_PW -dname "CN=Android Debug,O=Android,C=US" >/dev/null
  printf '%s' "$KS_PW" > "$GODOT_HOME/.debug-keystore-pw"
  unset KS_PW
fi
pw="$(cat "$GODOT_HOME/.debug-keystore-pw")"
echo "::add-mask::$pw"   # always, also when the keystore already existed (workflow command, harmless locally)

# Editor settings that tell Godot where the SDK and JDK are (headless export reads them).
mkdir -p "$XDG_CONFIG_HOME/godot"
cat > "$XDG_CONFIG_HOME/godot/editor_settings-4.7.tres" <<TRES
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$java_home"
export/android/android_sdk_path = "$ANDROID_HOME"
TRES

vars=(
  "ANDROID_HOME=$ANDROID_HOME"
  "ANDROID_SDK_ROOT=$ANDROID_HOME"
  "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$ks"
  "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
  "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=$pw"
)
if [ -n "${GITHUB_ENV:-}" ]; then printf '%s\n' "${vars[@]}" >> "$GITHUB_ENV"; fi
{ for v in "${vars[@]}"; do echo "export $v"; done; } > "$GODOT_HOME/android-env.sh"
echo "wrote $GODOT_HOME/android-env.sh (source it before scripts/export.sh android)"
