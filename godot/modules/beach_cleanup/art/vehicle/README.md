# Beach Cleanup / original miniature art

All geometry, palette and pivot rig were authored for this module. No downloaded models,
textures, prior-game models or humanoid assets are used. Sculpted sand/chalk bodywork,
sea-glass teal, fired terracotta, deep-kelp rubber. Six trash pieces are unmistakable
human-made debris; no shells, animals or natural seaweed are collectible trash.

## Rebuild and validate

From repository root:

```sh
blender -b --python godot/modules/beach_cleanup/art/vehicle/generate_models.py
python godot/modules/beach_cleanup/art/vehicle/audit_glb.py
# After Godot imports the generated GLBs:
Godot --headless --path godot --script res://modules/beach_cleanup/art/vehicle/test_model.gd
```

Editable Blender source: `vehicle/source/cart_model.blend` and `trash/source/*.blend`.
Source folders are `.gdignore`d: production uses reproducible GLBs, not a dependency
on each developer's Blender importer configuration. The Python generator preserves
individually named construction parts, then merges only geometry sharing one rigid
pivot. Colors are baked into linear vertex colors and a single matte material, so
articulation is retained at **11 surfaces** for the cart and **1 per trash model**.

Final cart is 4,988 triangles. Bottle 248, can 348, wrapper 1,076, sandal 216, crate
1,836, bundled net 2,676. These are audited geometry counts, not performance claims.
`export_audit.json` validates actual GLB index ranges, triangles, finite positions,
vertex colors and surfaces. Godot test validates pivot locations, wheel-axis bounds,
5 IK poses, vertex-color albedo enablement, wheel ground contact, repeated cargo replacement/emptying and actual imported surface counts.

## Integration

Instance `cleanup_cart.tscn`. Units metres, +Y up, forward -Z. Wheel ground contact
~0.005 m; body 1.0 × 1.22 m. Wheel radius .235 m. The small front sensor is a machine
sensor, not eyes. Chassis, each wheel, shoulder, elbow, wrist and each jaw are rigid
parts; shoulder and elbow use analytic two-link IK. A visible teal sliding rail extends the forearm by up to .7 m; its true wrist pivot follows the extension, maintaining accurate 1.8 m pickup without teleportation.

After `_ready`:
- `set_motion(speed: float, steering: float, dt: float)` rotates real wheel nodes;
  steering is clamped -1..1 and visibly turns front wheels.
- `set_grab(progress: float, target_local: Vector3)`: 0 idle/open, .5 pickup/closed, .65 lift, .85 over basket/release, 1 idle/open. Target is local to the cart. Runtime owns pickup timing.
- `set_cargo(cargo_items: Array)`: up to 12 visible pieces. Entries are kind strings
  or dictionaries containing `kind`; valid kinds bottle/can/wrapper/sandal/crate/net.
  Visual miniature representation only; gameplay capacity is owned by the rules.

Trash GLBs use ground-contact origins and do not include physics/collision scripts.

## Native renderer previews

```sh
Godot --path godot res://modules/beach_cleanup/art/vehicle/preview.tscn -- \
  --preset=hero --output=/absolute/path/cart.png
```

Presets `hero`, `grip`, `extended`, `cargo`, `catalog`. Capture occurs on frame 8 and exits.
Do not use headless/dummy renderer for screenshots. Root task owns native renders.
The first render revealed unapplied cylinder rotations before parenting; generator
now refreshes Blender depsgraph first. Wheel-axis regression specifically asserts
X thickness .199 vs Y/Z diameter .47 to prevent the horizontal-puck defect returning.

All gameplay and preview trash instances must use `trash/<kind>.tscn` wrappers,
not bare GLBs. Their `_ready` enables vertex-color albedo, as does the cart script.
This is independent of ignored `.import` files. Fresh copy test with all `.import`
and `.godot` files absent passes every assertion, including all seven palettes.
Preview uses a single orthogonal 12 m directional shadow range with bias .05 and
normal bias .25; wheel world-ground gap is asserted at .005 m.

`get_grip_world_position()` returns the actual jaw contact midpoint for the runtime
pickup visual. At 1.8 m and -40/0/+40 degrees, the headless regression requires
contact error < .03 m (measured < 3e-7 m). Identical cargo arrays preserve instance
IDs; visible cargo is rebuilt only on content changes. All exported triangles
pass nonzero-area cross-product threshold 1e-18, after float32 GLB export.
