# Two Q-style seabirds — V5

Two independent skinned assets; no runtime script dependencies.

| Variant | Asset | Appearance |
|---|---|---|
| Gull | `gull/bird_rigged.glb` | Original friendly white Q face, wide silver wings and dark tips |
| Tern | `tern/bird_rigged.glb` | Rounded charcoal cap, blue-grey wings, coral beak, longer outer tail feathers |

Each folder contains editable `bird_rigged.blend`, `rig_report.json`, `independent_audit.json`, `motion_bounds.json`, pose/glide PNGs and actual rendered `bird_fly.gif` / MP4. Research: `../../../docs/research/v5-birds.md` (from repository root use `docs/research/v5-birds.md`).

## Animation and import contract

- 17 actual armature bones, one skin; 42 / 43 mesh objects. Every vertex has normalized skin weights; 4,404 vertices blend neighbouring bones.
- `Fly`, `Glide`: 4 seconds each, 24 fps authored, closed endpoints. Preview samples 48 evaluated frames at 12 fps. No interpolated/faked still-image motion.
- Blender forward **-Y**, up **+Z**. Standard glTF/Godot forward **+Z**, up **+Y**. Align model **+Z** with path tangent; do not use `look_at` default -Z without correcting orientation.
- Exported armature root identity. Artist preview elevation is applied only after GLB export and is NOT gameplay spawn height.
- Gull glide motion bounds span 3.435 × 1.561 × 0.883 Blender units (X/Y/Z); Fly motion envelope spans 3.404 × 1.556 × 1.677, with lowest wingtip Z -0.297. Keep runtime clearance above sea/terrain. Full details in motion_bounds.json.
- No travelling root motion: world translation, heading and gentle banking belong to host path controller. Keep bank modest (~10–15°) and favour glide on turns; alternate flap/glide smoothly, don't teleport action phase every frame.
- Importer may expose ~4.041667s even though glTF's keyed duration is 4s. Reuse verified normalized phase mapping rather than assuming raw Blender frame offset.

## Reproduce

From project root with Blender 4.3.2:

```sh
blender -b -t 2 -P art/v5/birds/build_birds.py
blender -b -t 2 -P art/v5/birds/build_birds.py -- --tern
blender -b -t 2 -P art/v5/birds/render_motion.py
blender -b -t 2 -P art/v5/birds/render_motion.py -- --tern
blender -b -t 2 -P art/v5/birds/check_birds.py
blender -b -t 2 -P art/v5/birds/check_birds.py -- --tern
```

Build reuses approved head/body from `art/v3/animals.blend`, replaces only wings and adds companion markings. Cycles CPU, no unsupported OIDN or headless Eevee; motion preview max 2 threads/process. Final GLBs embed textures/materials and have no external URIs. Images are artist previews, not evidence of Godot integration (host integrator verifies runtime separately).
