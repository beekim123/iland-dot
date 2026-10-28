#!/usr/bin/env bash
set -euo pipefail
MODULE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/workspace/scratch/e3e9ec015b32/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64}"
QA="$(mktemp -d /tmp/pelican-rebuild-final.XXXXXX)"
mkdir -p "$QA/project/modules/pelican_pedal" "$QA/data" "$QA/config" "$QA/cache"
python3 - "$MODULE" "$QA/project/modules/pelican_pedal" <<'PY'
import sys,pathlib,shutil,hashlib,json
src,dst=map(pathlib.Path,sys.argv[1:]);manifest={}
for p in src.rglob('*'):
 if not p.is_file() or p.suffix=='.import' or '.godot' in p.parts or '__pycache__' in p.parts: continue
 rel=p.relative_to(src);q=dst/rel;q.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,q)
 manifest[str(rel)]=hashlib.sha256(p.read_bytes()).hexdigest()
(dst.parent.parent.parent/'source-sha256.json').write_text(json.dumps(manifest,indent=2))
PY
cat > "$QA/project/project.godot" <<'PROJECT'
config_version=5
[application]
config/name="Pelican Final Isolated"
run/main_scene="res://modules/pelican_pedal/main.tscn"
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
PROJECT
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
run_clean() {
 local label="$1"; shift
 "$GODOT" --headless --path "$QA/project" "$@" > "$QA/$label.log" 2>&1
 if grep -E 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA/$label.log"; then echo "FAIL $label";exit 1;fi
 tail -3 "$QA/$label.log"
}
python3 "$MODULE/ui/subset_font.py" --check
run_clean import --editor --import --quit
for test in test_sim test_routes test_edges test_storage test_runtime test_input test_world; do
 export XDG_DATA_HOME="$QA/$test/data"
 run_clean "$test" --script "res://modules/pelican_pedal/tests/$test.gd"
done
if [ -f "$MODULE/art/test_assets.gd" ]; then run_clean art --script res://modules/pelican_pedal/art/test_assets.gd;fi
run_clean seaside_art --script res://modules/pelican_pedal/art/test_seaside_props.gd
run_clean standalone_pause --script res://modules/pelican_pedal/tests/test_standalone_exit.gd
run_clean standalone_result --script res://modules/pelican_pedal/tests/test_standalone_exit.gd -- result
printf 'PELICAN FRESH EXTRACTION PASS %s\n' "$QA"
