# Art QA evidence (2026-10-27)

## Passed in actual Godot 4.7.2 headless

- All nine runtime species instantiate with a real `Skeleton3D`, 8 bones, and a `Skin` binding resource.
- Each fish uses one mesh surface / one pigment material.
- Head and tail poses differ, with the eight-bone rest orientation retained.
- CPU evaluation of the actual imported skin matrices verifies finite, horizontally oriented skinned bounds after simultaneous swim, turn, open-mouth and dash poses.
- Six player stages reuse three pre-instantiated models; stage changes do not add or destroy nodes.
- All three ecologies instantiate; a separate nine-case check spans three bound positions/sizes, verifies exact obstacle XY bounds and decorative geometry behind z=-2.
- 64 NPC fish + 1 player setup took 26 ms in one local headless run. 120 iterations of all 65 pose updates took 41 ms. This is **CPU-only microbenchmark evidence, not a rendered/browser FPS claim**.

## Visual review

The initial real GUI screenshot caught a pose bug: `set_bone_pose_rotation` had replaced the imported root-bone rest rotation. This was fixed in the shared runtime art script by composing `rest_rotation * animation_delta`, not by rotating the preview. The regression check now explicitly guards the imported rest orientation and evaluates the final skinned vertices. The preview hero root has zero additional yaw.

Round scalloped coral fans replaced the initial bare-branch fan geometry following first-frame review. Low-contrast moving current brush marks were added behind the active plane.

The second real GUI frame (`tide-watercolor-v2.png`) confirmed correct +X orientation and the watercolor style. It exposed an independent dorsal-fin root separation. This was fixed for all eleven meshes by topologically welding dorsal and ventral membranes to existing body surface vertices; root geometry and weights are now literally shared. The six growth stages are tested through 16 simultaneous swim/turn/mouth/dash poses each. The v3 real Godot frame (`build/previews/tide-watercolor-v3.png`) has now been inspected: +X orientation and connected dorsal/ventral fin silhouettes are correct. The real gameplay frame (`build/previews/tide-gameplay-first.png`) also shows the art integrated at playable scale. Nine-species/reverse-side gallery graphics review is still pending root capture. Do not use the first (vertical) or second (floating-fin) frame as final evidence.
