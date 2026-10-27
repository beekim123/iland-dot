extends SceneTree
const Sim = preload("../sim.gd")
var checks := 0
var failures := 0

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func quiet(seed_value: int = 42):
	var sim = Sim.new()
	sim.bots_enabled = false
	sim.start(seed_value)
	return sim

func has_event(sim, kind: String) -> bool:
	for event in sim.events:
		if event.type == kind: return true
	return false

func _initialize() -> void:
	_test_map()
	_test_movement_and_water()
	_test_projectiles_and_damage()
	_test_pods()
	_test_fine_liquid_and_3d()
	_test_timing()
	_test_bots_and_determinism()
	print("BLOOM SIM: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_map() -> void:
	var sim = quiet()
	expect(sim.actors.size() == 4 and sim.actors[0].is_player, "2v2 with one human")
	expect(sim.actors[0].team == 0 and sim.actors[1].team == 0 and sim.actors[2].team == 1 and sim.actors[3].team == 1, "team assignment")
	expect(sim.ownership.size() == Sim.GRID_W * Sim.GRID_H and sim.ownership.count(-1) == sim.ownership.size(), "all ground starts neutral")
	expect(sim.scoreable_cells == roundi(640.0 / (Sim.CELL_SIZE * Sim.CELL_SIZE)), "cover and protected spawns excluded from scoring denominator")
	expect(sim.score == [0.0, 0.0], "initial zero coverage")
	for actor in sim.actors:
		expect(sim._actor_position_clear(actor.pos, actor.team), "spawn is navigable")
		expect(not sim.is_scoreable(sim.cell_at(actor.pos)), "spawn does not score")
	sim._paint_disc(Vector2(2, 12), 4.0, 1)
	expect(sim.owner_at(Vector2(2, 12)) == -1, "spawn cannot be painted")
	expect(not sim.is_scoreable(sim.cell_at(Vector2(15.5, 11.5))) and sim.owner_at(Vector2(15.5, 11.5)) == -1, "wall never scores")
	expect(not sim.line_of_sight(Vector2(12, 12), Vector2(20, 12)), "cover occludes line of sight")
	expect(sim.line_of_sight(Vector2(5, 8), Vector2(26, 8)), "clear lane visible")
	var revision: int = sim.grid_revision
	sim._paint_disc(Vector2(6.5, 8.5), 0.3, 0)
	expect(sim.grid_revision > revision, "paint increments revision")
	revision = sim.grid_revision
	sim._paint_disc(Vector2(6.5, 8.5), 0.3, 0)
	expect(sim.grid_revision == revision, "unchanged turf does not increment revision")
	var before: int = sim.score_cells[0]
	var transferred: int = sim._paint_disc(Vector2(6.5, 8.5), 0.3, 1)
	expect(sim.score_cells[0] == before - transferred and sim.owner_at(Vector2(6.5, 8.5)) == 1, "repaint transfers ownership")
	expect(is_equal_approx(sim.score[0] + sim.score[1], 100.0 * (sim.score_cells[0] + sim.score_cells[1]) / sim.scoreable_cells), "coverage is fraction of total scoreable ground")

func _test_movement_and_water() -> void:
	var sim = quiet()
	var start: Vector2 = sim.actors[0].pos
	sim.step(1.0, {"move": Vector2.RIGHT})
	expect(sim.actors[0].pos.is_equal_approx(start + Vector2.RIGHT * Sim.MOVE_SPEED), "normal movement speed")
	sim.actors[0].pos = Vector2(13.3, 11.5)
	sim.step(0.5, {"move": Vector2.RIGHT, "dash": true})
	expect(sim.actors[0].pos.x <= 14.0 - Sim.ACTOR_RADIUS + 0.001, "dash cannot pass wall at low FPS")
	expect(sim.actors[0].dash_cd > 0.0, "dash starts cooldown")
	sim.actors[0].pos = Vector2(5, 8)
	sim.actors[0].dash_cd = 0.0
	sim.step(0.25, {"move": Vector2.RIGHT, "dash": true})
	expect(sim.actors[0].dash_cd == 0.0, "held dash does not retrigger")
	sim.step(Sim.FIXED_DT, {"dash": false})
	sim.step(Sim.FIXED_DT, {"dash": true, "move": Vector2.RIGHT})
	expect(sim.actors[0].dash_left > 0.0, "new dash edge triggers")
	sim.damage_actor(0, 25.0, 2)
	expect(sim.actors[0].hp == 75.0, "dash grants no invulnerability")
	sim.actors[0].pos = Vector2(27.5, 11.5)
	sim.step(1.0, {"move": Vector2.RIGHT})
	expect(sim.actors[0].pos.x <= 28.0 - Sim.ACTOR_RADIUS + 0.001, "enemy spawn forbids entry")
	sim = quiet()
	sim.step(5.0, {"shoot": true, "aim": Vector2(8, 10.5)})
	expect(sim.actors[0].water == 0.0 and sim.actors[0].shots == int(Sim.MAX_WATER / Sim.SHOT_WATER), "finite water forbids dry shooting and holding does not refill")
	sim.step(0.3)
	expect(sim.actors[0].water == 0.0, "refill waits after firing")
	sim.step(4.0)
	expect(sim.actors[0].water == Sim.MAX_WATER, "release auto-refills to cap")
	sim.step(Sim.FIXED_DT, {"shoot": true, "aim": Vector2(8, 10.5)})
	expect(sim.actors[0].water == Sim.MAX_WATER - Sim.SHOT_WATER, "refilled weapon fires again")

func _test_projectiles_and_damage() -> void:
	var sim = quiet()
	sim.actors[0].pos = Vector2(12.5, 11.5)
	sim.actors[2].pos = Vector2(19.5, 11.5)
	sim.step(2.0, {"shoot": true, "aim": sim.actors[2].pos})
	expect(sim.actors[2].hp == Sim.MAX_HP, "shots cannot hurt through central wall")
	expect(sim.owner_at(Vector2(18.5, 11.5)) == -1, "shots cannot paint through wall")
	expect(sim.owner_at(Vector2(13.875, 11.875)) == 0, "wall impact paints near side")
	sim = quiet()
	sim.actors[0].pos = Vector2(5.5, 8.5)
	sim.actors[1].pos = Vector2(7.5, 8.5)
	sim.actors[2].pos = Vector2(9.5, 8.5)
	sim.step(0.95, {"shoot": true, "aim": sim.actors[2].pos})
	expect(not sim.actors[2].alive and sim.actors[2].respawn_left > 3.0, "eight fluid packets defeat an exposed opponent")
	expect(sim.actors[1].hp == Sim.MAX_HP, "friendly fire disabled")
	expect(sim.actors[0].kills == 1 and sim.actors[2].defeats == 1, "defeat statistics")
	var respawn_left: float = sim.actors[2].respawn_left
	sim.step(respawn_left - 0.05)
	expect(not sim.actors[2].alive, "no early respawn")
	sim.step(0.07)
	expect(sim.actors[2].alive and sim.actors[2].hp == Sim.MAX_HP and sim.actors[2].water == Sim.MAX_WATER, "four-second full respawn")
	expect(sim.actors[2].pos == sim._spawn_position(2), "respawn at own safe garden")
	expect(not sim.damage_actor(2, 100.0, 0), "safe spawn blocks damage")
	sim.actors[0].pos = Vector2(27.5, 10.5)
	sim.step(2.0, {"shoot": true, "aim": sim.actors[2].pos})
	expect(sim.actors[2].hp == Sim.MAX_HP, "hostile projectiles stop at safe garden boundary")
	sim = quiet()
	sim.actors[0].pos = Vector2(5.5, 8.5)
	sim.step(1.0, {"shoot": true, "aim": Vector2(9.5, 8.5)})
	expect(sim.owner_at(Vector2(9.5, 8.5)) == 0, "shots land at world aim target and paint turf")
	expect(sim.projectiles.size() < 10, "projectile lifecycle bounded")
	sim = quiet()
	sim.obstacles.assign([Rect2(8.0, 7.0, 0.2, 5.0)])
	sim.actors[0].pos = Vector2(7.2, 8.5)
	sim.step(0.5, {"shoot": true, "aim": Vector2(9.5, 8.5)})
	expect(sim.owner_at(Vector2(7.875, 8.875)) == 0 and sim.owner_at(Vector2(8.5, 8.5)) == -1, "impact paint obeys even thin-wall occlusion")

func _test_pods() -> void:
	var sim = quiet()
	expect(not sim.deploy_pod(0), "no pod in protected spawn")
	sim.actors[0].pos = Vector2(6.5, 10.5)
	expect(not sim.deploy_pod(0), "no pod on neutral ground")
	sim._paint_disc(sim.actors[0].pos, 0.4, 1)
	expect(not sim.deploy_pod(0), "no pod on enemy turf")
	sim._paint_disc(sim.actors[0].pos, 0.4, 0)
	expect(sim.deploy_pod(0), "pod plants on friendly turf")
	expect(sim.pods.size() == 1 and sim.actors[0].pod_cd == Sim.POD_COOLDOWN, "plant creates fuse and cooldown")
	sim.actors[0].pod_cd = 0.0
	expect(not sim.deploy_pod(0), "one active pod per actor independent of cooldown")
	sim.step(2.99)
	expect(sim.pods.size() == 1, "three-second fuse does not detonate early")
	var before: int = sim.score_cells[0]
	sim.step(0.02)
	expect(sim.pods.is_empty() and has_event(sim, "pod_burst"), "pod detonates at three seconds")
	expect(sim.score_cells[0] > before + 10, "pod one-shot radius paints a useful area")
	before = sim.score_cells[0]
	sim.step(1.0)
	expect(sim.score_cells[0] == before, "no permanent pod territory generator")
	sim = quiet()
	sim.actors[0].pos = Vector2(13.5, 11.5)
	sim._paint_disc(sim.actors[0].pos, 0.4, 0)
	sim.deploy_pod(0); sim.step(3.0)
	expect(sim.owner_at(Vector2(14.5, 9.5)) == -1, "pod radius cannot wrap through a cover corner")
	expect(sim.owner_at(Vector2(12.5, 9.5)) == 0, "pod paints equally close unobstructed ground")
	sim = quiet()
	sim.actors[0].pos = Vector2(6.5, 10.5)
	sim._paint_disc(sim.actors[0].pos, 0.4, 0); sim.deploy_pod(0)
	sim.actors[0].pos = Vector2(5.5, 8.5)
	sim.actors[2].pos = Vector2(9.5, 10.5)
	sim.actors[2].aim = Vector2.LEFT
	sim._fire(sim.actors[2], Vector2(6.5, 10.5)); sim.step(0.25)
	expect(sim.pods.size() == 1 and sim.pods[0].hp < Sim.POD_HP, "enemy shot damages pod")
	for _packet in 3:
		sim._fire(sim.actors[2], Vector2(6.5, 10.5)); sim.step(0.25)
	expect(sim.pods.is_empty() and has_event(sim, "pod_destroyed"), "fourth fluid packet destroys pod before detonation")
	sim.step(3.0)
	expect(not has_event(sim, "pod_burst"), "destroyed pod cannot burst later")
	expect(sim.actors[0].pod_cd > 7.0, "destroying pod does not refund cooldown")
	sim.actors[0].pos = Vector2(6.5, 10.5)
	sim._paint_disc(sim.actors[0].pos, 0.4, 0)
	expect(not sim.deploy_pod(0), "no redeploy during cooldown after destruction")
	sim.step(9.0)
	expect(sim.deploy_pod(0), "pod available after full cooldown")
	sim.damage_actor(0, 100.0, 2)
	expect(sim.pods.size() == 1 and not sim.deploy_pod(0), "defeat preserves planted pod and blocks dead input")
	sim.step(3.0)
	expect(sim.pods.is_empty() and has_event(sim, "pod_burst"), "planted pod resolves independently of dead owner")

func _test_fine_liquid_and_3d() -> void:
	var sim = quiet()
	expect(Sim.CELL_SIZE == 1.0 / 12.0 and Sim.GRID_W == 384 and Sim.GRID_H == 288, "twelfth-unit authoritative paint raster")
	expect(sim.cell_at(Vector2(7.8, 8.3)) == Vector2i(93, 99), "world position maps to fine texel")
	expect(sim.cell_center(Vector2i(93, 99)) == Vector2(93.5, 99.5) * Sim.CELL_SIZE, "fine texel center maps to world")
	var origin := Vector2(6.125, 8.125)
	sim._paint_disc(origin, Sim.CELL_SIZE * 0.4, 0)
	expect(sim.score_cells[0] == 1 and is_equal_approx(sim.score[0], 100.0 / sim.scoreable_cells), "single sub-unit texel has exact scoring weight")
	expect(sim.owner_at(origin + Vector2(0.25, 0)) == -1, "adjacent sub-unit ground stays neutral")
	var revision: int = sim.grid_revision
	var wet_revision: int = sim.wet_revision
	sim.step(0.5); sim._paint_disc(origin, Sim.CELL_SIZE * 0.4, 0)
	expect(sim.grid_revision == revision and sim.wet_revision > wet_revision, "rewetting updates wetness without false ownership revision")
	expect(is_equal_approx(sim.painted_at[97 * Sim.GRID_W + 73], 0.5), "wet timestamp is authoritative simulation time")
	var organic = quiet(); var circular = quiet()
	organic._paint_splat(Vector2(6.5, 8.5), 1.5, 0, 0, 15)
	circular._paint_disc(Vector2(6.5, 8.5), 1.5, 0)
	expect(organic.ownership != circular.ownership, "actual owned mask contains irregular lobes and satellite droplets")
	var twin = quiet(); twin._paint_splat(Vector2(6.5, 8.5), 1.5, 0, 0, 15)
	expect(organic.ownership == twin.ownership and organic.score_cells == twin.score_cells, "same splat seed yields identical authority")
	var counts := [0, 0]
	for owner in organic.ownership:
		if owner >= 0: counts[owner] += 1
	expect(counts == organic.score_cells, "organic rendered ownership and exact score have one source of truth")
	var pixels_match := true
	for index in organic.ownership.size():
		var owner: int = organic.ownership[index]
		if organic.coverage_rgb[index * 3] != (255 if owner == 0 else 0) or organic.coverage_rgb[index * 3 + 1] != (255 if owner == 1 else 0): pixels_match = false
	expect(pixels_match, "native RGB upload buffer exactly matches every authoritative texel")
	sim = quiet(); sim.actors[0].pos = Vector2(5.5, 8.5); sim.actors[0].aim = Vector2.RIGHT
	sim._fire(sim.actors[0], Vector2(12.5, 8.5), Vector3(12.5, 0, 8.5))
	var shot: Dictionary = sim.projectiles[0].duplicate(true)
	expect(shot.origin == Vector3(6.54, Sim.SHOT_HEIGHT, 8.903), "liquid starts at actual scaled sprayer nozzle")
	sim.step(Sim.FIXED_DT)
	var expected: Vector3 = shot.origin + shot.velocity * Sim.FIXED_DT + Vector3.DOWN * Sim.SHOT_GRAVITY * 0.5 * Sim.FIXED_DT * Sim.FIXED_DT
	expect(sim.projectiles[0].world_pos.is_equal_approx(expected), "projectile visuals receive authoritative ballistic position")
	expect(is_equal_approx(sim.projectiles[0].velocity.y, shot.velocity.y - Sim.SHOT_GRAVITY * Sim.FIXED_DT), "actual gravity affects live projectile velocity")
	sim.step(0.6)
	var impact: Dictionary = {}
	for event in sim.events:
		if event.type == "splash": impact = event
	expect(not impact.is_empty() and impact.surface == "ground" and impact.normal == Vector3.UP, "ground impact includes exact effect plane and normal")
	expect(impact.has("world_pos") and impact.has("shot_id") and impact.has("seed"), "impact effects carry 3D position and stable identity")
	expect(sim.owner_at(Vector2(12.5, 8.5)) == 0, "ballistic packet reaches intended ground point")
	sim = quiet(); sim.actors[0].pos = Vector2(5.5, 8.5); sim.actors[2].pos = Vector2(9.5, 8.5)
	sim.step(0.8, {"shoot": true, "aim": Vector2(9.5, 8.5), "aim_direction": Vector3(1, 1.4, 0)})
	expect(sim.actors[2].hp == Sim.MAX_HP, "aiming upward cannot damage a floor enemy via flattened XZ ray")
	expect(sim.score_cells == [0, 0], "airborne upward spray does not paint imaginary ground impacts")
	sim = quiet(); sim.actors[0].pos = Vector2(12.8, 11.5); sim.actors[0].aim = Vector2.RIGHT
	sim._fire(sim.actors[0], Vector2(20.0, 11.5), Vector3(20, 0.8, 11.5))
	sim.step(0.3)
	impact = {}
	for event in sim.events:
		if event.type == "splash": impact = event
	expect(not impact.is_empty() and impact.surface == "wall" and impact.normal.x < -0.9, "wall impact exposes outward surface normal")
	sim = quiet(); sim.actors[0].pos = Vector2(13.5, 11.5); sim.actors[0].aim = Vector2.RIGHT
	sim._fire(sim.actors[0], Vector2(20, 11.5))
	expect(sim.projectiles.is_empty() and has_event(sim, "splash"), "nozzle extending into cover splashes immediately instead of teleporting shot through it")
	var collision: Dictionary = sim._world_collision(Vector3(13, 2.0, 12), Vector3(19, 2.0, 12), 0)
	expect(collision.t > 1.0, "genuine high trajectory clears finite-height cover")
	collision = sim._world_collision(Vector3(13, 0.8, 12), Vector3(19, 0.8, 12), 0)
	expect(collision.t <= 1.0 and collision.surface == "wall", "low trajectory is blocked by same cover")
	sim = quiet(); sim.actors[0].pos = Vector2(5.5, 8.5); sim.actors[0].aim = Vector2.RIGHT
	sim.actors[2].pos = Vector2(6.1, 8.7)
	sim._fire(sim.actors[0], Vector2(10, 8.5), Vector3(10, 0.9, 8.5))
	expect(sim.actors[2].hp == Sim.MAX_HP - Sim.SHOT_DAMAGE, "nozzle offset cannot teleport liquid past a point-blank opponent")
	sim = quiet(); sim.actors[0].pos = Vector2(5.5, 8.5); sim.actors[0].aim = Vector2.RIGHT
	sim._fire(sim.actors[0], Vector2(12.5, 8.5), Vector3(12.5, 0, 8.5), Vector3.UP)
	expect(sim.projectiles[0].velocity.x > 0.0, "valid world hit takes precedence over stale sky direction")
	sim.actors[2].pos = Vector2(10, 8)
	collision = sim._world_collision(Vector3(10, 3, 8), Vector3(10, 0.1, 8), 0)
	expect(collision.surface == "actor" and collision.normal == Vector3.UP, "descending head impact has a valid upward splash normal")

func _test_timing() -> void:
	var sim = quiet()
	sim.step(179.99)
	expect(sim.state == "playing" and sim.time_left > 0.0, "match lasts full180 seconds")
	sim.step(0.02)
	expect(sim.state == "finished" and sim.winner == -1 and sim.time_left == 0.0, "unpainted match resolves as draw at180")
	expect(has_event(sim, "finished"), "finish event")
	var pos: Vector2 = sim.actors[0].pos
	sim.step(10.0, {"move": Vector2.RIGHT, "shoot": true})
	expect(sim.actors[0].pos == pos and sim.projectiles.is_empty(), "finished match freezes commands")
	sim = quiet()
	sim._paint_disc(Vector2(6.5, 8.5), 0.4, 1)
	sim.step(180.0)
	expect(sim.winner == 1, "territory count decides winner")
	sim.start(9)
	expect(sim.state == "playing" and sim.time_left == Sim.MATCH_DURATION and sim.winner == -2 and sim.score == [0.0, 0.0], "restart fully resets result")
	expect(sim.pods.is_empty() and sim.projectiles.is_empty() and sim.events.size() == 1, "restart clears stale entities and events")
	sim.step(-1.0); sim.step(NAN)
	expect(sim.time_left == Sim.MATCH_DURATION, "invalid delta does not corrupt clock")
	sim.step(0.001, {"dash": true, "move": Vector2.RIGHT})
	sim.step(0.02, {"dash": false, "move": Vector2.RIGHT})
	expect(sim.actors[0].dash_cd > 0.0, "edge survives sub-fixed-step frame")
	sim.step(0.1, {"move": Vector2(NAN, INF), "aim": Vector2(NAN, INF), "shoot": true})
	expect(sim.actors[0].pos.is_finite() and sim.actors[0].aim.is_finite(), "nonfinite input cannot corrupt actor")
	for shot in sim.projectiles:
		expect(shot.pos.is_finite() and is_finite(shot.life), "nonfinite aim cannot corrupt projectiles")
	expect(not sim.damage_actor(0, NAN, 2), "nonfinite damage rejected")
	var drained: Array = sim.drain_events()
	expect(not drained.is_empty() and sim.events.is_empty() and sim.drain_events().is_empty(), "events drain once")

func _test_bots_and_determinism() -> void:
	var a = Sim.new(); var b = Sim.new()
	a.start(735); b.start(735)
	var input := {"move": Vector2.RIGHT, "aim": Vector2(8.5, 10.5), "shoot": true}
	for _frame in 300: a.step(Sim.FIXED_DT, input)
	for _frame in 10: b.step(0.5, input)
	expect(a.ownership == b.ownership and a.actors == b.actors and a.projectiles == b.projectiles and a.pods == b.pods, "same seed and command fixed-step deterministic across low FPS partitions")
	expect(is_equal_approx(a.time_left, b.time_left), "low FPS clock preserves elapsed time")
	var c = Sim.new(); c.start(12)
	c.step(180.0)
	expect(c.state == "finished" and c.time_left == 0.0, "full bot match reaches terminal result")
	expect(c.score[0] > 5.0 and c.score[1] > 5.0, "both bot teams claim substantial turf")
	var shots := 0
	var defeats := 0
	for actor in c.actors:
		shots += int(actor.shots); defeats += int(actor.defeats)
		expect(c._actor_position_clear(actor.pos, actor.team), "bots never cross cover or hostile spawn")
		expect(actor.water >= 0.0 and actor.water <= Sim.MAX_WATER, "water stays bounded")
	expect(shots > 500, "bots continue shooting and reloading all match")
	expect(defeats > 0, "bots fight rather than only paint")
	expect(c.pods.size() <= 4, "bot pod capacity stays bounded")
	print("  Full seed12: coverage=%s shots=%d defeats=%d" % [c.score, shots, defeats])
