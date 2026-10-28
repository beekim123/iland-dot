# Bloom Skirmish — original chibi fox athlete

> Publication note: preview/proof PNGs named below are local generated inspection outputs, not checked-in inputs. Recreate them with the retained render/build scripts; editable animal `.blend` and runtime/modeling GLBs are included.
Authoring tool: **Blender 4.3.2**. This animal was newly modeled for the animal-only visual direction. There are **no external models, textures, stock assets, human heads, human body meshes, copied character designs, or image-generated assets**.

## Deliverables

- `fox_blue.blend`, `fox_orange.blend`: compressed editable Blender sources.
- `build_fox.py`: reproducible modeling/export source. Imports only geometric helper functions from `../../build_athlete.py`; never calls its human `build` function.
- `../../../models/animals/fox/fox_blue.glb`, `fox_orange.glb`: self-contained GLBs with embedded geometry and vertex palette; no sidecar files or texture dependencies.
- `verify_fox.py`, `validation.json`: standalone structural/geometry tests and their results.
- `render_fox.py`, `fox_blue_studio.png`, `fox_orange_studio.png`: temporary studio QA renderer and its ready-pose 3/4 preview. Staging objects are not saved into exported model files.

Run from project `godot/modules/bloom_skirmish`:

```sh
blender -b --python art/source/animals/fox/build_fox.py
python art/source/animals/fox/verify_fox.py
blender -b --python art/source/animals/fox/render_fox.py -- blue
```

`source/animals/fox/.gdignore` prevents Blender authoring files from Godot auto-import.

## Animal design

Warm rust-orange full fox fur, cream protruding muzzle/cheek fans/throat/belly, triangular pointed ears, dark nose and furry distal paws, jade eyes, and a large continuous white-tipped brush tail. Compact 2.5-head-height animal anatomy replaces the old human design. A cropped graphite sport vest, simple liquid-drop badge, small translucent nectar reservoir, and rounded sprayer communicate greenhouse competition without plush-island or candy styling. Team colors appear **only on equipment**; both variants have identical species geometry and fur palette.

The right forepaw is specifically shaped to envelop the fixed grip in the public animation's shoulder `0.50` / elbow `0.70` ready pose. The left arm remains free for locomotion/gestures. Knees/elbows have overlapping fur geometry so the rigid articulation does not expose a hole.

## Export/animation contract

- Game coordinates: Y-up, ground exactly `Y=0`, forward `-Z`; Blender coordinates `(x,-z,y)`.
- Root: `AthleteRoot`; direct animated children: `Body`, `Head`, `ArmL`, `ArmR`, `LegL`, `LegR`, `Weapon`.
- Nested `Forearm` / `Forearm.001` and `Shin` / `Shin.001` preserve elbow/knee pivots. The shared factory normalizes the numeric suffixes in their separate parents.
- `Weapon=(0.31,0.60923076923,-0.29)`, `Weapon/Muzzle=(0,0.04,-0.51)` remain fixed.
- Unscaled bounds: approximately `(-0.7634,0,-0.8)` to `(0.4105,1.6469,0.6256)`.
- Each variant: **12 mesh objects, 34,816 triangles, 2 materials**. Opaque geometry is consolidated per animated pivot into linear `COLOR_0` vertex colors; the only second material is transparent reservoir glass.
- Godot's material must enable `vertex_color_use_as_albedo=true` and keep `vertex_color_is_srgb=false` for the linear GLB vertex palette. This is applied by the shared factory; Blender studio rendering alone is not proof of Godot's import material settings.

## Validation

`verify_fox.py` confirms GLB v2 integrity, fully embedded buffers, absence of external images, hierarchy, fixed weapon/muzzle, triangle/mesh budget, exact ground contact, ear-height limit, and identical geometry hashes across blue/orange variants. Runtime material and animation checks belong to the shared Godot integration; no shared runtime files are owned or modified by this source package.

## Repository cleanup (2026-10-28)

Unskinned GLB paths listed above are local generator outputs, not tracked runtime deliverables. Historical exports remain recoverable at Git commit `7b16265`; builders and editable `.blend` inputs remain tracked. Current game and Godot previews use `models/animals/rigged/`. Run the species builder before modeling-stage GLB validation.
