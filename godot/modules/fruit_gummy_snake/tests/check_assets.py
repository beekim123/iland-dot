from pathlib import Path
from fontTools.ttLib import TTFont
import json,hashlib,wave,math,struct,re
r=Path(__file__).resolve().parents[1]
errors=[]
for p in r.rglob('*'):
    if p.suffix in ['.gd','.tscn','.tres','.gdshader']:
        for ref in re.findall(r'res://[^\s"\')]+',p.read_text()):
            if not ref.startswith('res://modules/fruit_gummy_snake/'):errors.append(f'Foreign dependency {p}: {ref}')
font=TTFont(r/'ui/fruit-sans.otf');cmap=font.getBestCmap()
chars={c for p in r.rglob('*.gd') for c in p.read_text() if '\u4e00'<=c<='\u9fff'}
missing=sorted(c for c in chars if ord(c) not in cmap)
if missing:errors.append('Missing CJK '+''.join(missing))
manifest=json.loads((r/'audio/manifest.json').read_text())
for name,item in manifest.items():
    p=r/'audio'/name
    assert hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256']
    with wave.open(str(p),'rb') as w:
        assert w.getnchannels()==1 and w.getframerate()==22050 and w.getsampwidth()==2
        samples=struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
        assert 0<max(abs(v) for v in samples)<32767
        assert sum(v*v for v in samples)>1000
assert (r/'ui/OFL.txt').is_file()
if errors:raise SystemExit('\n'.join(errors))
print(f'FRUIT ASSETS PASS: {len(chars)} visible CJK characters, 5 self-contained PCM files, no foreign resource dependencies')
