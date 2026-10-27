# Tide Gulp — painted sea environment source

All environment meshes are original project-specific geometric authoring in
`../tide_environment.gd`. The seabed, shells, fan corals, kelp, distant reef
silhouettes, arches, and rectangular collision reefs use no downloaded models,
textures, traced artwork, game assets, or generated promotional images.

The runtime source is the reproducible authoring source. It builds genuine
three-dimensional ArrayMesh geometry, batched by material. The common watercolor
shader supplies pigment wash and stable screen-space paper grain. Background and
kelp shader code is kept inside the environment source; neither contains a
raster texture. All materials are matte, with no metallic/specular plastic gloss.

## Geometric contract

- World coordinates: X horizontal; Y up; +Z toward the camera.
- The returned root is at world origin. `bounds` is a world-coordinate Rect2.
- The seabed top is exactly `bounds.position.y` (not hard-coded to -7).
- Only the supplied obstacle Rect2 values create visuals in the gameplay plane.
  Their rendered XY AABBs exactly match the simulated rectangles.
- Every coral, shell, seaweed, ruin and distant reef is behind z = -2.
- Decoration cannot create collision, occlude threats from the foreground, or
  introduce false navigational walls.
- Environment motion is visual only; it never changes a blocker or root.

## API

`TideEnvironment.make_environment(biome, bounds, obstacles)` supports biome
0 (sunlit reef), 1 (kelp tide belt), 2 (distant sea ruins).

The returned Node3D has `tick_pose(delta, time)` and `set_current(current)` through
`tide_environment_motion.gd`. `animate_environment(node, time, current)` is also
available as a static method.

## Reproduce checks

From the repository root, run Godot 4.7.2 with the project path and the ignored
source test as an absolute script path:

```
Godot --headless --path godot --script "$PWD/godot/modules/tide_gulp/art/source/verify_environment.gd"
```

The check creates all three biomes across three differently sized/offset bounds,
verifies exact obstacle XY bounds, decorative depth segregation, finite vertices
and normals, and the motion material API. The test is under `.gdignore` alongside
the editable art sources and is not part of the exported game.

## Cost at one 24-unit chunk plus two obstacle rectangles

- Sunlit reef: 7 mesh instances, 7,439 triangles.
- Kelp tide belt: 7 mesh instances, 3,833 triangles.
- Sea ruins: 7 mesh instances, 4,940 triangles.

No per-frame geometry allocation occurs. Kelp and low-contrast background current-brush animation update two scalar
shader uniforms each. Materials are shared except these two animated batches,
which each get one local material instance per chunk. Current marks use signed
strength: zero for resting tide, ±0.08 for a faint preview, and ±0.25 for the
readable moving tide. A marker wraps as one whole brush gesture, never stretching
a triangle across the width of a streamed chunk.


## Obstacle visual refinement — 2026-10-27

The gameplay screenshot exposed two ceiling-attached obstacles that read as dark
green placeholder boxes. Their presentation has been refined without changing
simulation input, full rectangular silhouette, XY AABB, draw-batch count, or
background decoration:

- Corrected camera-facing rock normals to +Z instead of pointing into the rock.
- Replaced the simple four bevel strips with a shallow uneven 3D stone-face grid.
- Added pale warm grey-green mineral washes, irregular sediment bands, small
  angled facets, and short paired shadow/highlight seams that suggest fractures.
- Kept every corner solid and every collision edge fully visible; no false
  rounded, transparent, or apparently passable gap was introduced.
- Added 468 triangles in the two-obstacle benchmark above, with no new meshes,
  materials, downloaded assets, or per-frame geometry work.

After the change, the 9-case geometric contract check passed again. The parent
art task also reported a successful complete art regression run.
