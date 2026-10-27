#!/usr/bin/env python3
"""Rebuild and audit the module-local OFL Chinese book face.

Usage: python3 subset_font.py [--source /path/to/NotoSerifCJK-Regular.ttc]
fontTools is a build dependency only. Runtime never uses system fonts.
"""
import argparse
import hashlib
import json
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont

HERE = Path(__file__).resolve().parent
MODULE = HERE.parent
EXTRA = "逐潮小鱼小小水滴银鳍幼鱼珊瑚游鱼逐浪大鱼深蓝领航海洋朋友洋流将至顺流逆流潮水来了躲进礁石安静海湾珊瑚花园蓝色远海小银鱼珊瑚鱼月光鱼斑斓鱼远洋鱼蓝鲸星点幼鱼小溪银鳞珊瑚穿梭逐浪游侠深海领航潮汐巨影点点鱼小鳍鱼条纹鱼圆尾鱼大蓝鱼海之星离开水面躲开大鱼再试一次鱼苗小鱼游鱼大鱼巨鱼海洋霸主全成长已满成长洋流退去避开尖角鱼生存时间个人最佳本次最高成长"

def requested_chars():
    text = EXTRA + ''.join(chr(i) for i in range(32, 127))
    for path in sorted(MODULE.rglob('*.gd')):
        text += path.read_text(encoding='utf-8')
    return {ord(c) for c in text if not c.isspace()} | {32}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', default='/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc')
    args = parser.parse_args()
    source = Path(args.source)
    font = TTFont(str(source), fontNumber=2)
    font.recalcTimestamp = False
    available = font.getBestCmap()
    chars = requested_chars()
    missing = sorted(chars - set(available))
    if missing:
        raise SystemExit('Source is missing requested characters: ' + repr(''.join(map(chr, missing))))
    options = subset.Options()
    options.name_IDs = ['*']
    options.name_legacy = True
    options.name_languages = ['*']
    options.notdef_glyph = True
    sub = subset.Subsetter(options=options)
    sub.populate(unicodes=chars)
    sub.subset(font)
    names = {1: 'Tide Book UI', 2: 'Regular', 3: 'TideBookUI-Regular-20261027', 4: 'Tide Book UI Regular', 6: 'TideBookUI-Regular', 16: 'Tide Book UI', 17: 'Regular'}
    for record in font['name'].names:
        if record.nameID in names:
            record.string = names[record.nameID].encode(record.getEncoding())
    out = HERE / 'tide-book.otf'
    font.save(out)
    actual = set(TTFont(str(out)).getBestCmap())
    assert chars <= actual
    (HERE / 'font_manifest.json').write_text(json.dumps({
        'family': 'Tide Book UI', 'upstream': 'Noto Serif CJK SC Regular',
        'source_url': 'https://github.com/notofonts/noto-cjk/tree/main/Serif',
        'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
        'source_face_index': 2, 'license': 'SIL Open Font License 1.1',
        'subset_sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
        'glyph_coverage_count': len(chars), 'missing_codepoints': [],
        'rebuild': 'python3 ui/subset_font.py --source /path/to/NotoSerifCJK-Regular.ttc',
        'runtime_system_font_dependency': False,
    }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'TIDE_FONT_OK: {len(chars)} codepoints, {out.stat().st_size} bytes, no missing glyphs')

if __name__ == '__main__':
    main()
