extends RefCounted
## Deterministic, rendering-independent gummy blast simulation.
const WIDTH = 13
const HEIGHT = 11
const EMPTY = 0
const WALL = 1
const CRATE = 2
const DIRS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var grid: Dictionary = {}
var bombs: Dictionary = {}
var flames: Dictionary = {}
var pickups: Dictionary = {}
var enemies: Array[Dictionary] = []
var player := Vector2i(1, 1)
var alive := true
var wave := 1
var score := 0
var capacity := 1
var blast_range := 2
var speed := 1.0
var move_wait := 0.0
var invulnerable := 1.5
var wave_wait := -1.0
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func start(seed_value: int = 12345) -> void:
	events.clear()
	rng.seed = seed_value
	wave = 1
	score = 0
	capacity = 1
	blast_range = 2
	speed = 1.0
	generate_wave()

func generate_wave() -> void:
	grid.clear(); bombs.clear(); flames.clear(); pickups.clear(); enemies.clear()
	player = Vector2i(1, 1); alive = true; invulnerable = 1.5; move_wait = 0; wave_wait = -1
	for z in HEIGHT:
		for x in WIDTH:
			var p := Vector2i(x, z)
			var solid: bool = x == 0 or z == 0 or x == WIDTH - 1 or z == HEIGHT - 1 or (x % 2 == 0 and z % 2 == 0)
			grid[p] = WALL if solid else EMPTY
			# A full safe starting corridor guarantees a retreat after the first bomb.
			if not solid and not (z == 1 and x <= 4) and not (x == 1 and z <= 4) and rng.randf() < 0.43:
				grid[p] = CRATE
	var spawns := [Vector2i(11, 9), Vector2i(11, 1), Vector2i(1, 9), Vector2i(7, 7), Vector2i(9, 5), Vector2i(5, 9)]
	for i in mini(2 + wave, spawns.size()):
		var p: Vector2i = spawns[i]
		grid[p] = EMPTY
		for d in DIRS:
			if grid.get(p + d, WALL) != WALL:
				grid[p + d] = EMPTY
		enemies.append({"id": i, "pos": p, "wait": 0.7 + i * 0.12, "kind": i % 3})
	events.append({"type": "wave"})

func passable(p: Vector2i) -> bool:
	return grid.get(p, WALL) == EMPTY and not bombs.has(p)

func move(direction: Vector2i) -> bool:
	if not alive or move_wait > 0 or not direction in DIRS:
		return false
	var target := player + direction
	if not passable(target): return false
	player = target
	move_wait = 0.16 / speed
	if pickups.has(player):
		var kind: String = pickups[player]
		if kind == "range": blast_range = mini(6, blast_range + 1)
		elif kind == "capacity": capacity = mini(5, capacity + 1)
		else: speed = minf(1.65, speed + 0.13)
		pickups.erase(player)
		score += 25
		events.append({"type": "pickup"})
	check_damage()
	return true

func place_bomb() -> bool:
	if not alive or bombs.size() >= capacity or bombs.has(player): return false
	bombs[player] = {"timer": 2.4, "range": blast_range}
	events.append({"type": "place"})
	return true

func blast_cells(origin: Vector2i, reach: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = [origin]
	for d in DIRS:
		for distance in range(1, reach + 1):
			var p: Vector2i = origin + d * distance
			if grid.get(p, WALL) == WALL: break
			result.append(p)
			if grid[p] == CRATE: break
	return result

func explode(origin: Vector2i) -> void:
	if not bombs.has(origin): return
	var reach: int = bombs[origin].range
	bombs.erase(origin)
	var cells := blast_cells(origin, reach)
	events.append({"type": "pop", "pos": origin})
	for p in cells:
		flames[p] = 0.55
		pickups.erase(p)
		if grid.get(p) == CRATE:
			grid[p] = EMPTY
			score += 10
			if rng.randf() < 0.28:
				pickups[p] = ["range", "capacity", "speed"][rng.randi_range(0, 2)]
		if bombs.has(p):
			events.append({"type": "chain"})
			explode(p)
	check_damage()

func check_damage() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		if flames.has(enemies[i].pos):
			enemies.remove_at(i)
			score += 100
	if not alive or invulnerable > 0: return
	var hit := flames.has(player)
	for enemy in enemies:
		if enemy.pos == player: hit = true
	if hit:
		alive = false
		events.append({"type": "hit"})

func tick(dt: float) -> void:
	move_wait = maxf(0, move_wait - dt)
	invulnerable = maxf(0, invulnerable - dt)
	for p in flames.keys():
		flames[p] -= dt
		if flames[p] <= 0: flames.erase(p)
	if not alive: return
	for p in bombs.keys():
		if bombs.has(p):
			bombs[p].timer -= dt
			if bombs[p].timer <= 0: explode(p)
	for enemy in enemies:
		enemy.wait -= dt
		if enemy.wait <= 0:
			enemy.wait = maxf(0.28, 0.62 - wave * 0.018)
			var choices: Array[Vector2i] = []
			for d in DIRS:
				var p: Vector2i = enemy.pos + d
				if passable(p) and not flames.has(p): choices.append(p)
			if not choices.is_empty():
				var target: Vector2i = choices[rng.randi_range(0, choices.size() - 1)]
				if rng.randf() < 0.45:
					for p in choices:
						if p.distance_squared_to(player) < target.distance_squared_to(player): target = p
				enemy.pos = target
	check_damage()
	if alive and enemies.is_empty():
		if wave_wait < 0: wave_wait = 1.5
		wave_wait -= dt
		if wave_wait <= 0:
			wave += 1
			score += 250
			generate_wave()
