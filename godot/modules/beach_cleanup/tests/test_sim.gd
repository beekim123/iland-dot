extends SceneTree
const Sim = preload("../sim.gd")
const Maps = preload("../data/maps.gd")
const Witness = preload("../data/witness.gd")
var assertions := 0
var failures := 0

func expect(value: bool, label: String) -> void:
	assertions += 1
	if not value: failures += 1; printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for map_id in 3:
		for variant in 3:
			var sim = Sim.new(); sim.start(map_id,variant)
			expect(sim.remaining.size() == [24,30,36][map_id],"authored item count")
			expect(sim.map_data.depots.size() == (2 if map_id == 2 else 1),"authored depots")
			var kinds := {}
			for item: Dictionary in sim.map_data.trash: kinds[item.type] = true
			expect(kinds.size() == 6,"six distinct item types")
			var bulk_count := 0
			for item: Dictionary in sim.map_data.trash:
				if item.cost == 3: bulk_count += 1
			expect(bulk_count == [2,4,6][map_id], "authored bulky pacing")
			var initial := sim.snapshot()
			var count := 0
			while not sim.remaining.is_empty():
				var id: String = sim.nearest_hint().id
				if not Witness.collect_one(sim,id):
					expect(false,"reachable map %d variant %d item %s pos %s" % [map_id,variant,id,sim.pos]); break
				count += 1
				expect(sim.capacity_used() <= 12,"capacity never exceeded")
				expect(sim.remaining.size()+sim.cargo.size()+sim.delivered.size() == initial.remaining.size(),"partition conserved")
				var saved: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
				var copy = Sim.new()
				expect(copy.restore(saved),"roundtrip save")
				expect(copy.remaining == sim.remaining and copy.cargo == sim.cargo and copy.delivered == sim.delivered and copy.pos.is_equal_approx(sim.pos) and is_equal_approx(copy.distance,sim.distance),"roundtrip state IDs and numeric tolerance")
				if count == 5: sim = copy
			expect(sim.phase == "cleaning","final ground pickup not completion")
			expect(Witness.unload(sim),"last depot reachable")
			expect(sim.phase == "complete" and sim.cargo.is_empty() and sim.delivered.size() == initial.remaining.size(),"all delivered complete")
			expect(sim.restored_zones.size() == sim.map_data.zones.size(),"all ecology zones restored")
			var finished = Sim.new()
			expect(finished.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))) and finished.phase == "complete", "completed game restores")
			print("WITNESS map=",map_id," variant=",variant," collected=",count," distance=",snappedf(sim.distance,0.01)," unloads=",sim.unloads)
	_test_rules()
	_test_moving_grab()
	print("BEACH SIM: ",assertions," assertions; ",failures," failures")
	quit(0 if failures == 0 else 1)

func _test_rules() -> void:
	var sim = Sim.new(); sim.start()
	var id: String = sim.remaining[0]
	var target: Vector2 = sim.item_by_id(id).pos
	expect(Witness.drive(sim,Witness.route(sim,target,id)),"test position reachable")
	var aim: Vector2 = (target - sim.pos).normalized()
	sim.command({"move":-aim}); sim.tick(0.001); sim.command({"move":Vector2.ZERO,"grab":true}); sim.tick(1)
	expect(sim.remaining.has(id),"behind cannot collect")
	sim.command({"move":aim}); sim.tick(0.001); sim.command({"move":Vector2.ZERO}); sim.tick(0.25)
	expect(sim.remaining.has(id),"closure waits half second")
	sim.command({"grab":false}); sim.tick(0.5)
	expect(sim.remaining.has(id) and sim.grab_progress == 0,"release cancels closure")
	sim.command({"grab":true}); sim.tick(0.52)
	expect(not sim.remaining.has(id),"held grab closes")
	var before: Dictionary = sim.snapshot()
	sim.command({"pause":true,"move":Vector2.ONE,"grab":true}); sim.tick(1)
	expect(sim.snapshot() == before,"pause freezes")
	sim.command({"pause":false}); sim.tick(0.5)
	expect(sim.snapshot() == before,"resume does not retain input")
	expect(not sim.line_clear(Vector2(0,-3),Vector2(0,2)),"wall LOS rejects")
	var bad: Dictionary = before.duplicate(true); bad.cargo.append(bad.remaining[0])
	expect(not sim.restore(bad) and sim.snapshot() == before,"duplicate save rejects atomically")
	bad = before.duplicate(true); bad.remaining.pop_back()
	expect(not sim.restore(bad),"missing item save rejects")
	bad = before.duplicate(true); bad.pos = [0,0]
	expect(not sim.restore(bad),"inside rock save rejects")
	bad = before.duplicate(true); bad.phase = "complete"
	expect(not sim.restore(bad),"false completion save rejects")
	bad = before.duplicate(true); bad.restored_zones = ["shell"]
	expect(not sim.restore(bad),"false ecology save rejects")
	bad = before.duplicate(true); bad.version = 999
	expect(not sim.restore(bad),"future version rejects")
	# Fill exactly using legitimate pickups; ordinary unload restores capacity.
	sim.start()
	for next in sim.remaining.duplicate():
		if sim.capacity_used() == 12: break
		if sim.capacity_used()+int(sim.item_by_id(next).cost) <= 12: expect(Witness.collect_one(sim,next),"fill pickup")
	expect(sim.capacity_used() == 12,"full load exactly12")
	var next: String = sim.nearest_hint().id
	target = sim.item_by_id(next).pos
	expect(Witness.drive(sim,Witness.route(sim,target,next)),"full cart approaches trash")
	sim.command({"move":(target-sim.pos).normalized()}); sim.tick(0.001)
	sim.command({"move":Vector2.ZERO,"grab":true}); sim.tick(1)
	expect(sim.remaining.has(next) and sim.capacity_used() == 12,"full cart does not consume target")
	var capacity_event := false
	for event: Dictionary in sim.drain_events():
		if event.type == "capacity": capacity_event = true
	expect(capacity_event,"capacity feedback")
	expect(Witness.unload(sim) and sim.capacity_used() == 0,"unload frees full load")

	# A named authored shortcut really opens, while earlier witnesses prove bypasses.
	sim.start(1,0)
	expect(not sim.is_walkable(Vector2(0,-4.3)),"crate closes shortcut")
	expect(Witness.collect_one(sim,"m1_t04"),"shortcut crate reachable without entering blocked gate")
	expect(sim.is_walkable(Vector2(0,-4.3)),"pickup opens shortcut")
	# Release is not required between pickups: hold and drive into a second target.
	sim.start()
	id = "m0_t00"; target = sim.item_by_id(id).pos
	expect(Witness.drive(sim,Witness.route(sim,target,id)),"held sequence approach")
	sim.command({"move":(target-sim.pos).normalized()}); sim.tick(0.001)
	sim.command({"move":Vector2.ZERO,"grab":true}); sim.tick(0.52)
	expect(sim.cargo.has(id),"held sequence first pickup")
	var second := "m0_t01"
	var path := Witness.route(sim,sim.item_by_id(second).pos,second)
	for waypoint in path:
		var guard := 0
		while sim.pos.distance_to(waypoint) > 0.015 and guard < 120:
			var delta: Vector2 = waypoint-sim.pos
			sim.command({"move":delta.normalized()}); sim.tick(minf(1.0/60.0,delta.length()/4.0)); guard += 1
	target = sim.item_by_id(second).pos
	sim.command({"move":(target-sim.pos).normalized()}); sim.tick(0.001)
	sim.command({"move":Vector2.ZERO}); sim.tick(0.52)
	expect(sim.cargo.has(second),"held input continuously collects second target")

	sim.start(2,0)
	expect(not sim.is_walkable(Vector2(-8.5,0)),"west loop shortcut blocked")
	expect(Witness.collect_one(sim,"m2_t33"),"west loop shortcut reachable via bypass")
	expect(sim.is_walkable(Vector2(-8.5,0)),"west loop shortcut opens")
	expect(not sim.is_walkable(Vector2(8.5,0)),"east loop shortcut blocked")
	expect(Witness.collect_one(sim,"m2_t34"),"east loop shortcut reachable via bypass")
	expect(sim.is_walkable(Vector2(8.5,0)),"east loop shortcut opens")


func _test_moving_grab() -> void:
	# Actual held keyboard+mouse route, not a stationary pickup solver.
	for variant in 3:
		var sim = Sim.new(); sim.start(0,variant)
		var first: Vector2 = sim.item_by_id("m0_t00").pos
		var approach := first + Vector2(-1.45,0)
		expect(Witness.drive(sim,Witness.route(sim,approach)),"moving route approach")
		expect(Witness.drive(sim,PackedVector2Array([approach])),"moving route exact start")
		sim.command({"move":Vector2.RIGHT,"grab":true})
		var braced_frames := 0
		var moving_frames := 0
		for frame in 330:
			sim.tick(1.0/60.0)
			if sim.speed < 0.001 and not sim.grab_target.is_empty(): braced_frames += 1
			if sim.speed > 3.9: moving_frames += 1
		expect(sim.cargo.has("m0_t00") and sim.cargo.has("m0_t01") and sim.cargo.has("m0_t02"),"held WASD+grab automatically collects three consecutive items")
		expect(braced_frames >= 80 and moving_frames > 30,"automatic mechanical pauses and resumed driving")
	# Mouse release and steering away both cancel a partial closure immediately.
	var sim = Sim.new(); sim.start()
	var approach: Vector2 = sim.item_by_id("m0_t00").pos + Vector2(-1.45,0)
	expect(Witness.drive(sim,Witness.route(sim,approach)),"cancel test approach")
	expect(Witness.drive(sim,PackedVector2Array([approach])),"cancel test exact start")
	sim.command({"move":Vector2.RIGHT,"grab":true}); sim.tick(0.2)
	var stopped: Vector2 = sim.pos
	expect(sim.grab_target == "m0_t00" and sim.speed == 0,"cart braces before closure completes")
	sim.tick(0.1)
	expect(sim.pos == stopped and sim.remaining.has("m0_t00"),"brace does not instant-collect")
	sim.command({"grab":false}); sim.tick(1.0/60.0)
	expect(sim.pos.x > stopped.x and sim.grab_target.is_empty() and sim.grab_progress == 0,"mouse release immediately resumes driving")
	sim.command({"grab":true}); sim.tick(0.1)
	stopped = sim.pos
	sim.command({"move":Vector2.DOWN}); sim.tick(1.0/60.0)
	expect(sim.pos.y > stopped.y and sim.grab_target.is_empty() and sim.remaining.has("m0_t00"),"steering outside cone cancels brace without collecting")
