#!/usr/bin/env python3
"""Rebuild the unchanged hub font face with its explicit required-glyph set."""
import argparse
from pathlib import Path
from fontTools import subset

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, default=Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'))
args = parser.parse_args()
hub = Path(__file__).resolve().parents[1]
options = subset.Options()
options.font_number = 0  # Existing approved hub face: Noto Sans CJK JP Regular.
font = subset.load_font(str(args.source), options)
codepoints = [int(item.strip().removeprefix('U+'), 16) for item in (hub / 'tools/font-codepoints.txt').read_text().strip().split(',')]
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=codepoints)
subsetter.subset(font)
subset.save_font(font, str(hub / 'hub-ui.otf'), options)
print(f'Wrote {hub / "hub-ui.otf"} ({len(codepoints)} required codepoints)')
