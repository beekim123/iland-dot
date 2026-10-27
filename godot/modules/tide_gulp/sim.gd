extends RefCounted
## Deterministic, rendering-independent XY simulation. +Y points UP.
## Public: start/restart, command({move,target,use_target,dash}), tick(dt),
## drain_events, snapshot, set_paused, finish, relation, mouth_position,
## tide_state, stats_snapshot, biome_at. No hub, scene, audio, or input imports.
const Catalog = preload("data/catalog.gd")
const STAGE_LENGTHS = Catalog.STAGE_LENGTHS
const MAX_STEP := 1.0 / 60.0
const EPSILON := 0.000001
var tuning: Dictionary = Catalog.TUNING.duplicate(true)
var species: Dictionary = Catalog.SPECIES.duplicate(true)
var player: Dictionary = {}
var fish: Array[Dictionary] = []
var chunks: Dictionary = {}
var events: Array[Dictionary] = []
var stats: Dictionary = {}
var elapsed := 0.0
var alive := true
var paused := false
var score := 0
var seed_value := 12345
var rng := RandomNumberGenerator.new()
var _input_move := Vector2.ZERO
var _input_target := Vector2.ZERO
var _use_target := false
var _dash_requested := false
var _nutrition := 0.0
var _chunk_memory: Dictionary = {}
var _next_fish_id := 1
var _tide_phase := "calm"
var _last_biome := "shallow"
var _finished := false
var _world_center := 2147483647
var _spawn_clock := 0.0

func start(new_seed: int = 12345) -> void:
	seed_value = new_seed
	rng.seed = seed_value
	elapsed = 0.0; score = 0; alive = true; paused = false; _finished = false
	_nutrition = 0.0; _next_fish_id = 1; _spawn_clock = 0.0
	_input_move = Vector2.ZERO; _input_target = Vector2.ZERO; _use_target = false; _dash_requested = false
	_tide_phase = "calm"; _last_biome = "shallow"; _world_center = 2147483647
	fish.clear(); chunks.clear(); events.clear(); _chunk_memory.clear()
	player = {"pos": Vector2.ZERO, "dir": Vector2.RIGHT, "velocity": Vector2.ZERO,
		"length": 1.0, "target_length": 1.0, "stage": 1, "growth": 0.0,
		"dash_left": 0.0, "dash_cooldown": 0.0}
	stats = {"eaten": 0, "effective_eaten": 0, "tiny_eaten": 0, "dashes": 0,
		"max_stage": 1, "distance": 0.0, "threats_escaped": 0, "visited_biomes": ["shallow"],
		"max_fish": 0, "max_chunks": 0, "death_species": "", "reason": ""}
	_update_world()
	_emit({"type": "start", "seed": seed_value, "pos": player.pos})

func restart(new_seed: int = -1) -> void:
	start(seed_value if new_seed == -1 else new_seed)
	_emit({"type": "restart", "seed": seed_value})

func set_paused(value: bool) -> void:
	paused = value
	if value:
		_input_move = Vector2.ZERO; _use_target = false; _dash_requested = false

func command(input: Dictionary) -> void:
	if paused or not alive or _finished: return
	if input.has("move"):
		_input_move = (input.move as Vector2).limit_length(1.0)
	if input.has("target"): _input_target = input.target
	if input.has("use_target"): _use_target = bool(input.use_target)
	if bool(input.get("dash", false)): _dash_requested = true

func tick(dt: float) -> void:
	if paused or not alive or _finished or dt <= 0.0: return
	# Substeps prevent high-speed mouth/reef tunnelling and preserve cooldowns.
	var remaining := dt
	while remaining > EPSILON and alive and not _finished:
		var step := minf(MAX_STEP, remaining)
		_step(step)
		remaining -= step

func _step(dt: float) -> void:
	elapsed += dt
	var tide := tide_state()
	if tide.phase != _tide_phase:
		_tide_phase = tide.phase
		_emit({"type": "tide", "phase": tide.phase, "direction": tide.direction, "pos": player.pos})
	var biome := biome_at(player.pos.x)
	if biome != _last_biome:
		_last_biome = biome
		if not biome in stats.visited_biomes: stats.visited_biomes.append(biome)
		_emit({"type": "biome", "biome": biome})
	_update_player(dt)
	_update_world()
	for body in fish: _update_fish(body, dt)
	_check_contacts()
	if not alive: return
	_update_growth(dt)
	_spawn_clock += dt
	if _spawn_clock >= 1.0:
		_spawn_clock = 0.0
		_replenish_active()
		_prune_memory()
	stats.max_fish = maxi(int(stats.max_fish), fish.size())
	stats.max_chunks = maxi(int(stats.max_chunks), chunks.size())

func _update_player(dt: float) -> void:
	player.dash_left = maxf(0.0, float(player.dash_left) - dt)
	player.dash_cooldown = maxf(0.0, float(player.dash_cooldown) - dt)
	if _dash_requested and float(player.dash_cooldown) <= EPSILON:
		player.dash_left = float(tuning.dash_duration)
		player.dash_cooldown = float(tuning.dash_cooldown)
		stats.dashes += 1
		_emit({"type": "dash", "pos": player.pos})
	_dash_requested = false
	var move: Vector2 = _input_move
	if move.length_squared() < 0.001 and _use_target:
		var offset: Vector2 = _input_target - player.pos
		move = offset.normalized() * minf(1.0, offset.length() / 0.9) if offset.length() > 0.15 else Vector2.ZERO
	if move.length_squared() > 0.001: player.dir = move.normalized()
	var speed := float(tuning.player_speed)
	if float(player.dash_left) > 0:
		speed *= float(tuning.dash_multiplier)
		if move.length_squared() < 0.001: move = player.dir
	var velocity: Vector2 = player.velocity
	velocity = velocity.move_toward(move * speed, float(tuning.player_acceleration) * dt)
	player.velocity = velocity
	var old_pos: Vector2 = player.pos
	player.pos = _move_body(old_pos, velocity * dt + current_velocity(speed / (float(tuning.dash_multiplier) if float(player.dash_left) > 0 else 1.0)) * dt, body_radius(player))
	stats.distance += old_pos.distance_to(player.pos)

func body_radius(body: Dictionary) -> float:
	# Conservative body-length circle: fins excluded, reef contact never hides overlap.
	return float(body.length) * 0.5

func mouth_position(body: Dictionary) -> Vector2:
	return (body.pos as Vector2) + (body.dir as Vector2) * float(body.length) * 0.48

func relation(other_length: float, player_length: float = -1.0) -> String:
	var own := float(player.length) if player_length < 0.0 else player_length
	if other_length <= 0.8 * own + EPSILON: return "food"
	if other_length >= 1.25 * own - EPSILON: return "danger"
	return "peer"

func tide_state() -> Dictionary:
	var cycle := int(floor(elapsed / float(tuning.tide_period)))
	var phase_time := fmod(elapsed, float(tuning.tide_period))
	var direction := Vector2.RIGHT if cycle % 2 == 0 else Vector2.LEFT
	var phase := "calm"
	var remaining := float(tuning.tide_calm) - phase_time
	if phase_time >= float(tuning.tide_calm) + float(tuning.tide_warning):
		phase = "flow"; remaining = float(tuning.tide_period) - phase_time
	elif phase_time >= float(tuning.tide_calm):
		phase = "warning"; remaining = float(tuning.tide_calm) + float(tuning.tide_warning) - phase_time
	return {"phase": phase, "direction": direction, "remaining": maxf(0, remaining), "strength": float(tuning.current_fraction) if phase == "flow" else 0.0}

func current_velocity(base_speed: float) -> Vector2:
	# This hot path shares the exact tide law without allocating a UI dictionary.
	if fmod(elapsed, float(tuning.tide_period)) < float(tuning.tide_calm) + float(tuning.tide_warning): return Vector2.ZERO
	var direction := 1.0 if int(floor(elapsed / float(tuning.tide_period))) % 2 == 0 else -1.0
	return Vector2(direction * float(tuning.current_fraction) * base_speed, 0.0)

func _update_fish(body: Dictionary, dt: float) -> void:
	var def: Dictionary = species[body.species]
	var old_pos: Vector2 = body.pos
	var to_player: Vector2 = player.pos - body.pos
	var distance := to_player.length()
	var danger := relation(body.length) == "danger"
	body.threat = danger
	body.state_left = maxf(0.0, float(body.state_left) - dt)
	body.warning_left = maxf(0.0, float(body.warning_left) - dt)
	var safe := elapsed < float(tuning.start_safe_seconds) or (player.pos as Vector2).length() < float(tuning.start_safe_radius)
	var notice := maxf(7.5, float(body.length) * 2.1)
	var desired: Vector2 = body.dir
	var speed := float(def.speed)
	var turn := float(def.turn)
	if not danger or safe:
		if body.state != "cruise":
			body.state = "cruise"; body.armed = false; body.chase_time = 0.0
	elif body.state == "cruise" and distance < notice:
		body.state = "alert"; body.state_left = float(tuning.first_warning)
		body.warning_left = float(tuning.first_warning); body.chase_time = 0.0
		body.lunges = 0; body.armed = false
		_emit({"type": "threat", "id": body.id, "species": body.species, "pos": body.pos, "duration": float(tuning.first_warning), "direction": to_player.normalized()})
	if body.state != "cruise" and body.state != "retreat":
		body.chase_time += dt
		if float(body.chase_time) > float(tuning.chase_limit) or distance > notice * 1.8:
			_begin_retreat(body)
	match String(body.state):
		"alert":
			desired = to_player.normalized(); speed *= 0.24; turn = minf(turn, 0.8)
			if float(body.state_left) <= EPSILON:
				body.state = "windup"; body.state_left = float(tuning.windup)
		"windup":
			desired = to_player.normalized(); speed = 0.0; turn = minf(turn, 0.7)
			if float(body.state_left) <= EPSILON:
				body.state = "lunge"; body.state_left = 0.65; body.armed = true; body.lunges += 1
				_emit({"type": "lunge", "id": body.id, "pos": body.pos})
		"lunge":
			speed = maxf(float(def.speed) * 2.6, 5.4); turn = 0.0
			if float(body.state_left) <= EPSILON:
				body.state = "recover"; body.state_left = float(tuning.recovery); body.armed = false
		"recover":
			speed *= 0.22; turn *= 0.4
			if float(body.state_left) <= EPSILON:
				if int(body.lunges) >= int(tuning.max_lunges): _begin_retreat(body)
				else:
					body.state = "windup"; body.state_left = float(tuning.windup)
		"retreat":
			desired = -to_player.normalized(); speed *= 0.8
			if float(body.state_left) <= EPSILON: body.state = "cruise"
		_:
			desired = _cruise_direction(body, def)
			if not danger and relation(body.length) == "food" and distance < 2.3:
				desired = (desired * 0.65 - to_player.normalized() * 0.65).normalized()
				speed *= 1.12
	# Resident fish stay around their home chunk; pursuing has finite leash.
	var home_x := float(body.home_chunk) * float(tuning.chunk_width)
	if body.state == "cruise" and absf(body.pos.x - home_x) > float(tuning.chunk_width) * 0.44:
		desired = Vector2(signf(home_x - body.pos.x), desired.y * 0.25).normalized()
	if absf(body.pos.y) > float(tuning.half_height) - body_radius(body) - 0.5:
		desired.y = -signf(body.pos.y) * 0.9
	if desired.length_squared() > 0.001:
		var angle := rotate_toward((body.dir as Vector2).angle(), desired.angle(), turn * dt)
		body.dir = Vector2.from_angle(angle)
	body.velocity = (body.dir as Vector2) * speed
	body.pos = _move_body(body.pos, (body.velocity as Vector2) * dt + current_velocity(float(def.speed)) * dt, body_radius(body))
	if old_pos.distance_squared_to(body.pos) < 0.00001 and speed > 0.2 and body.state == "cruise":
		body.dir = Vector2((body.dir as Vector2).x * -1.0, -signf(body.pos.y) * 0.6).normalized()

func _cruise_direction(body: Dictionary, def: Dictionary) -> Vector2:
	var phase := elapsed * 0.7 + float(body.phase)
	var heading := float(body.heading)
	match String(def.behavior):
		"school": return Vector2(heading, sin(phase) * 0.22).normalized()
		"wander": return Vector2(heading, sin(phase * 0.55) * 0.7).normalized()
		"weave": return Vector2(heading, sin(phase * 1.5) * 0.85).normalized()
		"drift": return Vector2(heading * 0.55, sin(phase * 0.4) * 0.6).normalized()
		"graze": return Vector2(heading, sin(phase * 0.3) * 0.35).normalized()
		_: return Vector2(heading, sin(phase * 0.3) * 0.15).normalized()

func _begin_retreat(body: Dictionary) -> void:
	if body.state != "retreat": stats.threats_escaped += 1
	body.state = "retreat"; body.state_left = 4.0; body.armed = false; body.warning_left = 0.0

func _check_contacts() -> void:
	for i in range(fish.size() - 1, -1, -1):
		var body: Dictionary = fish[i]
		var kind := relation(body.length)
		var distance := (body.pos as Vector2).distance_to(player.pos)
		if distance > float(body.length) + float(player.length): continue
		if kind == "food":
			var eat_radius := float(player.length) * 0.20 + float(body.length) * 0.22
			if mouth_position(player).distance_to(body.pos) <= eat_radius:
				_eat(i)
		elif kind == "danger":
			var bite_radius := float(body.length) * 0.16 + float(player.length) * 0.18
			if bool(body.armed) and mouth_position(body).distance_to(player.pos) <= bite_radius:
				_die(body)
				return
			_soft_push(body)
		else:
			_soft_push(body)

func _soft_push(body: Dictionary) -> void:
	# Body sides/tails push, never damage. Smaller than conservative reef radius
	# so approaching the visible mouth remains possible.
	var minimum := float(player.length) * 0.23 + float(body.length) * 0.23
	var offset: Vector2 = player.pos - body.pos
	var distance := offset.length()
	if distance >= minimum: return
	var axis := offset / distance if distance > EPSILON else Vector2.UP
	var overlap := minimum - distance
	player.pos = _move_body(player.pos, axis * overlap * 0.65, body_radius(player))
	body.pos = _move_body(body.pos, -axis * overlap * 0.35, body_radius(body))

func _eat(index: int) -> void:
	var body: Dictionary = fish[index]
	var ratio := float(body.length) / float(player.length)
	var points := 0
	var nutrition := 0.0
	stats.eaten += 1
	if ratio < 0.35 - EPSILON:
		stats.tiny_eaten += 1
		player.dash_cooldown = maxf(0, float(player.dash_cooldown) - 0.08)
	else:
		stats.effective_eaten += 1
		var value := 0.45 if ratio < 0.5 else (1.0 if ratio < 0.65 else 1.8)
		nutrition = value * float(species[body.species].nutrition)
		points = int(round(nutrition * 100.0))
		_nutrition += nutrition; score += points
	if points > 0:
		_emit({"type": "score", "delta": points, "score": score, "source": "effective_food"})
	_record_depletion(body)
	fish.remove_at(index)
	_emit({"type": "eat", "id": body.id, "species": body.species, "pos": body.pos, "points": points, "score": score, "nutrition": nutrition, "tiny": points == 0})

func _update_growth(dt: float) -> void:
	var thresholds: Array = Catalog.GROWTH_THRESHOLDS
	var target_stage := 1
	for i in range(1, thresholds.size()):
		if _nutrition >= float(thresholds[i]): target_stage = i + 1
	var target := float(STAGE_LENGTHS[target_stage - 1])
	var growth := 1.0
	if target_stage < STAGE_LENGTHS.size():
		growth = clampf((_nutrition - float(thresholds[target_stage - 1])) / (float(thresholds[target_stage]) - float(thresholds[target_stage - 1])), 0.0, 1.0)
		target = lerpf(float(STAGE_LENGTHS[target_stage - 1]), float(STAGE_LENGTHS[target_stage]), growth)
	player.target_length = target
	var next_length := move_toward(float(player.length), target, float(tuning.growth_rate) * dt)
	if next_length > float(player.length):
		# Incremental displacement plus a guaranteed open trunk prevents trapping.
		var candidate := _resolve_position(player.pos, next_length * 0.5)
		if position_clear(candidate, next_length * 0.5):
			player.pos = candidate; player.length = next_length
	var actual_stage := 1
	for i in range(1, STAGE_LENGTHS.size()):
		if float(player.length) >= float(STAGE_LENGTHS[i]) - EPSILON: actual_stage = i + 1
	if actual_stage > int(player.stage):
		player.stage = actual_stage; stats.max_stage = maxi(int(stats.max_stage), actual_stage)
		_emit({"type": "grow", "stage": actual_stage, "length": player.length, "pos": player.pos})
	player.growth = growth if actual_stage == target_stage else 1.0

func _die(body: Dictionary) -> void:
	if not alive: return
	alive = false; stats.death_species = body.species; stats.reason = "eaten"
	_input_move = Vector2.ZERO; _dash_requested = false
	_emit({"type": "death", "id": body.id, "species": body.species, "pos": player.pos, "stats": stats_snapshot()})
	finish("eaten")

func finish(reason: String = "return") -> Dictionary:
	if not _finished:
		_finished = true; stats.reason = reason
		_emit({"type": "stats", "stats": stats_snapshot()})
		_emit({"type": "finished", "reason": reason, "stats": stats_snapshot()})
	return stats_snapshot()

func stats_snapshot() -> Dictionary:
	var result := stats.duplicate(true)
	result.score = score; result.elapsed = elapsed; result.stage = int(player.get("stage", 1))
	result.length = float(player.get("length", 1.0)); result.seed = seed_value
	return result

func snapshot() -> Dictionary:
	return {"player": player.duplicate(true), "fish": fish.duplicate(true), "chunks": chunks.duplicate(true),
		"elapsed": elapsed, "alive": alive, "paused": paused, "score": score, "stats": stats_snapshot(),
		"tide": tide_state(), "biome": biome_at(player.pos.x)}

func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = events.duplicate(true)
	events.clear()
	return result

func _emit(event: Dictionary) -> void:
	event.time = elapsed
	if events.size() >= int(tuning.max_events): events.pop_front()
	events.append(event)

func chunk_index(x: float) -> int:
	return int(floor((x + float(tuning.chunk_width) * 0.5) / float(tuning.chunk_width)))

func biome_at(x: float) -> String:
	var index := absi(chunk_index(x))
	if index <= 2: return "shallow"
	return ["kelp", "ruins", "shallow"][int((index - 3) / 3) % 3]

func _chunk_seed(index: int, salt: int = 0) -> int:
	return absi((seed_value * 73856093) ^ (index * 19349663) ^ (salt * 83492791))

func _make_chunk(index: int) -> Dictionary:
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = _chunk_seed(index)
	var biome := biome_at(float(index) * float(tuning.chunk_width))
	var variant := local_rng.randi_range(0, 3)
	var module_id := "%s_%d" % [biome, variant]
	var source: Array = Catalog.MODULES[biome][variant]
	if index == 0:
		module_id = "safe_start"
		source = [Rect2(-8, -7, 3, 3), Rect2(6, 4.0, 3, 3)]
	elif absi(index) % 9 == 2:
		module_id = "shallow_kelp"; source = Catalog.TRANSITIONS.shallow_kelp
	elif absi(index) % 9 == 5:
		module_id = "kelp_ruins"; source = Catalog.TRANSITIONS.kelp_ruins
	var obstacles: Array[Rect2] = []
	for rect: Rect2 in source:
		obstacles.append(Rect2(rect.position + Vector2(index * float(tuning.chunk_width), 0), rect.size))
	return {"index": index, "biome": biome, "module_id": module_id,
		"rect": Rect2(index * float(tuning.chunk_width) - float(tuning.chunk_width) * 0.5, -float(tuning.half_height), float(tuning.chunk_width), float(tuning.half_height) * 2),
		"obstacles": obstacles}

func _update_world() -> void:
	var center := chunk_index(player.pos.x)
	if center == _world_center: return
	_world_center = center
	var radius := int(tuning.active_radius)
	for key in chunks.keys():
		if absi(int(key) - center) > radius: chunks.erase(key)
	for i in range(fish.size() - 1, -1, -1):
		if not chunks.has(fish[i].home_chunk): fish.remove_at(i)
	for index in range(center - radius, center + radius + 1):
		if not chunks.has(index):
			chunks[index] = _make_chunk(index)
			_spawn_chunk(index)
	_prune_memory()

func _spawn_chunk(index: int) -> void:
	for slot in int(tuning.fish_per_chunk): _spawn_slot(index, slot)

func _spawn_slot(index: int, slot: int) -> bool:
	for body in fish:
		if int(body.home_chunk) == index and int(body.slot) == slot: return false
	var memory: Dictionary = _chunk_memory.get(index, {})
	if float(memory.get(slot, -1.0)) > elapsed: return false
	var local_rng := RandomNumberGenerator.new()
	# A fixed epoch per slot after natural replenishment, never player growth.
	var epoch := int(floor(elapsed / float(tuning.food_respawn_seconds)))
	local_rng.seed = _chunk_seed(index, slot + epoch * 103 + 1)
	var biome: String = chunks[index].biome
	var pool: Array = Catalog.BIOME_POOLS[biome]
	var key: String = pool[slot % pool.size()]
	if index == 0: key = "silver" if slot < 8 else "fan"
	var def: Dictionary = species[key]
	var length := local_rng.randf_range(float(def.length_min), float(def.length_max))
	var x := index * float(tuning.chunk_width) + local_rng.randf_range(-10.5, 10.5)
	var y := local_rng.randf_range(-5.5, 5.5)
	if index == 0 and slot < 6:
		x = 1.9 + float(slot % 3) * 2.0; y = float(slot / 3) * 1.3 - 0.5
	var pos := _resolve_position(Vector2(x, y), length * 0.5)
	# New dangerous fish cannot appear in the player's response envelope.
	if relation(length) == "danger":
		if pos.distance_to(player.pos) < maxf(float(tuning.spawn_clearance), float(def.speed) * 2.6 * float(tuning.first_warning) + length): return false
		if pos.length() < float(tuning.start_safe_radius) + length: return false
	# Replenishment is time-limited and never visible next to the player.
	if elapsed > 0.1 and pos.distance_to(player.pos) < 12.5: return false
	if not position_clear(pos, length * 0.5): return false
	var heading := -1.0 if local_rng.randf() < 0.5 else 1.0
	fish.append({"id": _next_fish_id, "species": key, "pos": pos, "dir": Vector2(heading, 0), "velocity": Vector2.ZERO,
		"length": length, "state": "cruise", "state_left": 0.0, "warning_left": 0.0, "threat": relation(length) == "danger",
		"home_chunk": index, "slot": slot, "phase": local_rng.randf_range(0, TAU), "heading": heading,
		"armed": false, "chase_time": 0.0, "lunges": 0})
	_next_fish_id += 1
	return true

func _replenish_active() -> void:
	for index in chunks: _spawn_chunk(index)

func _record_depletion(body: Dictionary) -> void:
	var index := int(body.home_chunk)
	if not _chunk_memory.has(index): _chunk_memory[index] = {}
	_chunk_memory[index][int(body.slot)] = elapsed + float(tuning.food_respawn_seconds)

func _prune_memory() -> void:
	for index in _chunk_memory.keys():
		var memory: Dictionary = _chunk_memory[index]
		for slot in memory.keys():
			if float(memory[slot]) <= elapsed: memory.erase(slot)
		if memory.is_empty(): _chunk_memory.erase(index)
	# Normal travel can visit far fewer than 128 chunks within the 120s food TTL.
	# This defensive limit also bounds externally teleported/debug simulations.
	while _chunk_memory.size() > int(tuning.max_chunk_memory):
		var oldest = _chunk_memory.keys()[0]
		var oldest_time := INF
		for index in _chunk_memory:
			var latest := 0.0
			for value in _chunk_memory[index].values(): latest = maxf(latest, float(value))
			if latest < oldest_time: oldest_time = latest; oldest = index
		_chunk_memory.erase(oldest)

func memory_counts() -> Dictionary:
	return {"chunks": chunks.size(), "fish": fish.size(), "depleted_chunks": _chunk_memory.size(), "events": events.size()}

func position_clear(pos: Vector2, radius: float) -> bool:
	if absf(pos.y) + radius > float(tuning.half_height) + EPSILON: return false
	for key in range(chunk_index(pos.x) - 1, chunk_index(pos.x) + 2):
		if not chunks.has(key): continue
		for rect: Rect2 in chunks[key].obstacles:
			if pos.x + radius < rect.position.x or pos.x - radius > rect.end.x or pos.y + radius < rect.position.y or pos.y - radius > rect.end.y: continue
			var nearest := Vector2(clampf(pos.x, rect.position.x, rect.end.x), clampf(pos.y, rect.position.y, rect.end.y))
			if nearest.distance_squared_to(pos) < radius * radius - EPSILON: return false
	return true

func _move_body(pos: Vector2, delta: Vector2, radius: float) -> Vector2:
	# Most fish are in open water; skip the costly recovery solver there.
	if position_clear(pos + delta, radius): return pos + delta
	# Axis sliding prevents corners from pinning input; substeps limit tunnelling.
	var result := _resolve_position(Vector2(pos.x + delta.x, pos.y), radius)
	result = _resolve_position(Vector2(result.x, result.y + delta.y), radius)
	return result

func _resolve_position(pos: Vector2, radius: float) -> Vector2:
	var result := pos
	result.y = clampf(result.y, -float(tuning.half_height) + radius, float(tuning.half_height) - radius)
	for _iteration in 4:
		var changed := false
		for key in range(chunk_index(result.x) - 1, chunk_index(result.x) + 2):
			if not chunks.has(key): continue
			for rect: Rect2 in chunks[key].obstacles:
				var nearest := Vector2(clampf(result.x, rect.position.x, rect.end.x), clampf(result.y, rect.position.y, rect.end.y))
				var difference := result - nearest
				var distance := difference.length()
				if distance >= radius - EPSILON: continue
				changed = true
				if distance > EPSILON:
					result = nearest + difference / distance * (radius + 0.0001)
				else:
					var options := [Vector2(rect.position.x - radius - 0.0001, result.y), Vector2(rect.end.x + radius + 0.0001, result.y), Vector2(result.x, rect.position.y - radius - 0.0001), Vector2(result.x, rect.end.y + radius + 0.0001)]
					var best := INF
					for option: Vector2 in options:
						if absf(option.y) + radius > float(tuning.half_height): continue
						var cost := result.distance_squared_to(option)
						if cost < best: best = cost; nearest = option
					result = nearest
		result.y = clampf(result.y, -float(tuning.half_height) + radius, float(tuning.half_height) - radius)
		if not changed: break
	if not position_clear(result, radius):
		# Authored invariant: the trunk y=0 is always navigable even at adult size.
		result.y = 0.0
	return result
