#!/usr/bin/env python3
"""Read-only independent checks: bundled 3D skin, glyphs, audio, self-containment.

This checks objective data only; it does not claim visual approval or listening.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import wave
from fontTools.ttLib import TTFont
import numpy as np

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--module', type=Path, default=Path(__file__).resolve().parents[3] / 'godot/modules/tide_gulp')
module = parser.parse_args().module.resolve()
for path in module.rglob('*'):
    assert not path.is_symlink(), f'Linked external payload: {path}'
    if path.suffix in {'.gd', '.tscn', '.tres', '.gdshader'}:
        for ref in re.findall(r'''res://[^"'\s\)]+''', path.read_text()):
            assert ref.startswith('res://modules/tide_gulp/'), f'Host or foreign dependency: {path}: {ref}'
            assert '..' not in Path(ref.removeprefix('res://')).parts, f'Traversal: {ref}'
models = sorted((module / 'art/fish').glob('*.glb'))
assert len(models) == 11, 'Expected 8 NPC species and 3 prepared player growth meshes'
for model in models:
    payload = model.read_bytes()
    magic, version, length = struct.unpack_from('<4sII', payload)
    assert magic == b'glTF' and version == 2 and length == len(payload), model.name
    json_length, chunk_type = struct.unpack_from('<II', payload, 12)
    assert chunk_type == 0x4E4F534A
    scene = json.loads(payload[20:20+json_length])
    assert scene['skins'] and len(scene['skins'][0]['joints']) == 8, f'{model.name}: not genuinely skinned'
    for mesh in scene['meshes']:
        for primitive in mesh['primitives']:
            attributes = primitive['attributes']
            assert {'POSITION', 'NORMAL', 'JOINTS_0', 'WEIGHTS_0'} <= attributes.keys()
            position = scene['accessors'][attributes['POSITION']]
            extents = [hi - lo for lo, hi in zip(position['min'], position['max'])]
            assert all(size > .01 for size in extents), f'{model.name}: flat/non-3D geometry'
font = module / 'ui/tide-book.otf'
manifest = json.loads((module / 'ui/font_manifest.json').read_text())
assert hashlib.sha256(font.read_bytes()).hexdigest() == manifest['subset_sha256']
coverage = set(TTFont(font).getBestCmap())
required = set(map(ord, '逐潮小鱼'))
for source in module.rglob('*.gd'):
    # Visible quoted Chinese text, not arbitrary comment words or icon glyphs.
    for quoted in re.findall(r'''["']([^"'\n]*)["']''', source.read_text()):
        required.update(ord(ch) for ch in quoted if '\u3400' <= ch <= '\u9fff')
assert required <= coverage, 'Missing UI glyphs: ' + ''.join(map(chr, sorted(required - coverage)))
assert (module / 'ui/OFL.txt').is_file() and (module / 'art/LICENSE.md').is_file()
audio = json.loads((module / 'audio/audio_manifest.json').read_text())
assert len(audio['assets']) == 8
for name, entry in audio['assets'].items():
    path = module / 'audio' / entry['file']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], name
    with wave.open(str(path), 'rb') as reader:
        assert (reader.getnchannels(), reader.getsampwidth(), reader.getframerate()) == (2, 2, 44100)
        data = np.frombuffer(reader.readframes(reader.getnframes()), '<i2').reshape(-1, 2).astype(float) / 32768
    assert np.isfinite(data).all() and np.max(np.abs(data)) < .37
    assert np.max(np.abs(data.mean(axis=0))) < .01
    if entry['loop']:
        assert len(data) == 24 * 44100 and np.max(np.abs(data[0] - data[-1])) < .012
    else:
        assert np.max(np.abs(data[[0, -1]])) < .001
print(f'TIDE ASSETS PASS: {len(models)} real 3D/8-joint GLBs; {len(required)} CJK glyphs; 8 local bounded waveforms; no foreign res dependencies')
