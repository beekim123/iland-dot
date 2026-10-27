#!/usr/bin/env bash
# Import and run the same module/independent suites in a genuine host-free copy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
GODOT="${GODOT_BIN:-$ROOT/../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d "${TMPDIR:-/tmp}/tide-extraction-qa.XXXXXX")"
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
DEST="$QA/standalone"
python3 "$ROOT/tools/extract_game.py" tide_gulp "$DEST"
python3 - "$ROOT" "$DEST" <<'PY'
from pathlib import Path
import hashlib, re, sys
root, dest = map(Path, sys.argv[1:])
assert {p.name for p in dest.iterdir()} == {'modules', 'project.godot'}
assert {p.name for p in (dest / 'modules').iterdir()} == {'tide_gulp'}
source = root / 'godot/modules/tide_gulp'
files = 0
for copied in (dest / 'modules/tide_gulp').rglob('*'):
    if not copied.is_file():
        continue
    original = source / copied.relative_to(dest / 'modules/tide_gulp')
    assert hashlib.sha256(copied.read_bytes()).digest() == hashlib.sha256(original.read_bytes()).digest(), copied
    assert not copied.name.endswith('.import')
    files += 1
name = lambda p: re.search(r'config/name="([^"]+)"', p.read_text()).group(1)
assert name(dest / 'project.godot') != name(root / 'godot/project.godot')
assert 'res://modules/tide_gulp/main.tscn' in (dest / 'project.godot').read_text()
print(f'TIDE EXTRACTION BOUNDARY PASS: {files} byte-identical local files, no host/other modules, distinct save-app identity')
PY
python3 "$ROOT/tools/qa/tide_gulp/assets.py" --module "$DEST/modules/tide_gulp"
if python3 "$ROOT/tools/extract_game.py" tide_gulp "$DEST" >"$QA/overwrite-policy.log" 2>&1; then
 echo 'FAIL: existing standalone was overwritten' >&2; exit 1
fi
run_clean() {
 local name="$1"; shift
 "$GODOT" --headless --path "$DEST" "$@" 2>&1 | tee "$QA/$name.log"
 if grep -Eq 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA/$name.log"; then
  echo "FAIL: engine errors during $name (see $QA/$name.log)" >&2; exit 1
 fi
}
run_clean import --editor --import --quit
for test in test_sim test_runtime test_storage; do
 run_clean "$test" --script "res://modules/tide_gulp/tests/$test.gd"
done
run_clean art --script res://modules/tide_gulp/art/tide_art_contract_check.gd
run_clean ui-audio --script res://modules/tide_gulp/ui/test_ui_audio.gd
for test in resource_probe independent lifecycle storage; do
 run_clean "$test" --script "$ROOT/tools/qa/tide_gulp/$test.gd"
done
printf 'TIDE EXTRACTION PASS; identical suites passed outside host; evidence %s\n' "$QA"
