# Original jungle monkey — rigged visual asset

Entry: `monkey.tscn`, root `Visual`, `set_pose(snapshot: Dictionary)`.
Standalone visual review: `preview.tscn` cycles all 7 clips. Review PNGs are **locally regenerated Blender model renders, not gameplay screenshots**; the generated `previews/` directory is not tracked.

## Contract

- Godot +X right, +Y up, camera +Z, XY authoritative gameplay.
- Root is simulation body center, no root-motion tracks. Rest foot bottom approximately -0.32 m (corrected from original -0.55 to match collision radius); physical hand-pair midpoint (0,+0.45,0).
- Default facing right. Wrapper mirrors X for left, never shifts rules position. Grab/swing solve both wrists around the actual grip. `GripMarker` is measured from real hand bone origins, not assigned independently to a fake target.
- A visual-only residual translation cancels import/interpolation error in attached clips. Raw Blender hand-center error before this correction is <0.00000005 m.
- `snapshot` consumes facing, player_pos, player_vel, grounded, vine_id, grip_pos, events. `grab`/`land` are allowed to finish before sustained swing/ground pose. Release immediately selects air/fall.
- Pose selection drives AnimationPlayer. No procedural rules changes. Swing angle is not directly applied to root (prevents body/collider displacement); a baked body/tail flex loop supplies the visual sway.

## Geometry / real deformation

Original rounded pear body, large monkey head, cheek mask, ear disks, eye glints, short limbs, grasping fingers, long curved tail. Not a human model with an animal head.

- 5,208 source vertices, 10,268 triangles, 22 deform bones, 1 exported Skin.
- 500 vertices have blended weights. Arm, leg, and tail tubes use continuous surfaces with interpolated bone weights.
- Acute inside bend triangles use per-face normals instead of misleading averaged normals; default backface culling remains enabled. QA verifies all 10,268 triangles match Godot clockwise convention.
- Clips: idle (2 s), run (.8 s), grab (.4 s), swing (1.6 s), air (1.2 s), land (.6 s), fall (1.2 s).
- Actual evaluated skinned-vertex motion verified for every clip; results in `source/skin_verification.json`. This is not just object rotation. Weights sum to 1 within float tolerance.

## Reproduce / test

```sh
blender -b -t 4 -P modules/monkey_vine/art/character/source/build_monkey.py
blender -b -t 2 -P modules/monkey_vine/art/character/source/verify_skin.py
blender -b -t 4 -P modules/monkey_vine/art/character/source/render_actions.py
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --editor --import --quit
Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://modules/monkey_vine/art/character/test_rig.gd
```

Generated using Blender 4.3.2 and verified with Godot 4.7.2 official `ed1daf0bf`. Source `.blend`, generator, action-render script, license/provenance, stats and hashes retained. Reproduction changes binary metadata but regenerates equivalent geometry/animations. No private user reference is embedded.

2026-10-28 local validation: all 7 clips deform bone poses, real Skin present, both-facing grasp error <1 mm, detach safe. Independent QA script `tools/qa/monkey_vine/audit_rig.gd` also passed 49 assertions (0 inverted faces). Full route/visual gameplay acceptance belongs to runtime/integration QA, not this asset report.
