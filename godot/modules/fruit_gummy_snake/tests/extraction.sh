#!/usr/bin/env bash
set -euo pipefail
MODULE="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:?Set GODOT_BIN to Godot 4.7.2}"
QA="$(mktemp -d /tmp/fruit-gummy-extract.XXXXXX)"
python3 - "$MODULE" "$QA/project" <<'PY'
from pathlib import Path
import sys,shutil,hashlib,json
src=Path(sys.argv[1]);project=Path(sys.argv[2]);dst=project/'modules/fruit_gummy_snake'
manifest={}
for p in sorted(src.rglob('*')):
    if not p.is_file() or '.godot' in p.parts or p.suffix=='.import' or '__pycache__' in p.parts:continue
    assert not p.is_symlink()
    target=dst/p.relative_to(src);target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
    assert target.read_bytes()==p.read_bytes()
    manifest[str(p.relative_to(src))]=hashlib.sha256(p.read_bytes()).hexdigest()
(project/'project.godot').write_text('''config_version=5
[application]
config/name="Fruit Chews Standalone"
run/main_scene="res://modules/fruit_gummy_snake/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
anti_aliasing/quality/msaa_3d=2
''')
(project.parent/'source_sha256.json').write_text(json.dumps(manifest,indent=2))
print('FRUIT FRESH SOURCE',len(manifest),'files')
PY
export XDG_DATA_HOME="$QA/data" XDG_CONFIG_HOME="$QA/config" XDG_CACHE_HOME="$QA/cache"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
"$GODOT" --headless --path "$QA/project" --editor --import --quit >"$QA/import.log" 2>&1
for test in test_xyz test_camera test_storage test_runtime test_interface test_detach; do
 "$GODOT" --headless --path "$QA/project" --script "res://modules/fruit_gummy_snake/tests/$test.gd" 2>&1 | tee "$QA/$test.log"
done
python3 "$QA/project/modules/fruit_gummy_snake/tests/check_assets.py" | tee "$QA/assets.log"
if grep -ER 'SCRIPT ERROR:|Parse Error:|^ERROR:|ObjectDB.*leaked|resources still in use' "$QA"/*.log; then exit 1; fi
printf 'FRUIT FRESH EXTRACTION PASS %s\n' "$QA"
