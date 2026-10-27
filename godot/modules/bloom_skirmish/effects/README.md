# Original flower-nectar rendering

This is a bounded visual layer, not a fluid solver or a second source of paint ownership.
The simulation owns the 3D projectile parabola and fine authoritative coverage raster. The
renderer never writes coverage, scores, collision state, or gameplay RNG.

## Runtime contract

```gdscript
const NectarEffects = preload("effects/nectar_effects.gd")
var fx = NectarEffects.new()
add_child(fx) # Sibling of replaceable actor nodes.
fx.reset() # New match and exit.
fx.shot(event) # Optional: bounded actor emission timestamps.
fx.impact(event) # splash and pod_burst simulation events.
fx.sync_projectiles(sim.projectiles, sim.actors, dt) # dt=0 on pause.
```

- Projectile dictionary: `id, team, world_pos:Vector3, velocity:Vector3,
  dir:Vector2, traveled:float, gravity:float`. `age` is optional; without it,
  traveled/horizontal speed gives the same ballistic age. The source nozzle is
  already included in the simulation. No render-only range or trajectory.
- Impact dictionary: `team, world_pos:Vector3, normal:Vector3, radius, seed,
  surface`. Existing `pos:Vector2` is a backwards-compatible ground fallback.
- `debug_stats()` exposes live counts and hard caps for lifecycle verification.
- `reset()` retains exactly four rendering nodes and empties all visible geometry.

Each live packet draws a finite, tapered, ten-sided smooth-normal liquid strand
following its actual ballistic trajectory. Overlapping 105ms tails connect at the
80ms authoritative fire cadence, but narrow and separate as firing stops. Rounded
elongated head beads, occasional thin detached beads, and changing neck radii
provide visible viscosity rather than a straight laser or a row of seeds.
Impact creates a short-lived hollow fluted crown and capillary ring, then inertial
stretched beads fall under gravity and vanish on ground contact. Wall/actor crowns
align to the simulation impact normal. These transient splashes do not paint.

Hard limits: 64 projectile strands, 24 impact crowns, 160 detached droplets,
256 visible instances per team, two dynamic strand/crown meshes plus two pooled
MultiMeshes. All geometry/materials are created from original code; no downloaded
reference textures, copyrighted character art, external plugins, or GPU particles.
The opaque Schlick-GGX nectar shader avoids transparent depth-sorting artifacts
and runs on Godot Compatibility/WebGL.

`../ui/turf.gdshader` consumes the *same ownership texture* as score and
movement queries. Irregular splat lobes/satellite ownership come from simulation,
not decorative stamps over neutral cells. There is no per-cell flower pattern or UV warping. Bilinear half-coverage
contours and one-screen-pixel antialiasing soften subtexel boundaries only; every
scored cell center retains its exact owner. Dominant-channel team selection avoids
a mixed third-team color at team boundaries. Broad continuous normal variation,
meniscus slopes and low-roughness highlights create the wet finish. Runtime sets
`liquid_time` so pausing freezes surface motion too.

## Sunlit greenhouse revision

The approved independent direction uses cobalt `#2F62FF` and orange `#FF8A1F`.
Both airborne liquid and the authoritative ground material use those exact sRGB
palette inputs, with restrained pale glints rather than teal/coral or glowing foam.
The ten-sided tube has a gently narrowing rounded front, a 105ms finite tail, and a
smaller nose bead so packets read as connected thick liquid rather than large balls.
Geometry is still derived only from the existing physical parabola; caps, four render
nodes, pause/reset semantics and all scoring/physics remain unchanged. The ground is
rough mineral white when unowned, glossy within the owned mask, and carries no
extra decorative liquid beyond the authoritative contour. Runtime uses a camera-local
procedural sky, a warm-white oblique sun and restrained cool fill, with a single orthogonal shadow map.
No SSAO, screen-space reflection or expensive fluid simulation is assumed.

### Compatibility shadow correction (2026-10-27)

The first sunlit native capture exposed dense receiver stripes across the floor,
liquid, pots and crates with two-split directional shadows. Increasing bias did not
remove them. Same-seed actual Godot A/B captures with shadows disabled removed the
stripes; an orthogonal shadow map also removed them while keeping grounded shadows.
Runtime therefore keeps shadows **enabled**, uses `SHADOW_ORTHOGONAL`, max distance
54m, bias .10 and normal bias 1.10. This is a renderer-path workaround, not a change
to ownership, geometry, collision or scoring. The full-floor foundation top is at
Y=-.025 and the authoritative surface is at Y=.025, not coplanar. The independent
mineral shader was also made smoothly varying and screen-footprint filtered to
avoid a separate distant-texture aliasing risk; it was not the cause of the global
striping. Sun/fill remain restrained at .56/.22 pending the final redesigned art's
native light calibration. Internal diagnostic captures use the old unfinished arena
and are not user-facing finished-art evidence.
