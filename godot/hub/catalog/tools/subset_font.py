from pathlib import Path
import hashlib,json
from fontTools import subset
root=Path(__file__).resolve().parents[1]
# Explicit UI and registration vocabulary; scan only owned source plus public registry text.
text=''.join(p.read_text() for p in root.rglob('*.gd'))+(root.parents[1]/'app/game_registry.gd').read_text()
text+='晴贝小岛全部游戏现在就玩新作筹备轻松休闲动作对战冒险竞速软糖爆爆岛绒芽争园逐潮小鱼拾光海滩火山岛逃生鹈鹕顺风车果园长长蛇重做中筹备中未开放'
chars=set(text)|set(chr(i) for i in range(32,127))
source=Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc')
options=subset.Options();options.font_number=2
font=subset.load_font(str(source),options);ss=subset.Subsetter(options=options);ss.populate(unicodes=[ord(x) for x in chars]);ss.subset(font);subset.save_font(font,str(root/'catalog-sans.otf'),options)
(root/'font-manifest.json').write_text(json.dumps({'source':str(source),'face':'Noto Sans CJK SC Regular','codepoints':sorted(ord(x) for x in chars),'sha256':hashlib.sha256((root/'catalog-sans.otf').read_bytes()).hexdigest()},indent=2))
