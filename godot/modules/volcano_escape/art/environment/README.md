# Volcano Escape — original clay island environment

`world.gd` is a read-only presentation. Call `build(sim.map_data)`, then `update_state(sim.snapshot(), events)` each rendered frame. `boarding_position(exit_id)` returns the live world-space vehicle target during the post-success departure. First 1.25 seconds remain stationary for boarding, then boat sails / balloon and airship ascend. This is presentation only, never a second simulation.

## Authorship / visual language

Original modeled clay forms, not inherited assets: warm ochre crater cape with rounded rocky toes and inset lava channels, scalloped terraced coast, cut-in southern harbour, submerged slate rescue hull, cream rescue cabin, orange balloon envelope behind its open basket, cream/teal airship and western berth, open four-entry slate artificial refuge canopies, reachable consoles, low safe-corridor edge pebbles, sparse palm pockets outside all walkways. No purchased/generated bitmap or external model dependencies.

All gameplay paving is the exact `Island.road_polygon` / `Island.hub_polygon` at Y=0. Sunken basalt-green land is 1.2m below the exact safe stone causeways, with clustered rock basins and visible support faces; it is not another walkable surface. Natural coastline contains every road/hub footprint. Scenic foliage rejects every authoritative path plus 2.8m margin. Supports are outside hub disk and the route cross. Northern volcano is outside traversable geometry.

## Visibility / fairness

* Roads show orange ground stripes during the authoritative 20-second warning. On closure a low lava flow broadens over six seconds, never a high instant firewall; hub disks stay clear.
* Rock rings use the authoritative physical radius and persist through impact. Falling rock only appears for the final .65 seconds; its four-second ring remains the primary cue.
* Near/occupied shelters cut away the front canopy inside 5m but retain the permanent rear half-roof, industrial corner shells and door lintel; green protection ring switches to amber during expiry warning and extinguishes on expiry. No full-screen smoke. Five bounded crater puffs are high above the inaccessible cape.
* Actor and UI are supplied by the runtime. Authoritative time drives all running-state visual changes; only terminal success departure uses render delta.

## Budget and batching

43,248 triangles across **all** geometry including hidden hazard states; 31 spatial static batches; focused whole-timeline test saw a maximum **60 visible mesh surfaces** before camera culling/shadow passes (not a measured GPU draw-call benchmark). Dynamic effects are fixed allocations. Indexed and nonindexed mesh sources are both flattened correctly; vertex tints explicitly convert sRGB→linear; primitive/terrain winding agrees with Godot clockwise front faces.

## Focused tests

From repository root:

```
XDG_DATA_HOME=/tmp/volcano-env-data XDG_CONFIG_HOME=/tmp/volcano-env-config XDG_CACHE_HOME=/tmp/volcano-env-cache ../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot --script res://modules/volcano_escape/art/environment/test_environment.gd
```

Checks exact counts, terrain containment, triangle budget, every batched face/normal, road warning/closed state, rock warning state, shelter cutaway, bounded visible surface count over timeline. These are **render-state fixtures, not gameplay completion proofs**. Runtime and rules owners verify actual play.

## Native preview (root owns GUI)

```
../tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --path godot res://modules/volcano_escape/art/environment/Preview.tscn -- --view=overview --output=/absolute/path.png
```

Views: `overview`, `road`, `refuge`, `boat` (or `exit`), `balloon`, `airship`. Captures a real viewport after `frame_post_draw`, then quits. Snapshot times in previews are explicitly fixtures. Neutral .7 sun/.45 ambient, single bounded orthogonal shadow, close camera far100/overview150; no preview-only boosted lighting hiding material problems. Native visual verification is recorded by root, not inferred from headless tests.
