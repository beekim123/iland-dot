from pathlib import Path
from fontTools import subset
root=Path(__file__).parent
chars=set(chr(i) for i in range(32,127))
for f in root.parent.rglob('*.gd'): chars.update(f.read_text())
chars.update('道路即将关闭亭失效落石预警暂避离开召唤飞艇充气灯点亮等待窗口港口已撤离准备南北东西安全信号中断最终分钟阶段教学观察选路撤离')
opts=subset.Options();opts.font_number=2
font=subset.load_font('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',opts)
s=subset.Subsetter(options=opts);s.populate(text=''.join(sorted(chars)));s.subset(font)
subset.save_font(font,str(root/'rescue-sans.otf'),opts)
(root/'font-characters.txt').write_text(''.join(sorted(chars)))
import hashlib, json
from fontTools.ttLib import TTFont
cmap=TTFont(root/'rescue-sans.otf').getBestCmap()
missing=sorted(c for c in chars if ord(c)>=32 and not c.isspace() and ord(c) not in cmap)
(root/'font_manifest.json').write_text(json.dumps({'source':'/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc','collection_face':2,'license':'SIL Open Font License 1.1','subset_sha256':hashlib.sha256((root/'rescue-sans.otf').read_bytes()).hexdigest(),'glyph_count':len(cmap),'missing_source_characters':missing},ensure_ascii=False,indent=2)+'\n')
assert not missing, missing
