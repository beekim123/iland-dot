# Living wildlife motion

`godot/scripts/wildlife_motion.gd` is a deterministic runtime module. Add it to the scene, call `setup(actors)` once with `[turtle, crab, seagull]`, then `apply_motion(time_seconds)` each frame. `update_motion` is the same API. It does not run its own process loop; pause and fixed-step recording remain controlled by the scene. Disable the original stationary wiggle logic for these actors.

## Behaviors

- Sea turtle swims a foreground oval at x −6..−2, z 10..11.6, root y −0.20..−0.12. The authored head faces local +Z; heading follows the velocity tangent. Front flippers row with shoulder hinges, rear flippers steer, with mild body pitch/roll and surface buoyancy. The shell remains partly above the water; flippers can be submerged.
- Seagull flies an 8.6 × 7 m elliptical orbit centered at (0, 8, 2), at y 7.66..8.34 above palm crowns. Body heading follows flight direction, with turn banking and altitude change. The torso leans forward 32° and the original legs/feet tuck under the belly, avoiding the upright perched-bird silhouette. The same imported wing meshes/feathers are unfurled and pivoted at their shoulders, alternating strokes and glides. This is stylized chibi flight, not a biological simulation.
- Crab scuttles sideways x 0.95..3.65 on the foreground beach, pauses at the endpoints, and uses alternating leg pairs. Each original leg and claw hierarchy is attached to a runtime articulation joint instead of merely rotating the entire animal.

All source Blender/GLB files are untouched. Runtime changes are reversible by reloading the scene. Actor root names and original scale are retained. Reparented articulation nodes have runtime-only ownership so imported scene ownership does not produce warnings.

## Verification

Godot 4.7.2 headless module test passed: 4 flipper pivots, 2 wing pivots, 8 crab leg pivots; finite positions/rotations across 240 samples covering 24 seconds; turtle stays z≥10, gull remains above y7.5; repeated absolute-time seeking returns the same position. No warnings/errors in final module test. Final camera composition and visible water interaction require the integrated graphical review, not just this test.
