# Original clay otter traveler

Original animal hero for Volcano Escape (not adapted from previous games). Cocoa fur, oat muzzle/bib, lagoon-blue helmet, apricot lamp backpack, slate boots. 1.288 m high; Y-up, forward -Z; yaw follows gameplay heading directly. Nominal gameplay collision radius .33 m; visual ears and articulated rear tail intentionally extend beyond collision.

## Integration

Instantiate `otter.tscn`. Call `set_motion(speed, dt)` with world m/s, and `set_state(state, progress=0.0)` for `idle`, `walk`, `shelter`, `interact`, `hurt`, `victory`. `sheltered`/`bracing` alias shelter; `success` aliases victory. Caller controls state duration. Clips crossfade; imported AnimationPlayer drives real Skeleton3D + Skin, not rigid per-part bobbing. Torso, paws, and continuous tapered three-joint tail contain blend weights. Headgear/backpack follow head/spine bones.

## Source and budget

`source/otter.blend` is editable Blender 4.3 source; `source/build_otter.py` regenerates source and GLB with `/usr/bin/blender --background --factory-startup --python source/build_otter.py`. Source is deliberately .gdignore'd so clean Godot imports do not require Blender. No textures or external palette imports. Seven rough PBR materials are embedded in GLB. `audit.json`: 5,706 indexed triangles, 7 surfaces, 14 bones, 2,935 weighted vertices, 382 blended vertices, no zero-area or reversed faces. This is a geometry budget, not a measured FPS claim.

## Verification

- `python tests/check_glb.py`: binary accessors, indexed/non-indexed face path, finite nonnegative normalized weights, inverse skeleton joint ranges, bounds, surface/triangle budgets, winding, degeneracy, six action names.
- Godot 4.7.2 `--headless --path <project> --script res://modules/volcano_escape/art/character/tests/test_character.gd`: fresh import, real Skeleton3D/Skin, all six clips change >=3 bones, walk changes 14, actual skin-matrix deformation moves 1,503–2,935 vertices per clip, state/motion routing.
- `preview.tscn`: GUI-only visual review. CLI `-- --preset=hero --output=/absolute/path.png`; presets hero/side/walk/interact/shelter/hurt/victory. Capture uses actual viewport after `RenderingServer.frame_post_draw`, never a headless substitute. Neutral ambient + bounded directional shadow; camera .1–12 m clipping avoids large-scene shadow stripes. Parent task owns real GUI captures and visual acceptance.
