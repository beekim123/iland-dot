#!/usr/bin/env bash
# Independently verify the distributable is module-only and can import and boot.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d "${TMPDIR:-/tmp}/bloom-extraction-qa.XXXXXX")"
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
DEST="$QA/standalone"
python3 "$ROOT/tools/extract_game.py" bloom_skirmish "$DEST"
python3 "$ROOT/tools/qa/bloom_skirmish/skin_assets.py" --root "$DEST/modules/bloom_skirmish/art/models/animals/rigged"
python3 "$ROOT/tools/qa/bloom_skirmish/skin_palette.py" --module "$DEST/modules/bloom_skirmish" --json "$QA/fox-palette.json"
python3 - "$ROOT" "$DEST" <<'PY'
import pathlib, re, sys
root, dest = map(pathlib.Path, sys.argv[1:])
assert {p.name for p in dest.iterdir()} == {'modules', 'project.godot'}, 'Unexpected root payload'
assert {p.name for p in (dest / 'modules').iterdir()} == {'bloom_skirmish'}, 'Other module leaked into export'
project = (dest / 'project.godot').read_text()
main = (root / 'godot/project.godot').read_text()
name = lambda text: re.search(r'config/name="([^"]+)"', text).group(1)
assert name(project) != name(main), 'Standalone and host userdata names must differ'
assert 'res://modules/bloom_skirmish/main.tscn' in project
assert (dest / 'modules/bloom_skirmish/main.tscn').is_file()
assert not any(p.name in {'app', 'hub'} for p in dest.iterdir())
print('Extraction boundaries and distinct application identity PASS')
PY
if python3 "$ROOT/tools/extract_game.py" bloom_skirmish "$DEST" >"$QA/existing-destination.log" 2>&1; then
 echo 'FAIL: extractor overwrote an existing destination' >&2; exit 1
fi
if python3 "$ROOT/tools/extract_game.py" not_a_game "$QA/invalid" >"$QA/invalid-id.log" 2>&1; then
 echo 'FAIL: extractor accepted an unknown module' >&2; exit 1
fi
run_clean() {
 local name="$1"; shift
 "$GODOT" --headless --path "$DEST" "$@" 2>&1 | tee "$QA/$name.log"
 if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA/$name.log"; then
  echo "FAIL: engine errors during $name (see $QA/$name.log)" >&2; exit 1
 fi
}
run_clean import --editor --import --quit
run_clean boot --script "$ROOT/tools/qa/bloom_skirmish/standalone.gd"
run_clean rules --script "$ROOT/tools/qa/bloom_skirmish/independent.gd"
run_clean perspective --script "$ROOT/tools/qa/bloom_skirmish/perspective.gd"
run_clean hud --script "$ROOT/tools/qa/bloom_skirmish/hud.gd"
run_clean skin --script "$ROOT/tools/qa/bloom_skirmish/skin_runtime.gd"
run_clean animal-runtime --script "$ROOT/tools/qa/bloom_skirmish/animal_runtime.gd"
run_clean close --script "$ROOT/tools/qa/bloom_skirmish/window_close.gd" -- --close-mode=standalone
printf 'BLOOM EXTRACTION PASS; isolated evidence retained at %s\n' "$QA"
