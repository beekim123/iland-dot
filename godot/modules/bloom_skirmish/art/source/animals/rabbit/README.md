# Original Q-version rabbit athlete

> Publication note: preview/proof PNGs named below are local generated inspection outputs, not checked-in inputs. Recreate them with the retained render/build scripts; editable animal `.blend` and runtime/modeling GLBs are included.
Authored with **Blender 4.3.2**, using self-contained procedural mesh construction.
No external meshes/textures or human-character builder are used.

## Deliverables

- `build_rabbit.py`: complete reproducible geometry/material/hierarchy source.
- `rabbit_blue.blend`, `rabbit_orange.blend`: compressed editable Blender sources, including an inspection camera and studio lights.
- `../../../models/animals/rabbit/rabbit_blue.glb` and `rabbit_orange.glb`: standalone embedded production exports (studio excluded).
- `rabbit_{blue,orange}_held_closeup.png`: common-runtime idle pose, front three-quarter.
- `rabbit_blue_rear_tail.png`: back three-quarter, showing reservoir and round tail.
- `validate_rabbit.py` / `validation_report.json`: independent exported-GLB checks.
- `rabbit_{blue,orange}_qa.json`: Blender authored-geometry checks.

This directory is deliberately excluded from Godot import via `.gdignore`.

## Reproduction

Run from the project `godot` directory:

```sh
blender -b --python modules/bloom_skirmish/art/source/animals/rabbit/build_rabbit.py -- --skip-render
python modules/bloom_skirmish/art/source/animals/rabbit/validate_rabbit.py
blender -b --python modules/bloom_skirmish/art/source/animals/rabbit/render_rabbit.py
```

The renderer poses a temporary scene without saving pose changes into the source or GLB.

## Model and technical contract

- True ivory/warm light-grey fur; cream cheeks/belly and peach inner ears.
- Large round head (top **1.493 m**) and expressive asymmetrical long ears (top **1.940 m**).
- Round haunches, compact short forepaws, elongated rabbit hindfeet, small round tail.
- Approximately **2.58 heads** tall excluding ears; no human chin, hair, clothing silhouette, hands, or long limbs.
- Lightweight short harness/side vest with graphite/mineral-white equipment. Only team equipment and contained liquid switch between cobalt blue and orange; animal geometry and all fur materials remain identical.
- **11 joined articulated meshes / 35,784 triangles** per team. Authored components are joined per pivot, retaining material slots rather than exporting hundreds of objects.
- Ground root `AthleteRoot` at Y=0, Godot X-right/Y-up/-Z-forward (Blender `(x,-z,y)`).
- Direct nodes: `Body`, `Head`, `ArmL`, `ArmR`, `LegL`, `LegR`, `Weapon`.
- Each arm has a `Forearm`; each leg has a `Shin` (Blender duplicate-name suffixes are normalized by the shared Godot factory).
- This source is the articulated modeling base. Any actual skin/armature outputs are owned separately under the shared rigging pass, not falsely claimed here.

## Compact paw grip and unchanged nozzle

Natural upper-torso shoulder: `(±.257, .875, -.005)`.
Right `Forearm`: `(.028, -.132, -.028)`; its palm marker `Grip`: `(0, -.069, -.015)`.
With shared idle X rotations `ArmR=.50`, `Forearm=.70`, the palm center is:

`(.285, .761560918, -.162602546)`.

The new compact rear/top U-grip is centered exactly there, while the small receiver remains forward/below it. No unreachable hanging human pistol handle, elongated arms, or waist-level shoulders.

Unchanged weapon rest: `(.31, .60923076923, -.29)`.
Unchanged child muzzle: `(0, .04, -.51)`.
Runtime root scale 1.3 and root Y offset .04 yield physical nozzle:

`(.403, .884, -1.04)`.

The GLB validator checks palm/grip coincidence, nozzle, hierarchy, embedded buffers, mesh/triangle budget, ground/ear bounds, identical animal geometry, and unchanged natural fur across teams.

## Additional contact QA

`check_grip_envelope.py` samples the shared idle/run/dash/shooting equations over 30 seconds at 5 ms intervals (72,012 parameter/time samples). The largest sampled paw-center to grip-center distance is **0.04376 m**, less than the compact paw's conservative **0.083 m** radius. This only establishes analytical contact tolerance; the art lead owns actual Godot import/runtime checks.
