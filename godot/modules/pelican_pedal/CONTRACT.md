# Pelican Pedal rebuild contract

This is a new implementation, not a restoration of the lost prior source.

- World: metres, Y up, forward -Z. Ground height is data/map.gd.height_at(XZ). Actor yaw uses (-sin(yaw), -cos(yaw)).
- Rider eye: (0,1.68,-0.12) relative to bike ground. Perspective 72 degrees, near .05. Camera yaw/pitch is relative to actor; no forced roll with comfort mode enabled.
- Art owner supplies art/pelican_bicycle.gd Node3D factory with `set_motion(speed, steering, braking, delta)` if convenient, or informs runtime of actual API. Runtime owns camera and world; art must not own gameplay/input/storage.
- First-person geometry: handlebar at y1.0,z-.55, wings near y1.03,z-.42, small beak tip below optical centre. Avoid opaque head around camera. Feet and wheels can exist below camera; optional full-body representation is separate.
- game.gd: Node3D with start(context), exit_requested, leave_game; fixed module storage namespace. No dependencies on hub or another game.
- sim.gd: sole gameplay authority, command + fixed tick, finite validated snapshots. Legal tests may drive command inputs; never teleport to fake route completion.
- Stops and collision data are shared with world renderer. Continuous substep collision prevents tunnelling. R reset returns to a recorded visited safe road point, not next target.
- Full delivery loop: depot pickup, ordered addresses, delivery result, next contract. Deadlines affect score, never silently delete cargo. Complete/failed jobs cannot tick or save twice.
- Development status is not a release claim; real native visual/input QA and source freeze remain acceptance gates.
