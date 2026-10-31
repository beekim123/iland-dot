#!/usr/bin/env python3
"""Static literal save namespace check; dynamic write isolation needs runtime evidence."""
import importlib.util
from pathlib import Path
import re
import sys
ROOT = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[3]
TOOLS_ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('extractor', TOOLS_ROOT / 'tools/extract_game.py')
extractor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extractor)
checked = {}
for game in extractor.GAMES:
    literals = []
    for source in (ROOT / 'godot/modules' / game).rglob('*.gd'):
        if 'tests' in source.relative_to(ROOT / 'godot/modules' / game).parts:
            continue
        for path in re.findall(r'''user://[^"'\s\)]+''', source.read_text()):
            assert path == f'user://games/{game}' or path.startswith(f'user://games/{game}/'), (game, source, path)
            assert '..' not in path.split('/'), (game, path)
            literals.append(path)
    assert literals, f'No literal private save path found: {game}'
    checked[game] = sorted(set(literals))
print('CURRENT_PRIVATE_LITERAL_NAMESPACES_PASS:', checked)
