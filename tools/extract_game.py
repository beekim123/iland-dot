#!/usr/bin/env python3
"""Extract a self-contained module as a new Godot project (never overwrite files)."""
import argparse
from pathlib import Path
import re
import shutil

GAMES = {
    'gummy_bomber': 'Gummy Garden Standalone',
    'bloom_skirmish': 'Bloom Skirmish Standalone',
    'tide_gulp': 'Tide Gulp Standalone',
    'beach_cleanup': 'Beach Cleanup Standalone',
    'volcano_escape': 'Volcano Escape Standalone',
    'pelican_pedal': 'Pelican Pedal Standalone',
}
RESOURCE_TEXT_SUFFIXES = {'.gd', '.tscn', '.tres', '.gdshader', '.gdshaderinc'}


def extract_game(game_id: str, destination: Path, repository: Path | None = None) -> Path:
    """Validate before creating the destination; preserve the module's resource ABI."""
    if game_id not in GAMES:
        raise ValueError(f'Unknown game ID: {game_id}')
    root = repository or Path(__file__).resolve().parents[1]
    source = root / 'godot/modules' / game_id
    if source.is_symlink():
        raise ValueError('Module source must not be a symlink.')
    if not (source / 'main.tscn').is_file():
        raise ValueError('Module entry main.tscn is missing.')
    dest = destination.resolve()
    if dest.exists():
        raise ValueError('Destination must not exist; extraction will not overwrite another project.')
    if dest.is_relative_to(source.resolve()):
        raise ValueError('Destination must not be inside the source module.')
    module_prefix = f'res://modules/{game_id}/'
    for resource in source.rglob('*'):
        # An archive must never follow a link into the island, another module or user files.
        if resource.is_symlink():
            raise ValueError(f'Module contains a symlink: {resource.relative_to(source)}')
        if not resource.is_file() or resource.suffix not in RESOURCE_TEXT_SUFFIXES:
            continue
        for path in re.findall(r'''res://[^"'\s\)]+''', resource.read_text(encoding='utf-8')):
            normalized = (root / 'godot' / path.removeprefix('res://')).resolve()
            if not path.startswith(module_prefix) or not normalized.is_relative_to(source.resolve()):
                raise ValueError(f'External dependency in {resource.name}: {path}')
    # Copy all module assets and their license/source records, not only runtime extensions.
    shutil.copytree(source, dest / 'modules' / game_id,
                    ignore=shutil.ignore_patterns('.godot', '*.import', '__pycache__'))
    (dest / 'project.godot').write_text(f'''config_version=5
[application]
config/name="{GAMES[game_id]}"
run/main_scene="res://modules/{game_id}/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
window/stretch/mode="canvas_items"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
anti_aliasing/quality/msaa_3d=2
[audio]
driver/enable_input=false
''', encoding='utf-8')
    return dest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('game_id', choices=sorted(GAMES))
    parser.add_argument('destination', type=Path)
    args = parser.parse_args()
    try:
        print(extract_game(args.game_id, args.destination))
    except ValueError as error:
        parser.error(str(error))


if __name__ == '__main__':
    main()
