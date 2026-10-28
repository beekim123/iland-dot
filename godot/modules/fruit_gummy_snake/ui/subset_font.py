from pathlib import Path
from fontTools import subset
root=Path(__file__).parent
chars=set(chr(i) for i in range(32,127))
for p in root.parent.rglob('*.gd'):chars.update(p.read_text())
opts=subset.Options();opts.font_number=2
font=subset.load_font('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',opts)
s=subset.Subsetter(options=opts);s.populate(text=''.join(sorted(chars)));s.subset(font)
subset.save_font(font,str(root/'fruit-sans.otf'),opts)
(root/'font-characters.txt').write_text(''.join(sorted(chars)))
