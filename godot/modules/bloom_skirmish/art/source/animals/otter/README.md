# Original cartoon otter athlete

> Publication note: preview/proof PNGs named below are local generated inspection outputs, not checked-in inputs. Recreate them with the retained render/build scripts; editable animal `.blend` and runtime/modeling GLBs are included.
Original Blender 4.3.2-authored model for Bloom Skirmish. Natural chestnut/cream
otter fur is identical in both teams; only the equipment accents and liquid
change between cobalt blue and orange. No downloaded meshes, textures, fonts,
stock assets, or external texture dependencies.

## Shape and materials

- Compact 2.5-head chibi river otter: small rounded ears, round head, broad pale
  paired whisker pads, beadlike rounded triangular nose, bright cocoa eyes.
- Long rounded/pear torso with pale belly, naturally short animal forepaws and
  wide short hind paws. No human face, hair, pants, boots, or human long legs.
- Broad muscular tail root, continuously tapered flattened swimmer's tail.
- Minimal graphite/mineral-white sport harness leaves the belly and species
  silhouette clear. Compact translucent tank has an interior colored fill,
  air gap, level ticks, white endcaps, and a short supply hose.
- The compact sprayer has an animal-specific **rear/top transverse U grip**.
  It is not the human-style hanging pistol grip. Both shoulder pivots retain
  their natural high chest-side positions.

## Files

- `build_otter.py` — deterministic full geometry/material authoring and export.
- `otter_blue.blend`, `otter_orange.blend` — compressed editable Blender source,
  all anatomical pivots in zero-rotation rest pose. Original surface topology
  is retained in the merged per-pivot mesh objects with named material slots.
- `render_otter.py` — source-only articulated closeups and rear/tail inspection.
- `otter_*_held_closeup.png` — front three-quarter **actual common idle pose**.
- `otter_blue_rear_tail.png` — back three-quarter tail and tank inspection.
- `validate_otter.py`, `validation_report.json` — independent binary GLB QA.
- `otter_*_qa.json` — Blender scene geometry measurements.
- Runtime deliverables: `../../../models/animals/otter/otter_{blue,orange}.glb`.

## Reproduce

From the repository's `godot/modules/bloom_skirmish` directory:

```sh
blender -b --python art/source/animals/otter/build_otter.py
# Or skip studio rendering while rebuilding the GLB and editable blend files:
blender -b --python art/source/animals/otter/build_otter.py -- --skip-render
python art/source/animals/otter/validate_otter.py
blender -b --python art/source/animals/otter/render_otter.py
```

The `.gdignore` source marker excludes Blender source, preview renders, and
scripts from Godot asset imports. No source from other species is modified.

## Runtime contract and verified limits

- Godot coordinates: X right, Y up, -Z forward. Blender mapping `(x,-z,y)`.
- Root `AthleteRoot`; exact direct children `Body`, `Head`, `ArmL`, `ArmR`,
  `LegL`, `LegR`, `Weapon`.
- `Forearm` beneath each arm; `Shin` beneath each leg. Blender's second same-name
  joints carry `.001`, normalized by the existing runtime factory.
- **11 mesh objects; 38,080 triangles per GLB; 1.463 m head top; foot sole Y=0.**
- Weapon local rest: `(0.31, 0.60923076923, -0.29)`.
- Muzzle local: `(0, 0.04, -0.51)`.
- After runtime scale 1.3 and root Y=0.04, muzzle is `(0.403, 0.884, -1.04)`.
- ArmR root: `(0.257, 0.862, -0.005)`.
- Right Forearm local: `(0.028, -0.132, -0.028)`.
- Right Forearm `Grip` local: `(0, -0.069, -0.015)` (center of short forepaw).
- Weapon `Grip.001` local: `(-0.025, 0.139330148912, 0.127397453922)`.
- In common idle `ArmR.rotation.x=+0.50`, `Forearm.rotation.x=+0.70`, the two
  grip markers coincide at `(0.285, 0.748560918142, -0.162602546078)`.
  This equality is asserted by the GLB validator. GLB rest pose is deliberately
  unrotated; use common animation when reviewing the held weapon.

GLBs contain one embedded binary buffer each, no external images/materials,
no cameras/lights, and no animation dependency. Front and rear studio images
are inspection aids only, not an environment or UI redesign.

## Repository cleanup (2026-10-28)

Unskinned GLB paths listed above are local generator outputs, not tracked runtime deliverables. Historical exports remain recoverable at Git commit `7b16265`; builders and editable `.blend` inputs remain tracked. Current game and Godot previews use `models/animals/rigged/`. Run the species builder before modeling-stage GLB validation.
