# Tide Gulp simulation data and contract

These are **initial authored tuning values, not player-tested timings**. All
simulation coordinates are `Vector2(x, y)` with positive Y pointing upwards.
Only this plane determines feeding and collisions. Render Z must never affect
collision or eligibility. Fish body length excludes fins and decorative tails.

`catalog.gd` contains eight species, six growth milestones, three ecology pools,
twelve authored primary reef layouts, two transitions, and all numeric tuning.
No dependency on the island, the other games, a node tree, input, or sound.

## Authoritative API

```gdscript
var sim = preload("res://modules/tide_gulp/sim.gd").new()
sim.start(12345)
sim.command({"move": Vector2.RIGHT, "use_target": false, "dash": false})
sim.tick(1.0 / 60.0)
var events = sim.drain_events()
# Direct public field reads avoid deep copying every render frame.
var player_position: Vector2 = sim.player.pos
```

- `start(seed)`, `restart(seed=-1)`: reset everything; `-1` reuses previous seed.
- `command({move, target, use_target, dash})`: vectors in the XY world; nonzero
  `move` overrides pointer targeting. Dash is an edge request, not a held state.
- `tick(dt)`: deterministic <=1/60 second substeps, no real-time clock lookup.
- `set_paused(bool)`: freezes time and clears held input when pausing.
- `finish("return")`: freezes run, returns stats; voluntary return is not death.
- `snapshot()`: deep copies player, fish, chunks, elapsed, alive, paused, score,
  stats, tide, biome. `stats_snapshot()` makes just the small result dictionary.
- `drain_events()`: returns then clears the bounded FIFO (capacity 128).
- `relation(length, player_length=-1)`: `food`, `peer`, `danger`.
- `mouth_position(body)`, `body_radius(body)`, `position_clear(pos,radius)`.
- `tide_state()`: phase (`calm`, `warning`, `flow`), direction, seconds remaining,
  fractional strength. `current_velocity(base_speed)` applies the same fractional
  drift to every animal; dash never secretly increases the current.
- `biome_at(x)`, `chunk_index(x)`, `memory_counts()`.

Player keys: `pos`, `dir`, `velocity`, `length`, `target_length`, `stage` (1..6),
`growth` (0..1), `dash_left`, `dash_cooldown`.

Fish keys: `id`, `species`, `pos`, `dir`, `velocity`, fixed `length`, `state`,
`state_left`, `warning_left`, `threat`, `home_chunk`, `slot`, `armed`. States are
`cruise`, `alert`, `windup`, `lunge`, `recover`, `retreat`.

Chunk dictionary is keyed by integer chunk index; each entry has `index`,
`biome` (`shallow`, `kelp`, `ruins`), `module_id`, `rect`, `obstacles` (world Rect2s).
Chunk width is 24. Water limits are Y=-7..7. The starting point is (0,0).

Events have `type` and `time`. Types: `start`, `restart`, `eat`, `score`, `grow`,
`dash`, `threat`, `lunge`, `tide`, `biome`, `death`, `stats`, `finished`.
`eat` includes fish id/species/position, nutrition, points, running score, tiny.
`threat` includes id/species/position, 1.2-second duration and direction.
`death`, `stats`, `finished` include final stats. Events never imply blood/gore.

## Fairness and bounded world invariants

- <=0.8P is edible, >=1.25P dangerous; the open interval only pushes.
- Only mouths feed. Unarmed threat contacts and dangerous sides/tails push.
- First alert lasts >=1.2s, followed by 0.6s windup; lunge commits its direction.
  Recovery is 1s; two lunges or a 7s pursuit forces a 4s retreat. There is no
  invulnerability dash. Initial 8s and the authored origin refuge disarm threats.
- Existing fish never resize when the player grows. The player's effective
  body length is itself smoothly interpolated; collision and feeding use it.
- Every authored layout has an adult-clear central route. Reef collisions use
  a conservative body-length circle. Growth pushes out incrementally; the
  guaranteed center route is a final safe-resolution fallback, not a new power.
- At most five chunks and sixty fish are resident. Eaten slots stay depleted
  for 120s even across unloading/revisits. Refill also stays outside 12.5 units
  of the player. Recent depletion memory caps at 128 chunks; natural movement
  cannot traverse that many chunks within 120s. The defensive cap also covers
  test/debug teleportation. Expired entries are discarded, so there is no
  unbounded visited-world or eaten-fish history.
- Main score is only effective food. Fish <0.35P award no score or nutrition;
  they may shorten dash cooldown by 0.08s. There is no time score or hunger.

## Reproduce headless checks

```sh
XDG_DATA_HOME=/tmp/tide-godot-data XDG_CACHE_HOME=/tmp/tide-godot-cache \
  /path/to/Godot_v4.7.2-stable_linux.x86_64 --headless --path godot \
  --script modules/tide_gulp/tests/test_sim.gd
```

The suite includes a 30-minute simulated-time lifecycle fixture with real
60Hz substeps and fish AI. Its scripted relocation of imminent predators is
explicitly a **world/resource stress fixture**, not a claim of unattended human
survival, playtest balance, graphical performance, or natural 30-minute play.
Predator lethality, warning timing and recovery have separate direct tests.
