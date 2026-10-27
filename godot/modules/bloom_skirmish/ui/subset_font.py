#!/usr/bin/env python3
"""Rebuild this isolated module's SC font from its actual displayed source text."""
import argparse
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc'))
    parser.add_argument('--check', action='store_true', help='Verify the current subset without writing files.')
    args = parser.parse_args()
    ui = Path(__file__).resolve().parent
    module = ui.parent
    sources = sorted(module.rglob('*.gd'))
    text = ''.join(path.read_text(encoding='utf-8') for path in sources)
    # ASCII handles runtime-generated numbers and input labels; source characters
    # cover all fixed UI labels without relying on installed runtime fonts.
    required = {ord(c) for c in text if c.isprintable()} | set(range(32, 127))
    target = ui / 'bloom-ui.otf'
    if not args.check:
        options = subset.Options()
        options.font_number = 2  # Noto Sans CJK SC Bold, not the JP face.
        font = subset.load_font(str(args.source), options)
        missing = required - set(font.getBestCmap())
        if missing:
            raise SystemExit('Source font missing codepoints: ' + ', '.join(f'U+{c:04X}' for c in sorted(missing)))
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=required)
        subsetter.subset(font)
        subset.save_font(font, str(target), options)
        (ui / 'font-characters.txt').write_text(''.join(chr(c) for c in sorted(required)) + '\n', encoding='utf-8')
    with TTFont(target) as font:
        missing = required - set(font.getBestCmap())
    if missing:
        raise SystemExit('Subset missing codepoints: ' + ', '.join(f'U+{c:04X}' for c in sorted(missing)))
    print(f'PASS: {len(required)} required glyphs in {target.name}; {len(sources)} module source files inspected')


if __name__ == '__main__':
    main()
