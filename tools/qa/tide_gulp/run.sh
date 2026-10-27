#!/usr/bin/env bash
# Focused third-game QA: avoids re-running the unrelated large Bloom oracle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d "${TMPDIR:-/tmp}/tide-focused-qa.XXXXXX")"
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
printf 'Isolated focused QA: %s\n' "$QA"
run_clean() {
 local name="$1"; shift
 "$GODOT" --headless --path "$ROOT/godot" "$@" 2>&1 | tee "$QA/$name.log"
 if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA/$name.log"; then
  echo "FAIL: engine errors during $name (see $QA/$name.log)" >&2; exit 1
 fi
}
python3 "$ROOT/tools/qa/test_extract_game.py" 2>&1 | tee "$QA/extraction-policy.log"
python3 "$ROOT/tools/qa/tide_gulp/assets.py" 2>&1 | tee "$QA/assets.log"
run_clean import --editor --import --quit
for test in test_sim test_runtime test_storage; do
 run_clean "$test" --script "res://modules/tide_gulp/tests/$test.gd"
done
run_clean art --script res://modules/tide_gulp/art/tide_art_contract_check.gd
run_clean ui-audio --script res://modules/tide_gulp/ui/test_ui_audio.gd
for test in resource_probe independent lifecycle storage; do
 run_clean "$test" --script "$ROOT/tools/qa/tide_gulp/$test.gd"
done
run_clean hub --script res://hub/tests/test_hub.gd
run_clean picker --script res://hub/tests/test_portal_picking.gd
run_clean initial-layout --script res://hub/tests/test_portal_layout.gd
run_clean app --script res://tests/check_app.gd
GODOT_BIN="$GODOT" "$ROOT/tools/qa/tide_gulp/extraction.sh" 2>&1 | tee "$QA/extraction.log"
printf 'TIDE FOCUSED QA PASS; graphical/manual/WebGL and subjective audio are separate; evidence %s\n' "$QA"
