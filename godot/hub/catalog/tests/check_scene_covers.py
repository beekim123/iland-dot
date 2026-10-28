"""Verify exact native capture provenance, bindings, PNG validity and visible label glyphs."""
from pathlib import Path
import hashlib,json
from PIL import Image
from fontTools.ttLib import TTFont
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'covers/manifest.json').read_text())
capture=json.loads((root/'covers/native-capture-manifest.json').read_text())
assert capture['passed'] and len(capture['captures'])==5
expected={'gummy_bomber','bloom_skirmish','tide_gulp','beach_cleanup','volcano_escape'}
assert set(manifest['covers'])==expected
original={v['game_id']:v for v in capture['captures']}
script=(root/'game_catalog.gd').read_text()
for name in expected:
    entry=manifest['covers'][name]; record=original[name]; path=root/'covers'/f'{name}.png'
    digest=hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest==entry['source_png_sha256']==entry['image_sha256']==record['sha256'],name
    assert not record['camera_overrides'] and not record['state_overrides'] and not record['scripted_movement'],name
    assert record['frames_waited']>=48 and record['normal_runtime_wall_ms']>=4500 and record['hidden_ui_only'],name
    with Image.open(path) as image:
        image.load();assert list(image.size)==record['size']==entry['size'];assert image.convert('RGB').getcolors(maxcolors=100) is None,name
    assert f'"{name}":"res://hub/catalog/covers/{name}.png"' in script,name
assert '"场景预览" if COVERS.has(id) else "主题图标"' in script
font=TTFont(root/'catalog-sans.otf');codepoints=font.getBestCmap()
assert all(ord(ch) in codepoints for ch in '场景预览主题图标')
font.close()
print('CATALOG NATIVE COVER PASS: 5 PNG files byte-identical to actual native capture; honest labels and glyphs verified')
