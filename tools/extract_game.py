#!/usr/bin/env python3
"""Extract a self-contained module as a new Godot project (never overwrite files)."""
import argparse
from pathlib import Path
import re
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('game_id', choices=['gummy_bomber'])
parser.add_argument('destination', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source = root / 'godot/modules' / args.game_id
if not (source / 'main.tscn').is_file():
    parser.error('Module entry main.tscn is missing.')
dest = args.destination.resolve()
if dest.exists():
    parser.error('Destination must not exist; extraction will not overwrite another project.')
# Keep res://modules/<id>/ ABI stable, copying only that module, not shell/island data.
for script in source.rglob('*'):
    if not script.is_file() or script.suffix not in {'.gd', '.tscn', '.tres', '.gdshader'}:
        continue
    for path in re.findall(r'res://[^"\s\)]+', script.read_text()):
        if not path.startswith(f'res://modules/{args.game_id}/'):
            parser.error(f'External dependency in {script.name}: {path}')
shutil.copytree(source, dest / 'modules' / args.game_id,
                ignore=shutil.ignore_patterns('.godot', '*.import', '__pycache__'))
(dest / 'project.godot').write_text(f'''config_version=5
[application]
config/name="Gummy Garden Standalone"
run/main_scene="res://modules/{args.game_id}/main.tscn"
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
print(dest)
