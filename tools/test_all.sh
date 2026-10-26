#!/usr/bin/env bash
# Full headless suite in isolated QA userdata; never touches player saves.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d "${TMPDIR:-/tmp}/sunny-shell-qa.XXXXXX")"
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
printf 'QA user data (not player data): %s\n' "$QA"
"$GODOT" --headless --path "$ROOT/godot" --editor --import --quit
for script in tests/check_scene.gd tests/check_app.gd hub/tests/test_hub.gd modules/gummy_bomber/tests/test_sim.gd modules/gummy_bomber/tests/test_runtime.gd modules/gummy_bomber/tests/test_save_schema.gd; do
 printf '\n== %s ==\n' "$script"
 "$GODOT" --headless --path "$ROOT/godot" --script "res://$script"
done
for script in independent lifecycle storage; do
 printf '\n== independent QA: %s ==\n' "$script"
 "$GODOT" --headless --path "$ROOT/godot" --script "$ROOT/tools/qa/gummy_bomber/$script.gd"
done
printf '\nAll headless tests passed. Graphical QA is separate. QA data retained at %s\n' "$QA"
