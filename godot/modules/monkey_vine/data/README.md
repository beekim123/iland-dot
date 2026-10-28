# Monkey Vine verified segment pool

Rules/data author handoff, 2026-10-28. Godot 4.7.2 stable official.

- Four authored templates cycle deterministically; no random vine spacing is admitted.
- Each template has two three-vine crossings, a broad middle checkpoint and broad treehouse exit. Alternating vine lengths vary by template without moving the catch-tip safe line. Moving/fragile vines are optional high routes; they are not mandatory traps. Fourth template adds bounded light wind.
- `Rect2.position` is bottom-left in XY, `.end.y` is solid top. `player_pos` is the radius .32 collision center; `grip_pos = player_pos + (0,.45)`.
- Space press jumps only from actual ground. Held Space can catch only within .35m of a vine tip with a clear anchor line. Release preserves momentum. Rope length locks to actual hand-to-anchor distance; no grab position snap occurs. Horizontal direction is limited pumping/air adjustment; there is no lift input.
- Fixed rules step is 120Hz. `step(dt,input)` accepts finite positive dt and retains fractional time; runtime can feed exact fixed ticks. Press/release edges are consumed once, held state persists across the supplied interval. Paused runtime must not call step.
- Failures auto-restart after .45s; segment clears auto-advance after .55s. `advance_segment()` can also be called while clear. One-frame events include jump, grab, release, land, collect, checkpoint, break_warning, vine_break, fail, restart, segment_clear, segment_start.
- Saves contain independent schema/game ID, seed, segment, safe checkpoint, banked score and checkpoint-confirmed collected IDs. Validation is atomic. Failed attempts roll back to confirmed checkpoint collectibles/score. A clear exports the next entrance immediately so leaving during feedback cannot repeat the completion reward.

## Reproduce

From standalone project root:

```
godot --headless --path . --script res://modules/monkey_vine/tests/test_rules_route.gd
godot --headless --path . --script res://modules/monkey_vine/tests/test_rules_invariants.gd
```

`route_witness.json` contains actual fixed-tick input dictionaries, seed and segment for each safe route. Replay in order using `step(1.0/120,input)` from `configure(seed,segment)`. All six vines are used, middle and final platforms are reached by physical landing. No position, velocity, score, checkpoint or phase writes occur in these completion tests. Route test also verifies small early/late control-threshold perturbations.

Invariant tests distinguish normal-input witnesses from explicit boundary fixtures; fixtures are not represented as playability proof. Fixtures test high-speed swept collision, remote grab rejection and fragile warning duration. Normal witnesses check rope error, continuous grab position, release momentum, bounded velocity, safe persistence, and a natural fall/retry from the middle platform. dt grouping checks include 15/30/60/120Hz and a 2-second catch-up.

Independent QA separately passed 36 normal-input combinations (three seeds, four templates, release threshold .55/.65/.75m) after the treehouse landing trigger was broadened. Runtime/rendering/rig/UI remain separate integration acceptance. Optional upper-route playability is now proven by the normal-input witnesses below.


## Optional upper routes: normal-input proof

`test_rules_bonus.gd` replays `bonus_witness_1.json` and `bonus_witness_2.json` from standard `configure(seed,segment)` starts. It never writes player position/velocity/checkpoint/score. `test_rules_bonus_search.gd` can regenerate them using normal right/Space control and bounded release-time search. Airborne releases remain unheld for at least 10 ticks (83.3ms), rather than requiring one-frame re-presses.

- Moving route, seed 937/template 1: first vine released at tick 154; moving vine grabbed and golden fruit collected at tick 173; released at 191; physical landing and rest checkpoint at 299. Original moving anchor/golden geometry was already reachable and was not changed.
- Fragile route, seed 937/template 2: second-crossing first vine released at tick 382; fragile grabbed at 400; warning starts 401; player actively releases at 448, after 0.392 seconds of observable warning and before its 1.2-second deadline. Physical exit landing/clear occurs at 608. No vine break or failure occurs.
- **Authored geometry correction:** the original fragile anchor x=21 did not yield a successful route in the tested release-time/threshold search; this is not an impossibility proof. The higher swing's natural hand trajectory was approximately x=21.4, just beyond the .35m grab radius. With root approval only its x was shifted to 21.5; y=7, length=2, grab radius, velocity cap, warning duration, all main-line vines and physics remain unchanged. The boundary fixture now uses the corrected anchor. The safe-line 12 perturbation routes and author invariants were rerun and passed after this correction.

These are reachability/safe-completion proofs, not claims that every mistimed upper route is recoverable or that arbitrary wind phases/skill levels are automatically solved.
