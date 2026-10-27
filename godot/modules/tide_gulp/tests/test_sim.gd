extends SceneTree
const Sim = preload("../sim.gd")
const Catalog = preload("../data/catalog.gd")
var checks := 0
var failures := 0
var started := Time.get_ticks_msec()

func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func clean(seed: int = 42):
	var sim = Sim.new()
	sim.start(seed)
	sim.fish.clear()
	sim.events.clear()
	return sim

func body(sim, length: float, pos: Vector2, direction: Vector2 = Vector2.RIGHT, key: String = "silver") -> Dictionary:
	return {"id": 9000 + sim.fish.size(), "species": key, "pos": pos, "dir": direction, "velocity": Vector2.ZERO,
		"length": length, "state": "cruise", "state_left": 0.0, "warning_left": 0.0, "threat": length >= 1.25,
		"home_chunk": sim.chunk_index(pos.x), "slot": 99 + sim.fish.size(), "phase": 0.0, "heading": direction.x,
		"armed": false, "chase_time": 0.0, "lunges": 0}

func _initialize() -> void:
	boundaries()
	contacts()
	growth_and_geometry()
	movement_and_tide()
	predator_fairness()
	world_and_revisit()
	lifecycle_and_determinism()
	long_run()
	print("TIDE GULP SIM: %d checks, %d failures (%.2fs wall time)" % [checks, failures, (Time.get_ticks_msec() - started) / 1000.0])
	quit(1 if failures else 0)

func boundaries() -> void:
	var sim = clean()
	expect(sim.relation(0.8) == "food", "exact 0.8P is edible")
	expect(sim.relation(0.80001) == "peer", "above 0.8P is peer")
	expect(sim.relation(1.24999) == "peer", "below 1.25P is peer")
	expect(sim.relation(1.25) == "danger", "exact 1.25P is dangerous")
	for length: float in Catalog.STAGE_LENGTHS:
		expect(sim.relation(length * 0.8, length) == "food", "food boundary every growth stage")
		expect(sim.relation(length * 1.25, length) == "danger", "danger boundary every growth stage")
	expect(sim.relation(4.0, 3.05) == "danger" and sim.relation(4.8, 3.05) == "danger", "both apex lengths remain dangerous at adult cap")
	expect(sim.relation(1.65, 1.0) == "danger" and sim.relation(1.65, 2.44) == "food", "fixed former predator becomes edible after growth")
	for size in [0.349, 0.35, 0.499, 0.5, 0.649, 0.65, 0.8]:
		sim = clean()
		sim.player.dash_cooldown = 2.0
		sim.fish.append(body(sim, size, Vector2(0.48, 0)))
		sim._check_contacts()
		expect(sim.fish.is_empty(), "mouth eats edible boundary %s" % size)
		expect((sim.score == 0) == (size < 0.35), "tiny fish no main score %s" % size)
		expect((sim._nutrition == 0.0) == (size < 0.35), "tiny fish no growth %s" % size)
		if size < 0.35: expect(is_equal_approx(sim.player.dash_cooldown, 1.92), "tiny fish only lightly shortens dash cooldown")

func contacts() -> void:
	var sim = clean()
	sim.fish.append(body(sim, 0.6, Vector2(-0.48, 0)))
	sim._check_contacts()
	expect(sim.fish.size() == 1, "player tail cannot auto-swallow")
	sim.player.dir = Vector2.LEFT
	sim._check_contacts()
	expect(sim.fish.is_empty(), "turning mouth toward prey eats")
	sim = clean()
	var big := body(sim, 2.0, Vector2.ZERO, Vector2.RIGHT, "ribbon")
	big.armed = true; big.state = "lunge"
	sim.fish.append(big)
	sim.player.pos = Vector2(-0.96, 0)
	sim._check_contacts()
	expect(sim.alive, "danger tail overlap never kills")
	sim.player.pos = Vector2(0, 0.6)
	sim._check_contacts()
	expect(sim.alive, "danger flank overlap only pushes")
	sim.player.pos = Vector2(0.96, 0)
	sim.player.dash_left = 0.7
	sim._check_contacts()
	expect(not sim.alive, "armed mouth kills even during dash, no invulnerability")
	var death_events := 0
	for event in sim.events:
		if event.type == "death": death_events += 1
	expect(death_events == 1 and sim.stats.reason == "eaten", "one death with cause")
	sim = clean()
	sim.fish.append(body(sim, 1.0, Vector2(0.1, 0)))
	sim._check_contacts()
	expect(sim.alive and sim.fish.size() == 1 and sim.player.pos.x < 0, "same-size fish pushes without eating/damage")
	sim = clean()
	big = body(sim, 2.0, Vector2(-0.96, 0), Vector2.RIGHT, "ribbon")
	sim.fish.append(big); sim._check_contacts()
	expect(sim.alive, "unwarned new threat never contact-kills")

func growth_and_geometry() -> void:
	var sim = clean()
	sim.player.pos = Vector2(6.5, 3.49)
	expect(sim.position_clear(sim.player.pos, 0.5), "growth test starts beside reef")
	sim._nutrition = 10000.0
	var previous := 1.0
	for i in 600:
		sim._update_growth(1.0 / 60.0)
		expect(float(sim.player.length) - previous <= float(sim.tuning.growth_rate) / 60.0 + 0.00001, "continuous growth maximum step")
		expect(sim.position_clear(sim.player.pos, sim.body_radius(sim.player)), "growth resolves reef overlap")
		previous = sim.player.length
	expect(is_equal_approx(sim.player.length, 3.05) and sim.player.stage == 6, "six stages end at exact 3.05 cap")
	expect(sim.stats.max_stage == 6, "growth updates max-stage statistic")
	var grown := 0
	for event in sim.events:
		if event.type == "grow": grown += 1
	expect(grown == 5, "five distinct milestone events")
	for index in range(-40, 41):
		sim.chunks.clear(); sim.chunks[index] = sim._make_chunk(index)
		for x_offset in range(-11, 12):
			expect(sim.position_clear(Vector2(index * 24 + x_offset, 0), 3.05 / 2.0), "all chunk variants retain adult trunk path")
	# Existing fish lengths are fixed and not secretly scaled by player growth.
	sim.start(42)
	var lengths: Array = []
	for one in sim.fish: lengths.append(one.length)
	sim._nutrition = 999.0
	for i in 30: sim._update_growth(1.0)
	for i in sim.fish.size(): expect(lengths[i] == sim.fish[i].length, "growth does not upgrade existing fish")

func movement_and_tide() -> void:
	var sim = clean()
	sim.command({"move": Vector2(8, 8)})
	expect(is_equal_approx(sim._input_move.length(), 1.0), "diagonal input normalized")
	sim.command({"move": Vector2.RIGHT, "dash": true})
	sim.tick(0.05)
	expect(sim.player.dash_left > 0.6 and sim.stats.dashes == 1, "dash begins")
	var first_cd: float = sim.player.dash_cooldown
	sim.command({"dash": true}); sim.tick(0.05)
	expect(sim.stats.dashes == 1 and sim.player.dash_cooldown < first_cd, "cooldown blocks retrigger")
	sim.tick(0.66)
	expect(sim.player.dash_left == 0.0, "dash ends after 0.7 seconds")
	sim.tick(2.3); sim.command({"dash": true}); sim.tick(0.01)
	expect(sim.stats.dashes == 2, "dash ready again after 3 seconds")
	sim = clean()
	sim.command({"move": Vector2.ZERO, "target": Vector2(4, 0), "use_target": true})
	sim.tick(0.4)
	expect(sim.player.pos.x > 0.5, "mouse target steers movement")
	for mark in [0.0, 34.99, 35.0, 39.99, 40.0, 59.99, 60.0]:
		sim.elapsed = mark
		var expected := "calm" if mark < 35.0 or mark >= 60.0 else ("warning" if mark < 40.0 else "flow")
		expect(sim.tide_state().phase == expected, "tide interval %s" % mark)
	sim.elapsed = 40.0
	expect(sim.current_velocity(4.0) == Vector2(1, 0), "flow adds exactly 25 percent base speed")
	expect(sim.current_velocity(4.0) / 4.0 == sim.current_velocity(2.0) / 2.0, "current applies identical fractional law to fish and player")
	expect((-Vector2.RIGHT * 4.0 + sim.current_velocity(4.0)).x < 0.0, "upstream movement remains possible")
	sim.elapsed = 100.0
	expect(sim.current_velocity(4.0).x < 0, "next tide reverses readable direction")
	# Compare actual player drift to actual idle fish drift in a clear region.
	sim = clean(); sim.player.pos = Vector2(48, 0); sim._update_world(); sim.fish.clear()
	sim.elapsed = 40; sim.player.velocity = Vector2.ZERO
	var before: Vector2 = sim.player.pos
	sim._update_player(0.1)
	expect(is_equal_approx(sim.player.pos.x - before.x, 4.2 * 0.25 * 0.1), "actual player receives current at rest")
	sim.species.silver.speed = 4.2
	var f := body(sim, 0.6, Vector2(52, 0)); f.state = "windup"; f.state_left = 1.0
	# A non-danger fish exits windup, so derive its drift against a calm twin.
	var twin = clean(); twin.player.pos = sim.player.pos; twin._update_world(); twin.species.silver.speed = 4.2
	twin.elapsed = sim.elapsed; twin.tuning.current_fraction = 0.0
	var f2 := f.duplicate(true)
	sim._update_fish(f, 0.1); twin._update_fish(f2, 0.1)
	expect(absf((f.pos.x - f2.pos.x) - 4.2 * 0.25 * 0.1) < 0.001, "actual fish receives same current law")

func predator_fairness() -> void:
	var sim = clean()
	sim.elapsed = 10; sim.player.pos = Vector2(25, 0); sim._update_world(); sim.fish.clear()
	var big := body(sim, 2, Vector2(30, 0), Vector2.LEFT, "ribbon")
	sim.fish.append(big)
	sim._update_fish(big, 0.01)
	expect(big.state == "alert" and big.warning_left >= 1.19 and not big.armed, "first threat at least 1.2s warning")
	for i in 70: sim._update_fish(big, 1.0 / 60.0)
	expect(not big.armed, "threat cannot arm before 1.2 seconds")
	for i in 40: sim._update_fish(big, 1.0 / 60.0)
	expect(big.state == "lunge" and big.armed, "windup adds 0.6 seconds then arms mouth")
	var angle: float = big.dir.angle()
	sim.player.pos += Vector2(0, 4)
	sim._update_fish(big, 0.1)
	expect(is_equal_approx(big.dir.angle(), angle), "committed lunge cannot instantly track turn")
	for i in 100: sim._update_fish(big, 1.0 / 60.0)
	expect(not big.armed, "lunge enters nonlethal recovery")
	# Max chase time is absolute even if target stays close.
	big.state = "windup"; big.chase_time = 6.99; big.state_left = 0.6
	sim.player.pos = big.pos + Vector2.LEFT * 4
	sim._update_fish(big, 0.02)
	expect(big.state == "retreat" and not big.armed, "finite pursuit gives retreat window")
	sim = Sim.new(); sim.start(77)
	for f in sim.fish:
		if sim.relation(f.length) == "danger":
			expect(f.pos.distance_to(sim.player.pos) >= 14.0, "initial danger spawn response clearance")
		expect(not bool(sim.species[f.species].apex), "no apex fish in opening shallow chunks")
	# Safe spawn is protected even if a threat is externally moved into it.
	big = body(sim, 4, Vector2(2, 0), Vector2.LEFT, "sailjaw"); big.armed = true; big.state = "lunge"
	sim._update_fish(big, 0.01)
	expect(not big.armed and big.state == "cruise", "safe start never permits armed predator")

func world_and_revisit() -> void:
	var sim = Sim.new(); sim.start(12)
	expect(sim.chunks.size() == 5 and sim.fish.size() <= 60, "resident world and fish bounded at start")
	var target: Dictionary = {}
	for f in sim.fish:
		if f.home_chunk == 0: target = f; break
	var old_slot := int(target.slot)
	sim._record_depletion(target)
	for i in range(sim.fish.size() - 1, -1, -1):
		if sim.fish[i].id == target.id: sim.fish.remove_at(i)
	sim.player.pos = Vector2(240, 0); sim._update_world()
	sim.player.pos = Vector2.ZERO; sim._update_world()
	var found := false
	for f in sim.fish:
		if f.home_chunk == 0 and f.slot == old_slot: found = true
	expect(not found, "leave and revisit does not replenish eaten slot")
	sim.elapsed = 121.0; sim.player.pos = Vector2(240, 0); sim._update_world()
	sim.player.pos = Vector2.ZERO; sim._update_world()
	# Replenishment is also kept away from the player camera (can be delayed).
	expect(sim._chunk_memory.is_empty(), "expired depletion memory pruned")
	var biomes: Dictionary = {}
	var all_species: Dictionary = {}
	for i in range(-100, 101):
		sim.player.pos = Vector2(i * 24, 0); sim._update_world()
		biomes[sim.biome_at(sim.player.pos.x)] = true
		for f in sim.fish: all_species[f.species] = true
		expect(sim.chunks.size() == 5 and sim.fish.size() <= 60, "far traversal world stays bounded")
	expect(biomes.size() == 3, "all three ecologies reachable both directions")
	expect(all_species.size() == 8, "all six ordinary and two apex species in traversable ecology")
	for i in range(200):
		sim._chunk_memory[i] = {1: sim.elapsed + 100.0}
	sim._prune_memory()
	expect(sim._chunk_memory.size() <= 128, "defensive memory cap for debug teleports")

func lifecycle_and_determinism() -> void:
	var sim = Sim.new(); sim.start(421)
	var twin = Sim.new(); twin.start(421)
	expect(sim.snapshot() == twin.snapshot(), "same seed gives exact initial snapshot")
	for i in 300:
		var input := {"move": Vector2(cos(i * 0.02), sin(i * 0.02)), "dash": i % 120 == 0}
		sim.command(input); twin.command(input)
		sim.tick(1.0 / 60.0); twin.tick(1.0 / 60.0)
	expect(sim.snapshot() == twin.snapshot(), "same seed and commands remain exact deterministic")
	var before := sim.snapshot()
	sim.set_paused(true); sim.command({"move": Vector2.RIGHT, "dash": true}); sim.tick(100.0)
	expect(sim.elapsed == before.elapsed and sim.player.pos == before.player.pos, "pause freezes all dangerous time")
	expect(not sim._dash_requested and sim._input_move == Vector2.ZERO, "pause does not queue held movement or dash")
	sim.set_paused(false); sim.tick(0.01)
	expect(sim.elapsed > before.elapsed, "resume advances simulation")
	var results: Dictionary = sim.finish("return")
	expect(results.reason == "return" and sim.alive, "voluntary return is not death")
	var stopped: float = sim.elapsed
	sim.command({"move": Vector2.RIGHT, "dash": true}); sim.tick(5.0)
	expect(not sim._dash_requested, "finished run rejects future dash commands")
	expect(sim.elapsed == stopped, "finished run stops")
	sim.restart(421)
	expect(sim.alive and sim.score == 0 and sim.elapsed == 0 and sim.player.stage == 1, "restart fully resets progress")
	expect(sim.fish.size() <= 60 and sim.chunks.size() == 5 and sim.events.size() == 2, "restart clears stale entities and events")
	var events: Array = sim.drain_events()
	expect(events.size() == 2 and sim.events.is_empty(), "events have one-shot drain contract")
	sim = clean(); sim.tick(10)
	expect(sim.score == 0, "idling has no survival-time score")

func long_run() -> void:
	var sim = Sim.new(); sim.start(8008)
	# Actual 30-minute simulation, without accelerated physics or immunity flags.
	# Alternate bounded exploration with the authored safe origin. A scripted
	# observer routes only through y=0 and keeps dangerous encounters out of the
	# lifecycle stress portion; predator lethality is independently tested above.
	var max_fish := 0
	var max_chunks := 0
	var max_memory := 0
	for second in 1800:
		# Recycle 41 chunks in both directions while retaining real fish AI/time.
		# Teleport is a test fixture, not a player command or shipped mechanic.
		if second % 6 == 0:
			var index := int(20.0 * sin(float(second) * 0.008))
			sim.player.pos = Vector2(index * 24, 0)
			sim._update_world()
		# Move imminent threats to the far edge without disabling their AI.
		for f in sim.fish:
			if sim.relation(f.length) == "danger" and f.pos.distance_to(sim.player.pos) < 12.0:
				f.pos.x = sim.player.pos.x + 17.0
				f.state = "retreat"; f.state_left = 4.0; f.armed = false
		sim.command({"move": Vector2.ZERO})
		sim.tick(1.0)
		max_fish = maxi(max_fish, sim.fish.size()); max_chunks = maxi(max_chunks, sim.chunks.size())
		max_memory = maxi(max_memory, sim._chunk_memory.size())
		if not sim.alive:
			expect(false, "long-run controlled fixture survives; second %d" % second)
			break
	expect(sim.elapsed >= 1799.99, "30 minutes simulation time completed")
	expect(max_fish <= 60 and max_chunks <= 5 and max_memory <= 128 and sim.events.size() <= 128, "30 minute recycle, fish, food memory, events remain bounded")
	print("30-minute fixture: time=%.2f, fish<=%d, chunks<=%d, depletion_chunks<=%d, queued_events=%d" % [sim.elapsed, max_fish, max_chunks, max_memory, sim.events.size()])
