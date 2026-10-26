extends SceneTree
const Sim = preload("../sim.gd")
var checks := 0
var failures := 0
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)
func empty(sim) -> void:
	for p in sim.grid:
		if sim.grid[p] != sim.WALL: sim.grid[p] = sim.EMPTY
	sim.enemies.clear(); sim.invulnerable = 0
func _initialize() -> void:
	var sim = Sim.new(); sim.start(42); empty(sim)
	var cross = sim.blast_cells(Vector2i(3, 3), 2)
	expect(cross.size() == 9, "orthogonal cross")
	expect(not Vector2i(4, 4) in cross, "no diagonal blast")
	sim.grid[Vector2i(4, 3)] = sim.CRATE
	cross = sim.blast_cells(Vector2i(3, 3), 3)
	expect(Vector2i(4, 3) in cross and not Vector2i(5, 3) in cross, "crate blocks beyond first cell")
	expect(not Vector2i(2, 2) in sim.blast_cells(Vector2i(1, 2), 4), "solid stops blast")
	sim.player = Vector2i(1, 1)
	expect(sim.place_bomb(), "place first")
	expect(not sim.place_bomb(), "capacity enforced")
	expect(sim.move(Vector2i.RIGHT), "leave own bomb")
	sim.move_wait = 0
	expect(not sim.move(Vector2i.LEFT), "cannot reenter bomb")
	sim.bombs.clear(); sim.grid[Vector2i(4, 3)] = sim.EMPTY
	sim.bombs[Vector2i(3, 3)] = {"timer": 0.1, "range": 2}
	sim.bombs[Vector2i(5, 3)] = {"timer": 2.4, "range": 2}
	sim.explode(Vector2i(3, 3))
	expect(sim.bombs.is_empty() and sim.flames.has(Vector2i(7, 3)), "chain reaction")
	sim.player = Vector2i(3, 3); sim.check_damage()
	expect(not sim.alive, "blast kills")
	sim.start(42)
	expect(sim.alive and sim.wave == 1 and sim.score == 0, "restart resets")
	expect(sim.grid[Vector2i(1, 2)] == sim.EMPTY and sim.grid[Vector2i(3, 1)] == sim.EMPTY, "safe escape corridor")
	for enemy in sim.enemies: expect(enemy.pos.distance_to(sim.player) >= 6, "enemy spawn clearance")
	sim.enemies.clear(); sim.tick(0.05)
	for i in 31: sim.tick(0.05)
	expect(sim.wave == 2 and sim.enemies.size() > 0, "infinite next wave")
	var twin = Sim.new(); twin.start(42); sim.start(42)
	expect(twin.grid == sim.grid, "seed determinism")
	sim.events.append({"type": "hit"}); sim.start(7)
	expect(sim.events.size() == 1 and sim.events[0].type == "wave", "restart clears stale audio events")
	empty(sim); sim.player = Vector2i(1, 1); sim.place_bomb()
	sim.player = Vector2i(5, 1)
	sim.enemies.append({"id": 99, "pos": Vector2i(11, 9), "wait": 999.0, "kind": 0})
	sim.tick(2.39)
	expect(sim.bombs.size() == 1, "bomb respects fuse")
	sim.tick(0.02)
	expect(sim.bombs.is_empty() and sim.flames.has(Vector2i(1, 1)), "bomb fires on fuse end")
	sim.start(8); empty(sim)
	sim.pickups[Vector2i(3, 1)] = "range"
	sim.bombs[Vector2i(1, 1)] = {"timer": 2.4, "range": 3}
	sim.explode(Vector2i(1, 1))
	expect(not sim.pickups.has(Vector2i(3, 1)), "exposed pickup destroyed by later blast")
	sim.start(9); empty(sim)
	for i in 20:
		sim.player = Vector2i(1, 1); sim.move_wait = 0
		sim.pickups[Vector2i(2, 1)] = "capacity"; sim.move(Vector2i.RIGHT)
	expect(sim.capacity == 5, "capacity cap")
	for i in 20:
		sim.player = Vector2i(1, 1); sim.move_wait = 0
		sim.pickups[Vector2i(2, 1)] = "range"; sim.move(Vector2i.RIGHT)
	expect(sim.blast_range == 6, "range cap")
	for i in 20:
		sim.player = Vector2i(1, 1); sim.move_wait = 0
		sim.pickups[Vector2i(2, 1)] = "speed"; sim.move(Vector2i.RIGHT)
	expect(sim.speed <= 1.65, "speed cap")
	print("GUMMY SIM: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
