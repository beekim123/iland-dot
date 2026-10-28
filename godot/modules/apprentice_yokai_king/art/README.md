# Apprentice Yokai King — original AI-assisted 2D artwork

Created 2026-10-28 using built-in `image_gen` (not API fallback). These are painted bitmap assets, not procedural geometric character stand-ins. Reference language: pale sage arena, rounded plum outlines, large eyes and short limbs. No Poteto website artwork, code, character identities, logos or downloads are reused. This is a project-origin provenance statement, not a claim that AI output has exclusive copyright protection.

## Runtime contract
- `hero.png`: RGBA 1024×2048; 4 columns ×8 rows; cell 256². Rows: idle, move, light, charge, slam, dodge, hurt, defeat. Four distinct painted poses in each row; hero faces right. Horizontal mirror permitted. Ground anchor (128,220); no sprite rotation needed.
- `grunt/shield/spring/bubble/sleeper/boss.png`: RGBA 256², grounded anchor (128,220), face left. `elite.png` intentionally uses the grunt art; runtime enlarges it as the design specifies.
- `*-strip.png`: four cells 256² horizontally, semantic poses idle/walk/anticipation/attack, NOT a four-frame seamless walk cycle. Runtime should select according to actual enemy state. Do not claim full enemy locomotion cycles.
- `arena.png`: RGB 1280×800; open meadow with decoration outside central battle area.
- `ui/`: twelve upgrade symbols matching design card order and four decorative panel/heart assets. Panel artwork can be stretched/nine-sliced cautiously, with text supplied by runtime.
- Wooden mallet is baked into painted hero poses. Its hand grip follows each pose, not a separate runtime rotational weapon pivot. Gameplay hit origin must remain at runtime aim/ground position. Foot anchors are manually reviewed per pose; falling/rolling images retain the same ground location.

## QA and corrections
The first hero sheet had touching swing cells and an extra hurt pose. The light-attack row was regenerated separately and replaced with four complete unclipped poses. Hurt uses four distinct poses. Deterministic connected-component cleanup removes neighbouring sprite contamination; manual foot coordinates align bodies instead of centering the enormous weapon bounding box. All 32 runtime hero frame hashes are distinct (`manifest.json`).
Enemy generation and one transparency edit retained an unwanted colored background. Do not describe those source files as clean transparent production art. Runtime enemy transparency is extracted deterministically from enclosed dark outline masks, with per-cell component cleanup and a minor mask cutoff removing an adjacent background remnant. No character was redrawn procedurally. Final sheets were visually inspected; thin anti-aliased outlines and spring legs remain. This is a first-production art set, not an assertion that all animation polish or runtime playtesting is finished.

## Reproduction
Python 3, Pillow, NumPy and SciPy. Run `python art/build_atlas.py` from any cwd to regenerate hero/enemies/arena from preserved sources. Run `python art/build_ui.py` to regenerate UI. `normalize_hero.py` records source crop/foot coordinates; `manifest.json` records exact normalized hero frame hashes. Source files are preserved under `sources/` and never needed at runtime.

`hero-actions-preview.gif` is an asset-only animation preview, not a gameplay recording. Runtime integration and screenshots are owned by the gameplay task.

## Prompt set / built-in generation record
1. Hero: original tiny pale-gold yokai king, asymmetric plum horns, short plum cape, huge barrel wooden mallet, expressive eyes; clean rounded dark-plum outlined flat 2D; near-top-down/right-facing; transparent 4×8 sheet, four distinct poses per idle/walk/light/charge/slam/dodge/hurt/defeat. No copied IP, pixel art, clay, gummy or island theme.
2. Arena: 1280×800 near-overhead pale sage meadow, sparse grass/cream flowers, low contrast, perimeter rounded rocks/shrubs/posts with entry gaps; central 85% unobstructed; no text/UI/characters.
3. Enemies: original 4×6 sheet of coral horned fist imp, mint leaf shield imp, lavender spring-legged jumper, ochre trumpet-mouth bubble creature, blue pillow sleepy creature, asymmetric-horned plum broad-belly boss. Four distinct idle/walk/anticipation/attack poses. Left-facing, flat outlined 2D, requested transparent.
4. Enemy transparency repair: preserve all 24 sprites/positions/details and remove only background; output did not meet full transparency requirement, so deterministic mask extraction was applied and disclosed above.
5. UI: transparent 4×4 sheet, first twelve cream circle badges for wind, speed, return, thunder, chain, charge, quake, slow, echo, handle, elastic, roll; last row blank cream card, mint title panel, wooden score panel, heart; plum outlines, no text.
6. Light repair: same hero reference identity, four complete right-facing anticipation/sweep/extension/recovery poses, one horizontal row, generous transparent separation; preserve mallet, horns and cape; no scenery/text.
