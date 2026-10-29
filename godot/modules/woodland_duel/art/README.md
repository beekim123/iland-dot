# Woodland Duel runtime artwork

Original, AI-assisted artwork created for **林间牌局 / Woodland Duel** with OpenAI's built-in image generation, then cropped and size-normalized without redrawing the characters. The botanical card-back SVG was authored for this module. No third-party character or card-layout assets are used.

- **21 PNGs, 256 × 256 RGBA:** 18 distinct paper-cut creatures (6 per faction) and 3 faction spell illustrations. Each creature is shared by its hand-card illustration and summoned paper standee.
- `forest_*.png`, `toy_*.png`, and `spore_*.png` are loaded dynamically from `cards.gd`'s `art_key`. The three `*_magic.png` images intentionally serve multiple spells in their faction; their names/rules distinguish each spell.
- Summoned tokens intentionally reuse the corresponding young creature (`toy_mouse` or `spore_sprout`). The temporary sunlight card uses `forest_magic`.
- `card_back.svg` is the original cream-paper / moss-green seed emblem for concealed cards and deck presentation.
- PNGs retain generated transparency, have a clear outer margin, and align their visual bottom near y=246. Render with aspect ratio preserved. These are display-sized runtime resources, not disposable thumbnails.

The PNGs total about **1.79 MiB**; no large source atlas, generation prompt, production script, contact sheet, or preview is included here. Do not remove an image solely because its filename has no literal code reference: `art_key` loads it dynamically.
