"""Rebuild/check the module-owned OFL CJK subset. Requires fontTools."""
from pathlib import Path
import argparse,hashlib,json
from fontTools import subset
from fontTools.ttLib import TTFont
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');p.add_argument('--source',default='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc');a=p.parse_args()
root=Path(__file__).resolve().parents[1];out=root/'ui/pelican-sans.otf'
chars=set(chr(i) for i in range(32,127))
for file in root.rglob('*.gd'):chars.update(file.read_text())
required={ord(c) for c in chars if ord(c)>=32 and (not c.isspace() or c==' ')}
if not a.check:
 opts=subset.Options();opts.font_number=2
 f=subset.load_font(a.source,opts);sub=subset.Subsetter(options=opts);sub.populate(unicodes=required);sub.subset(f);subset.save_font(f,str(out),opts)
 (root/'ui/font-manifest.json').write_text(json.dumps({'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'codepoints':sorted(required)},indent=2))
f=TTFont(out);missing=required-set(f.getBestCmap());assert not missing,missing
saved=json.loads((root/'ui/font-manifest.json').read_text());assert saved['sha256']==hashlib.sha256(out.read_bytes()).hexdigest()
print('PELICAN FONT PASS',len(required),'codepoints')
