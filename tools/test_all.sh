#!/usr/bin/env bash
# Full headless suite in isolated QA userdata; never touches player saves.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d "${TMPDIR:-/tmp}/sunny-shell-qa.XXXXXX")"
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
printf 'QA user data (not player data): %s\n' "$QA"
run_clean() {
 local name="$1"; shift
 "$GODOT" --headless --path "$ROOT/godot" "$@" 2>&1 | tee "$QA/$name.log"
 # Godot can return zero after a script error. Such output is not a test pass.
 if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA/$name.log"; then
  printf 'Engine errors during %s; inspect %s\n' "$name" "$QA/$name.log" >&2
  exit 1
 fi
}
python3 "$ROOT/tools/qa/test_extract_game.py" 2>&1 | tee "$QA/extractor-policy.log"
python3 "$ROOT/tools/qa/bloom_skirmish/assets.py" 2>&1 | tee "$QA/bloom-assets.log"
python3 "$ROOT/godot/modules/bloom_skirmish/ui/subset_font.py" --check 2>&1 | tee "$QA/bloom-font.log"
python3 "$ROOT/tools/qa/bloom_skirmish/skin_assets.py" 2>&1 | tee "$QA/bloom-animal-skin-assets.log"
python3 "$ROOT/tools/qa/bloom_skirmish/skin_palette.py" --json "$QA/bloom-fox-palette.json" 2>&1 | tee "$QA/bloom-fox-palette.log"
run_clean import --editor --import --quit
for script in tests/check_scene.gd tests/check_app.gd hub/tests/test_hub.gd modules/gummy_bomber/tests/test_sim.gd modules/gummy_bomber/tests/test_runtime.gd modules/gummy_bomber/tests/test_save_schema.gd modules/bloom_skirmish/art/validate_art.gd modules/bloom_skirmish/tests/test_sim.gd modules/bloom_skirmish/tests/test_runtime.gd modules/bloom_skirmish/tests/test_storage.gd; do
 printf '\n== %s ==\n' "$script"
 run_clean "${script//\//_}" --script "res://$script"
done
for module in gummy_bomber bloom_skirmish; do
 for script in independent lifecycle storage; do
  printf '\n== independent QA: %s / %s ==\n' "$module" "$script"
  run_clean "${module}_${script}" --script "$ROOT/tools/qa/$module/$script.gd"
 done
done
for script in perspective liquid hud skin_runtime animal_runtime; do
 printf '\n== independent third-person QA: %s ==\n' "$script"
 run_clean "bloom_$script" --script "$ROOT/tools/qa/bloom_skirmish/$script.gd"
done
printf '\n== ordinary application window-close regression ==\n'
GODOT_BIN="$GODOT" "$ROOT/tools/qa/bloom_skirmish/window_close.sh" 2>&1 | tee "$QA/bloom_window_close.log"
printf '\n== standalone bloom_skirmish extraction ==\n'
GODOT_BIN="$GODOT" "$ROOT/tools/qa/bloom_skirmish/extraction.sh" 2>&1 | tee "$QA/bloom_extraction.log"
printf '\nAll headless tests passed. Graphical/WebGL and performance QA are separate. QA data retained at %s\n' "$QA"
