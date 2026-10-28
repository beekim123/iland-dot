# Beach Cleanup · original carved-sand environment

Editable source: `beach_environment.gd`; shader: `../../shaders/environment_sand.gdshader`.
No imported or reused previous-game visuals, external textures or licensed models.
Palette: warm mineral sand, chalk shell, petroleum sea, terracotta, restrained reed green.

## Integration

Instantiate the script as a Node3D. Call `build(map_data)` with `data/maps.gd.definition()`.
The map's `size`, exact obstacle Rect2/height, depots and zones are authoritative. XZ ground,
Y up. Call `update_state(snapshot)` with `restored_zones: Array[String]` after state changes.
Each restored zone adds one animated crab and one animated shorebird, plus four succulent/reed
clusters and small companion shells. All are non-collectible.
The apron includes a striped linen/terracotta parasol, beach mats, a weathered boardwalk,
a small sandcastle, shell clusters and reeds. Wind-eroded sandstone banks stay strictly
inside simulation rectangles. Both shader uniform colors and authored vertex colors are explicitly converted sRGB→linear;
original author colors are retained as metadata to prevent double conversion during batching.
These contain no physics/collectible objects and avoid rock/depot footprints. This renderer
never duplicates large trash geometry: its removal is owned by the trash renderer from
snapshot.remaining. Arbitrary zone IDs/counts are supported.

Static detail is vertex-colored and grouped into 12m spatial buckets. Terrain consists of
three solid opaque closed meshes (sea plinth, sand edge, sand cap), plus four narrow opaque tidal ribbons. There are no transparent
water layers. Every source surface's own indices are respected, including non-indexed meshes;
positions and inverse-transpose normals are transformed. A build-time assertion verifies
source and batched triangle counts are identical. Wildlife is one local mesh per animal.

## Preview (root owns screenshot capture)

`art/environment/preview.tscn` supports `-- --map=0`, `--map=1`, `--map=2`, `--restored`,
and `--output=/absolute/path.png`. Output waits for `RenderingServer.frame_post_draw`, saves
actual viewport pixels, then exits. Run with rendering enabled for screenshots, not headless.
Camera orthographic size = map width × 1.55; position = (23,33,31), looking at origin.
Preview daylight energy .7, ambient .25, filmic tonemap, parchment background.

## Headless structural checks

From repository root:

```
XDG_DATA_HOME=/tmp/beach-art-data XDG_CONFIG_HOME=/tmp/beach-art-config \
XDG_CACHE_HOME=/tmp/beach-art-cache \
../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot \
--script res://modules/beach_cleanup/art/environment/test_environment.gd
```

Checks all 3 authoritative layouts, <45k triangles, upward cap normals, all restoration IDs,
wildlife outside rocks/depot areas, and absence of CollisionObject3D. Budgets are mesh/triangle
counts, not measured FPS. Sun/shadow passes and labels can add actual renderer draw calls.

## Latest structural budget (all ecology present)

- Map 0: 25,072 triangles / 32 MeshInstance3D nodes.
- Map 1: 25,288 triangles / 32 MeshInstance3D nodes.
- Map 2: 31,120 triangles / 37 MeshInstance3D nodes.

Counts exclude cart/trash/UI; include restored flora/fauna. Label3D and shadow rendering can
add actual draw calls. Initial state keeps restoration meshes hidden. Structural tests pass
on Godot 4.7.2; actual screenshots and gameplay viewport review belong to the integration owner.
