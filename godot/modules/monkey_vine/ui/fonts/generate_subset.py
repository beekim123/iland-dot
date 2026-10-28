"""Rebuild OFL Noto SC subset. Requires system fonts-noto-cjk + fontTools.
Generated font is renamed Jungle Sans Subset; OFL license retained alongside.
"""
from pathlib import Path
from fontTools.ttLib import TTCollection
from fontTools import subset
root=Path(__file__).resolve().parents[2]
chars=set(chr(i) for i in range(32,127))
for path in root.rglob('*.gd'):
    chars.update(path.read_text())
chars.update('香蕉林区暂停按住空格抓藤松开飞出上下左右继续冒险检查点重试返回海岛关闭游戏音乐与音效音量丛林小憩安全树枝已抵达下一片存档失败无法保存损坏版本错误权限只读内存进度警告。；：，！？（）…→Ⅱ·')
font=TTCollection('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc').fonts[2]
options=subset.Options(); options.name_IDs=['*']; options.name_legacy=True
sub=subset.Subsetter(options=options); sub.populate(text=''.join(sorted(chars))); sub.subset(font)
for record in font['name'].names:
    if record.nameID in (1,4,6):
        name='JungleSansSubset' if record.nameID==6 else 'Jungle Sans Subset'
        record.string=name.encode(record.getEncoding())
font.save(Path(__file__).parent/'JungleSansSubset.otf')
(Path(__file__).parent/'included_chars.txt').write_text(''.join(sorted(chars)))
