# shellcheck shell=bash
# Source this file. Sets GODOT_HOME (tool install dir, outside the repo) and the Godot binary path.
# Godot's per-user data (export templates) and config (editor settings) are redirected under GODOT_HOME,
# so a local run never touches the real user profile.
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_here/.." && pwd)"
# shellcheck disable=SC1091
. "$_here/pins.env"
export GODOT_HOME="${GODOT_HOME:-$HOME/.cache/enterprise-sim2/godot}"
export XDG_DATA_HOME="$GODOT_HOME/xdg-data"
export XDG_CONFIG_HOME="$GODOT_HOME/xdg-config"
export GODOT_BIN="$GODOT_HOME/bin/godot"
export TEMPLATES_DIR="$XDG_DATA_HOME/godot/export_templates/${GODOT_VERSION}.stable"
