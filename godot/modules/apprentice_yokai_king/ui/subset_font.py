#!/usr/bin/env python3
"""Build module-local SIL-OFL Noto Sans CJK SC subset from installed font.
Usage: python3 ui/subset_font.py [path/to/NotoSansCJK-Regular.ttc]
"""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
import sys
module=Path(__file__).resolve().parents[1]
source=sys.argv[1] if len(sys.argv)>1 else '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
text=''.join(p.read_text() for p in module.rglob('*.gd'))+''.join(chr(i) for i in range(32,127))+'●○←→↑↓'
font=TTFont(source,fontNumber=2)
subsetter=subset.Subsetter(); subsetter.populate(text=text); subsetter.subset(font)
font.save(str(module/'ui/yokai-sans.otf'))
