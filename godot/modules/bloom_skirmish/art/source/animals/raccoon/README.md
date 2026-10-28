# Raccoon athlete — original animal replacement

> Publication note: preview/proof PNGs named below are local generated inspection outputs, not checked-in inputs. Recreate them with the retained render/build scripts; editable animal `.blend` and runtime/modeling GLBs are included.
Original Q-version raccoon authored in Blender 4.3.2. All meshes and materials
are locally authored; no textures, external models, downloads, armatures, or
third-party assets are needed. This replaces the human design rather than
putting an animal head on the previous human geometry.

## Character design

- Broad silver-gray cranium, charcoal eye-mask patches, small rounded-triangle
  pinnae, short cream muzzle, black nose, amber eyes, short furry cheeks.
- Compact pear-shaped animal torso, cream belly, short chubby forelegs and hind
  haunches, broad dark paws with blunt digits. No human clothes, shoes, hair,
  skin, fingers, or long human calves.
- Large curved fluffy ringtail with actual alternating material rings.
- Light mineral-white/graphite sports harness, small translucent liquid tank,
  flexible hose, and compact liquid sprayer. Blue/orange change equipment only;
  the natural fur, eye mask, paws, eye colors, and tail remain identical.
- The right forepaw reaches the fixed weapon grip in the unanimated rest pose.

## Rebuild

```sh
blender -b --threads 4 --python art/source/animals/raccoon/build_raccoon.py
```

Append `-- --render` to generate the two local 3/4 proof images. The proof
renderer uses Cycles CPU without denoising because this installed Blender build
does not include OpenImageDenoise. The modeling script only imports geometry
helpers from `art/source/build_athlete.py`; it never calls the human builder or
changes the shared source, preview, gameplay, or UI.

The build writes compressed editable `.blend` files, self-contained two-team
GLBs, and per-team validation JSON. This directory is under `.gdignore`.

## Coordinate and articulation contract

- Authoring uses Godot X-right, Y-up, -Z-forward; helper mapping to Blender is
  `(x, -z, y)`. Ground contact is Y = 0.
- `AthleteRoot` direct children: `Body`, `Head`, `ArmL`, `ArmR`, `LegL`, `LegR`,
  `Weapon`. `Forearm` is below each arm and `Shin` below each leg; Blender makes
  the second same-named node `.001`, which the shared importer normalizes.
- One multi-material mesh per articulated joint: 11 mesh nodes in each GLB.
- Top of cranium approximately 1.438 m; including ears 1.511 m. Main head
  height 0.516 m, with a compact approximately three-head overall silhouette.
- `Weapon` rest = `(0.31, 0.60923076923, -0.29)`.
- `Weapon/Muzzle` = `(0, 0.04, -0.51)`.
- At root scale 1.3 and root Y offset 0.04, the world-space muzzle is
  `(0.403, 0.884, -1.04)`.

Validation JSON records exact current triangle count and bounds. The script
asserts < 40,000 triangles, <= 25 mesh nodes, ground contact, total height, and
muzzle position before export. `validate_glbs.py` independently inspects the
actual GLB bytes, checks hierarchy and contained buffers, and compares natural
material colors across teams.

## Artifacts

- `art/models/animals/raccoon/raccoon_blue.glb`
- `art/models/animals/raccoon/raccoon_orange.glb`
- `art/source/animals/raccoon/raccoon_blue.blend`
- `art/source/animals/raccoon/raccoon_orange.blend`
- `art/source/animals/raccoon/raccoon_{blue,orange}_proof.png`
- `art/source/animals/raccoon/raccoon_{blue,orange}_validation.json`

The studio proof is a local modeling QA image, not a claim of a tested runtime
animation or a replacement for the lead's Godot close-up acceptance capture.

## Repository cleanup (2026-10-28)

Unskinned GLB paths listed above are local generator outputs, not tracked runtime deliverables. Historical exports remain recoverable at Git commit `7b16265`; builders and editable `.blend` inputs remain tracked. Current game and Godot previews use `models/animals/rigged/`. Run the species builder before modeling-stage GLB validation.
