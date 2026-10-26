#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
export XDG_DATA_HOME="$ROOT/.runtime/data"
export XDG_CONFIG_HOME="$ROOT/.runtime/config"
export XDG_CACHE_HOME="$ROOT/.runtime/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
case "${1:-}" in
 --sync) exec python3 "$ROOT/tools/sync_resources.py";;
 --import) exec "$GODOT" --headless --path "$ROOT/godot" --editor --import --quit;;
 --test) exec "$GODOT" --headless --path "$ROOT/godot" --script tests/check_scene.gd;;
 --gif) exec "$GODOT" --path "$ROOT/godot" --resolution 960x600 -- --gif;;
 --shots) exec "$GODOT" --path "$ROOT/godot" -- --shots;;
 *) exec "$GODOT" --path "$ROOT/godot" "$@";;
esac
