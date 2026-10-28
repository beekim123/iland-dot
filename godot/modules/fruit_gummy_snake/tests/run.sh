#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d /tmp/fruit-gummy-qa.XXXXXX)"
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
python3 "$ROOT/godot/modules/fruit_gummy_snake/tests/check_assets.py" | tee "$QA/assets.log"
"$GODOT" --headless --path "$ROOT/godot" --editor --import --quit >"$QA/import.log" 2>&1
for test in test_xyz test_camera test_storage test_runtime test_interface test_detach; do
 "$GODOT" --headless --path "$ROOT/godot" --script "res://modules/fruit_gummy_snake/tests/$test.gd" 2>&1 | tee "$QA/$test.log"
done
if grep -ER 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA"/*.log; then exit 1; fi
printf 'FRUIT MODULE QA PASS; logs %s; graphical/performance/Web are separate\n' "$QA"
