from pathlib import Path
from fontTools import subset
root=Path(__file__).parent
chars=set(chr(i) for i in range(32,127))
for f in root.parent.rglob('*.gd'): chars.update(f.read_text())
chars.update('拾光海滩月牙湾礁石岬潮汐洲海风小径贝壳浅湾沙丘北南东西站垃圾塑料瓶易拉罐纸盒轮胎木板渔网容量不足距离车厢已满请前往卸货站继续下一片地面剩余生态回归清理完成米次区域')
opts=subset.Options();opts.font_number=2
font=subset.load_font('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',opts)
s=subset.Subsetter(options=opts);s.populate(text=''.join(sorted(chars)));s.subset(font)
subset.save_font(font,str(root/'shore-sans.otf'),opts)
(root/'font-characters.txt').write_text(''.join(sorted(chars)))
