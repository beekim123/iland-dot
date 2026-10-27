# Actual skinned cartoon-animal cast

This directory contains the **real skeletal rigging pass**, not the earlier Empty/node-based articulation. The approved fox, otter, raccoon and rabbit geometry is read from `../<species>/<species>_<team>.blend`; those original files and their original GLBs are never overwritten.

## Outputs and runtime contract

- Runtime: `art/models/animals/rigged/<species>/<species>_<team>_rigged.glb`.
- Editable source: `<species>/<species>_<team>_rigged.blend` here.
- Each GLB embeds its mesh/material/skin/animation data and uses no external textures, models or third-party assets.
- Authored root `AthleteRoot` contains `CharacterRig` and independent `Weapon`.
- Godot imports an actual `CharacterRig/Skeleton3D`, with 24 bones (rabbit: 23), `Skin` resources and weighted mesh surfaces. It places weighted meshes under the skeleton. An import wrapper root can precede `AthleteRoot`.
- The actual `AnimationPlayer` is on the imported GLB wrapper root. Runtime should search recursively rather than hard-code that wrapper's filename-derived name.
- Bone names retain periods: `UpperArm.R`, `Forearm.R`, `Hand.R`, and corresponding `.L`; `Thigh`, `Shin`, `Foot`; `Root`, `Pelvis`, `Spine`, `Chest`, `Head`; linked `Tail.01` etc.; `EarBase.L/R`, `EarTip.L/R`.
- **The head/origin of `Hand.R` is the actual palm center**, matching `Weapon/GunGrip`. The `Forearm.R` tail matches that joint too.
- Nine real bone clips: `idle`, `run`, `spray`, `dash`, `hit`, `pod`, `respawn`, `celebration`, `defeat`. Runtime loops idle/run/spray/celebration as appropriate, treats the remaining event clips as one-shots, and manually advances using game time so pause freezes them. `celebration` is the victory mapping.

### Fixed emitter and independently aimed nozzle

`Weapon` stays at authored Godot location `(0.31, 0.60923076923, -0.29)`. Its direct children `Muzzle` and `AimNozzle` share local position `(0, 0.04, -0.51)`. Thus at runtime scale 1.3/root Y 0.04, physical muzzle is exactly `(0.403, 0.884, -1.04)`.

Rotate **only `Weapon/AimNozzle.rotation.x`** for the accepted pitch range `[-0.75, +0.70]`. `Muzzle`, the receiver, the rear grip and `GunGrip` do not move. This is an authorized sprayer structural refinement: the old front rings are replaced by an original compact rear hemispherical joint and open annular nozzle. The original fixed barrel enters that spherical envelope; no long flexible tube or impossible arm stretch is used.

Do not rotate the whole Weapon or apply the old Arm/Body node animation to these assets.

## What is skinned

Original torso vertices blend between pelvis/spine/chest; elbow/wrist and knee/ankle transition vertices blend between adjacent limb bones; species tails and ears have multi-bone follow-through. Every deform mesh has named vertex groups and a real Armature modifier. The head, paw/sole islands, hard backpack and other hard details retain appropriate rigid regions **inside the skin**, preserving volumes instead of flattening paws. Thousands of vertices have two or more weights greater than one percent; this is not a collection of bone-parented rigid objects.

Right arms use an analytical two-segment solution each sample. Overlarge torso poses are reduced to reachable short-animal-arm poses; free-hand goals respect both minimum and maximum chain reach. No limb bone is lengthened. Every bone's animated scale is one. Breathing comes from chest translation through blended torso skin, avoiding tiny nonuniform-scale compensation tracks that importers might remove.

Fox's original linear `Col` palette is converted face-for-face to standard PBR base-color materials and removed from the exported vertex attributes. **Do not apply the old vertex-color gamma workaround to these PBR rigged assets.** Natural fur is unchanged between teams; team differences are equipment only.

## Reproduction

Blender 4.3.2, Python bundled with Blender; Godot 4.7.2 for validation.

```sh
blender -b --python art/source/animals/rigging/build_rigs.py -- --species otter --team both
# Repeat with fox, raccoon and rabbit.
python art/source/animals/rigging/validate_glb.py
blender -b --python art/source/animals/rigging/validate_poses.py -- otter
blender -b --python art/source/animals/rigging/render_rig.py -- otter
```

The builder exports to a temporary filename and atomically replaces the final GLB, so import readers do not encounter partial bytes. Original source hashes, output hashes, weighting counts, analytical reach checks and gait parameters are in each `*_rig_report.json`.

Inspection PNGs and contact sheets are local generated evidence and are not included in the source publication; `render_rig.py` reproduces the individual frames.

`render_rig.py` adds a **source-only** CPU Cycles inspection studio after reopening the rigged source. Its PNGs are pose/shape evidence, not claims of Godot game appearance, and the studio is never exported to game files.

## Independent checks

- `validate_glb.py`: parses binary GLB accessors; verifies embedded data, skin/joint references, normalized weights, genuine multi-bone vertices, nonconstant joint animation channels, required clips and seamless looping endpoints.
- `validate_poses.py`: reopens saved `.blend`, samples every animation frame, verifies actual palm/grip and joint positions, bone lengths, Armature modifiers, and the final evaluated hindpaw mesh above the ground plane.
- `probe_rig.gd`: imports the actual GLB into an isolated headless Godot project; verifies `Skeleton3D`, `Skin`, surface bone/weight arrays, real animation tracks, actual animated Hand.R palm versus GunGrip, and independent nozzle pitch with zero emitter/grip movement. The calibrated run contact check measures the **actual imported foot-bone motion**, including sub-frame interpolation, not just authored markers or claimed stride.
- The parent QA task additionally owns real non-headless Godot native CPU skin baking and the integrated gameplay/animation recordings. Those independent results are not replaced by these source checks.

Small floating-point errors are reported honestly. An entirely new game scene, a clean aggregate gameplay pass or publication is outside this directory's validation claims.

### Final running contact calibration

All four species use a 0.6-second cycle with 6 of 18 authored frames in stance (one third), followed by a longer lifted swing and a brief whole-body airborne bounce. Half-stride is `4.6 × 0.2 / (2.6 × 1.3) / 2 = 0.1360946746` model units. At game playback rate 2.6 and actor scale 1.3, the intended planted-foot backward velocity is 4.6 world units/second; the runtime scales playback proportionally below full movement speed. Swing lift is 0.12 for rabbit, 0.09 for raccoon and 0.10 for otter/fox. The paw/sole remains a volume-preserving foot region; limbs retain their original bone lengths.

Authoring-frame errors and arbitrary-time imported errors are different measurements. The source/keyframe palm errors are near floating-point precision; ordinary quaternion/translation interpolation can introduce small sub-frame residuals. Godot's dense raw-GLB probe uses a **3 mm model-space maximum palm/grip tolerance**, matching the separate integrated QA threshold, rather than claiming all interpolated times are exact. Contact-slip measurements are separately reported in world units at the reference speed.

`validate_palette.py` independently reopens both original fox sources, reads each face's original linear Col value, then compares every corresponding rigged body/head/limb face's assigned PBR base color. It checks the **face assignment**, not merely the presence of a palette material list. The authorized replacement swivel nozzle is excluded from that original-color comparison.
