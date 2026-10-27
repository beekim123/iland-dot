extends RefCounted
## Rendering-independent deterministic 2v2 turf battle. No scene, input-map or host dependencies.
## Coordinates are Vector2(x, z), in arena units; ownership is row-major, -1/0/1.
## step accepts move (direction), aim (XZ world target), shoot (held), dash/pod (rising edge).
## aim_world is a real Vector3 camera hit; aim_direction is a Vector3 sky ray (never flattened).
## Fine ownership and coverage_rgb are authoritative; navigation remains a separate 1-unit grid.
const WORLD_W := 32.0
const WORLD_H := 24.0
const GRID_W := 384
const GRID_H := 288
const CELL_SIZE := 1.0 / 12.0
const NAV_W := 32
const NAV_H := 24
const NAV_CELL_SIZE := 1.0
const MATCH_DURATION := 180.0
const FIXED_DT := 1.0 / 60.0
const MAX_HP := 100.0
const MAX_WATER := 100.0
const ACTOR_RADIUS := 0.36
const MOVE_SPEED := 4.6
const RESPAWN_TIME := 4.0
const SHOT_INTERVAL := 0.08
const SHOT_WATER := 2.5
const SHOT_DAMAGE := 12.5
const SHOT_SPEED := 19.0
const SHOT_RANGE := 10.5
const SHOT_RADIUS := 0.88
const SHOT_GRAVITY := 18.0
const SHOT_MAX_LIFE := 2.5
const SHOT_HEIGHT := 0.884
const MUZZLE_FORWARD := 1.04
const MUZZLE_SIDE := 0.403
const OBSTACLE_HEIGHT := 1.25
const ACTOR_HEIGHT := 1.8
const ACTOR_CENTER_HEIGHT := 0.9
const POD_HEIGHT := 0.65
const REFILL_DELAY := 0.45
const REFILL_RATE := 30.0
const DASH_SPEED := 12.0
const DASH_DURATION := 0.18
const DASH_COOLDOWN := 3.0
const POD_FUSE := 3.0
const POD_COOLDOWN := 12.0
const POD_RADIUS := 3.2
const POD_HP := 45.0
const POD_HIT_RADIUS := 0.42
const NAV_DIRS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]

var actors: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var pods: Array[Dictionary] = []
var ownership := PackedInt32Array()
## Native RGB8 upload bytes, incrementally kept identical to ownership (R team0 / G team1).
var coverage_rgb := PackedByteArray()
var painted_at := PackedFloat32Array()
var wet_revision := 0
var obstacles: Array[Rect2] = []
var spawn_zones: Array[Rect2] = []
var events: Array[Dictionary] = []
var state := "ready"
var time_left := MATCH_DURATION
var elapsed := 0.0
var winner := -2
var score: Array[float] = [0.0, 0.0]
var score_cells: Array[int] = [0, 0]
var scoreable_cells := 0
var grid_revision := 0
var bots_enabled := true
var rng := RandomNumberGenerator.new()
var _scoreable := PackedByteArray()
var _accumulator := 0.0
var _ticks := 0
var _next_id := 1
var _dash_held := false
var _pod_held := false
var _dash_queued := false
var _pod_queued := false

func start(seed_value: int = 1) -> void:
	rng.seed = seed_value
	actors.clear(); projectiles.clear(); pods.clear(); events.clear()
	state = "playing"; winner = -2; time_left = MATCH_DURATION; elapsed = 0.0
	_ticks = 0; _accumulator = 0.0; _next_id = 1
	_dash_held = false; _pod_held = false; _dash_queued = false; _pod_queued = false
	score = [0.0, 0.0]; score_cells = [0, 0]; scoreable_cells = 0
	grid_revision += 1
	# Rotationally and horizontally symmetric cover, with wide flanking lanes.
	obstacles.assign([
		Rect2(7, 5, 5, 2), Rect2(20, 5, 5, 2),
		Rect2(7, 17, 5, 2), Rect2(20, 17, 5, 2),
		Rect2(14, 3, 4, 3), Rect2(14, 18, 4, 3), Rect2(14, 10, 4, 4)
	])
	spawn_zones.assign([Rect2(0, 9, 4, 6), Rect2(28, 9, 4, 6)])
	ownership.resize(GRID_W * GRID_H); ownership.fill(-1)
	coverage_rgb.resize(GRID_W * GRID_H * 3); coverage_rgb.fill(0)
	painted_at.resize(GRID_W * GRID_H); painted_at.fill(-999.0)
	wet_revision += 1
	_scoreable.resize(GRID_W * GRID_H); _scoreable.fill(0)
	for y in GRID_H:
		for x in GRID_W:
			var p := cell_center(Vector2i(x, y))
			if not _inside_obstacle(p) and _spawn_team(p) == -1:
				_scoreable[y * GRID_W + x] = 1
				scoreable_cells += 1
	for id in 4:
		var team := id / 2
		var pos := _spawn_position(id)
		actors.append({
			"id": id, "team": team, "is_player": id == 0, "pos": pos,
			"aim": Vector2.RIGHT if team == 0 else Vector2.LEFT,
			"hp": MAX_HP, "water": MAX_WATER, "alive": true,
			"respawn_left": 0.0, "dash_left": 0.0, "dash_cd": 0.0,
			"dash_dir": Vector2.RIGHT if team == 0 else Vector2.LEFT,
			"pod_cd": 0.0, "shot_cd": 0.0, "refill_wait": 0.0,
			"kills": 0, "defeats": 0, "painted": 0, "shots": 0,
			"bot_think": 0.0, "bot_goal": pos, "bot_path": [],
			"bot_strafe": 1.0 if id % 2 == 0 else -1.0,
			"bot_rest": false, "bot_aim_error": Vector2.ZERO,
			"bot_decision": 0.0
		})
	events.append({"type": "start", "seed": seed_value})

func step(dt: float, input: Dictionary = {}) -> void:
	events.clear()
	if state != "playing" or not is_finite(dt) or dt <= 0.0:
		return
	var dash := bool(input.get("dash", false))
	var pod := bool(input.get("pod", false))
	_dash_queued = _dash_queued or (dash and not _dash_held)
	_pod_queued = _pod_queued or (pod and not _pod_held)
	_dash_held = dash; _pod_held = pod
	_accumulator += dt
	# Do not discard elapsed time on low-FPS frames. The runtime pauses on application suspension.
	while _accumulator + 0.00000001 >= FIXED_DT and state == "playing":
		_accumulator -= FIXED_DT
		var command := input.duplicate()
		command["dash"] = _dash_queued; command["pod"] = _pod_queued
		_dash_queued = false; _pod_queued = false
		_tick(command)

func _tick(player_input: Dictionary) -> void:
	for actor in actors:
		if not actor.alive:
			actor.respawn_left = maxf(0.0, float(actor.respawn_left) - FIXED_DT)
			if actor.respawn_left <= 0.000001:
				_respawn(actor)
			continue
		actor.shot_cd = maxf(0.0, float(actor.shot_cd) - FIXED_DT)
		actor.dash_cd = maxf(0.0, float(actor.dash_cd) - FIXED_DT)
		actor.pod_cd = maxf(0.0, float(actor.pod_cd) - FIXED_DT)
		actor.refill_wait = maxf(0.0, float(actor.refill_wait) - FIXED_DT)
		var command: Dictionary = player_input if actor.is_player else (_bot_input(actor) if bots_enabled else {})
		_update_actor(actor, command)
	_update_projectiles()
	_update_pods()
	_ticks += 1
	elapsed = _ticks * FIXED_DT
	time_left = maxf(0.0, MATCH_DURATION - elapsed)
	if _ticks >= int(MATCH_DURATION / FIXED_DT):
		_finish()

func _update_actor(actor: Dictionary, command: Dictionary) -> void:
	var move: Vector2 = command.get("move", Vector2.ZERO)
	if not move.is_finite(): move = Vector2.ZERO
	move = move.limit_length(1.0)
	var target: Vector2 = command.get("aim", actor.pos + actor.aim)
	if not target.is_finite(): target = actor.pos + actor.aim
	if target.distance_squared_to(actor.pos) > 0.001:
		actor.aim = (target - Vector2(actor.pos)).normalized()
	if bool(command.get("dash", false)):
		try_dash(int(actor.id), move if move.length_squared() > 0.01 else Vector2(actor.aim))
	if float(actor.dash_left) > 0.0:
		_move_actor(actor, Vector2(actor.dash_dir) * DASH_SPEED * minf(FIXED_DT, float(actor.dash_left)))
		actor.dash_left = maxf(0.0, float(actor.dash_left) - FIXED_DT)
	else:
		_move_actor(actor, move * MOVE_SPEED * FIXED_DT)
	if bool(command.get("pod", false)):
		deploy_pod(int(actor.id))
	if bool(command.get("shoot", false)):
		actor.refill_wait = REFILL_DELAY
		if float(actor.shot_cd) <= 0.000001 and float(actor.water) >= SHOT_WATER:
			_fire(actor, target, command.get("aim_world"), command.get("aim_direction"))
	elif float(actor.refill_wait) <= 0.000001:
		actor.water = minf(MAX_WATER, float(actor.water) + REFILL_RATE * FIXED_DT)

func try_dash(actor_id: int, direction: Vector2) -> bool:
	if state != "playing" or actor_id < 0 or actor_id >= actors.size(): return false
	var actor := actors[actor_id]
	if not actor.alive or float(actor.dash_cd) > 0.000001 or not direction.is_finite(): return false
	if direction.length_squared() < 0.001: return false
	actor.dash_dir = direction.normalized(); actor.dash_left = DASH_DURATION; actor.dash_cd = DASH_COOLDOWN
	_event("dash", actor)
	return true

func _move_actor(actor: Dictionary, offset: Vector2) -> void:
	# Fixed substeps and independent axis slides forbid tunnelling and retain corner mobility.
	var pieces := maxi(1, ceili(offset.length() / 0.15))
	var delta := offset / pieces
	for _part in pieces:
		var next: Vector2 = actor.pos + Vector2(delta.x, 0)
		if _actor_position_clear(next, int(actor.team)): actor.pos = next
		next = actor.pos + Vector2(0, delta.y)
		if _actor_position_clear(next, int(actor.team)): actor.pos = next

func _actor_position_clear(pos: Vector2, team: int) -> bool:
	if pos.x < ACTOR_RADIUS or pos.y < ACTOR_RADIUS or pos.x > WORLD_W - ACTOR_RADIUS or pos.y > WORLD_H - ACTOR_RADIUS:
		return false
	for rect in obstacles:
		if _circle_rect_intersects(pos, ACTOR_RADIUS, rect): return false
	if _circle_rect_intersects(pos, ACTOR_RADIUS, spawn_zones[1 - team]): return false
	return true

func _fire(actor: Dictionary, target: Vector2, world_target: Variant = null, launch_direction: Variant = null) -> void:
	actor.water -= SHOT_WATER; actor.shot_cd = SHOT_INTERVAL; actor.shots += 1
	var facing: Vector2 = actor.aim
	if target.is_finite() and target.distance_squared_to(actor.pos) > 0.0001:
		facing = (target - Vector2(actor.pos)).normalized()
	var right := Vector2(-facing.y, facing.x)
	var center := Vector3(actor.pos.x, SHOT_HEIGHT, actor.pos.y)
	var muzzle := center + Vector3(facing.x, 0, facing.y) * MUZZLE_FORWARD + Vector3(right.x, 0, right.y) * MUZZLE_SIDE
	var shot_id := _allocate_id()
	# The rendered nozzle can extend beyond the character collider. Never teleport a shot through cover.
	var muzzle_hit := _world_collision(center, muzzle, int(actor.team))
	if float(muzzle_hit.t) <= 1.0:
		var impact: Vector3 = center.lerp(muzzle, maxf(0.0, float(muzzle_hit.t) - 0.001))
		_event("shot", actor)
		events[-1].merge({"shot_id": shot_id, "world_pos": impact, "dir": facing, "velocity": Vector3.ZERO})
		_resolve_impact({"id": shot_id, "owner_id": actor.id, "team": actor.team}, impact, muzzle_hit)
		return
	var destination := Vector3(target.x, 0.0, target.y)
	if world_target is Vector3 and world_target.is_finite(): destination = world_target
	var horizontal := Vector2(destination.x - muzzle.x, destination.z - muzzle.z)
	# A point behind the forward nozzle cannot reverse a jet back through its own gardener.
	if horizontal.dot(facing) < 0.05:
		horizontal = facing * 0.15
		destination.x = muzzle.x + horizontal.x; destination.z = muzzle.z + horizontal.y
	var distance := clampf(horizontal.length(), 0.15, SHOT_RANGE)
	var direction := horizontal.normalized() if horizontal.length_squared() > 0.0001 else facing
	var flight_time := maxf(0.035, distance / SHOT_SPEED)
	var velocity := Vector3(direction.x * SHOT_SPEED, (destination.y - muzzle.y + 0.5 * SHOT_GRAVITY * flight_time * flight_time) / flight_time, direction.y * SHOT_SPEED)
	# A ray that hits sky must remain a 3D direction, not a projected XZ floor shot.
	if not (world_target is Vector3 and world_target.is_finite()) and launch_direction is Vector3 and launch_direction.is_finite() and launch_direction.length_squared() > 0.001:
		velocity = launch_direction.normalized() * SHOT_SPEED
		direction = Vector2(velocity.x, velocity.z).normalized()
		distance = SHOT_RANGE
	var shot := {"id": shot_id, "owner_id": actor.id, "team": actor.team,
		"pos": Vector2(muzzle.x, muzzle.z), "dir": direction, "life": SHOT_MAX_LIFE,
		"remaining": distance, "total_distance": distance, "traveled": 0.0,
		"world_pos": muzzle, "velocity": velocity, "initial_velocity": velocity,
		"origin": muzzle, "start_pos": muzzle, "age": 0.0, "gravity": SHOT_GRAVITY}
	projectiles.append(shot)
	_event("shot", actor)
	events[-1].merge({"shot_id": shot_id, "world_pos": muzzle, "dir": direction, "velocity": velocity})

func _update_projectiles() -> void:
	var remaining: Array[Dictionary] = []
	for shot in projectiles:
		var from: Vector3 = shot.world_pos
		var gravity := Vector3.DOWN * SHOT_GRAVITY
		var to := from + Vector3(shot.velocity) * FIXED_DT + gravity * (0.5 * FIXED_DT * FIXED_DT)
		var collision := _world_collision(from, to, int(shot.team))
		if float(collision.t) <= 1.0:
			var impact := from.lerp(to, clampf(float(collision.t), 0.0, 1.0))
			_resolve_impact(shot, impact, collision)
			continue
		shot.velocity += gravity * FIXED_DT
		shot.world_pos = to; shot.pos = Vector2(to.x, to.z)
		shot.age += FIXED_DT; shot.life = maxf(0.0, SHOT_MAX_LIFE - float(shot.age))
		shot.traveled += Vector2(to.x - from.x, to.z - from.z).length()
		shot.remaining = maxf(0.0, float(shot.total_distance) - float(shot.traveled))
		if float(shot.life) > 0.000001: remaining.append(shot)
	projectiles = remaining

func _resolve_impact(shot: Dictionary, impact: Vector3, collision: Dictionary) -> void:
	var surface: String = collision.surface
	var normal: Vector3 = collision.normal
	var ground := Vector2(impact.x, impact.z)
	if surface == "ground":
		_paint_splat(ground, SHOT_RADIUS, int(shot.team), int(shot.owner_id), int(shot.id))
	elif surface == "wall":
		# A wall stain is cosmetic. Only physically downward spillage at its near foot scores.
		var spill := ground + Vector2(normal.x, normal.z) * 0.04
		_paint_splat(spill, SHOT_RADIUS * 0.64, int(shot.team), int(shot.owner_id), int(shot.id))
	elif surface == "actor":
		damage_actor(int(collision.actor_id), SHOT_DAMAGE, int(shot.owner_id))
		_paint_splat(ground, SHOT_RADIUS * 0.72, int(shot.team), int(shot.owner_id), int(shot.id))
	elif surface == "pod":
		for index in pods.size():
			if int(pods[index].id) != int(collision.pod_id): continue
			pods[index].hp -= SHOT_DAMAGE
			if float(pods[index].hp) <= 0.0:
				var destroyed := pods[index]
				events.append({"type": "pod_destroyed", "id": destroyed.id, "owner_id": destroyed.owner_id, "team": destroyed.team, "pos": destroyed.pos, "world_pos": Vector3(destroyed.pos.x, 0.2, destroyed.pos.y)})
				pods.remove_at(index)
			break
		_paint_splat(ground, SHOT_RADIUS * 0.6, int(shot.team), int(shot.owner_id), int(shot.id))
	events.append({"type": "splash", "shot_id": shot.id, "pos": ground, "world_pos": impact,
		"normal": normal, "surface": surface, "radius": SHOT_RADIUS, "team": shot.team, "seed": shot.id})

func _world_collision(from: Vector3, to: Vector3, team: int, entities: bool = true) -> Dictionary:
	var result := {"t": 2.0, "normal": Vector3.UP, "surface": "ground", "actor_id": -1, "pod_id": -1}
	if to.y <= 0.0:
		result.t = 0.0 if from.y <= 0.0 else from.y / (from.y - to.y)
	for rect in obstacles:
		var hit := _segment_box_hit(from, to, AABB(Vector3(rect.position.x, 0, rect.position.y), Vector3(rect.size.x, OBSTACLE_HEIGHT, rect.size.y)))
		if float(hit.t) < float(result.t):
			result.merge({"t": hit.t, "normal": hit.normal, "surface": "wall"}, true)
	var safe := spawn_zones[1 - team]
	var protected_hit := _segment_box_hit(from, to, AABB(Vector3(safe.position.x, 0, safe.position.y), Vector3(safe.size.x, 30.0, safe.size.y)))
	if float(protected_hit.t) < float(result.t):
		result.merge({"t": protected_hit.t, "normal": protected_hit.normal, "surface": "shield"}, true)
	var delta := to - from
	for axis in [0, 2]:
		var limit := WORLD_W if axis == 0 else WORLD_H
		var t := 2.0
		var normal := Vector3.ZERO
		if to[axis] < 0.0 and delta[axis] < 0.0:
			t = -from[axis] / delta[axis]; normal[axis] = 1.0
		elif to[axis] > limit and delta[axis] > 0.0:
			t = (limit - from[axis]) / delta[axis]; normal[axis] = -1.0
		if t >= 0.0 and t < float(result.t): result.merge({"t": t, "normal": normal, "surface": "wall"}, true)
	if not entities: return result
	for actor in actors:
		if not actor.alive or int(actor.team) == team or _spawn_team(actor.pos) == int(actor.team): continue
		var t := _segment_cylinder_t(from, to, actor.pos, ACTOR_RADIUS + 0.10, ACTOR_HEIGHT)
		if t < float(result.t):
			var point := from.lerp(to, t)
			var normal := _cylinder_normal(point, actor.pos, ACTOR_HEIGHT)
			result.merge({"t": t, "normal": normal, "surface": "actor", "actor_id": actor.id, "pod_id": -1}, true)
	for pod in pods:
		if int(pod.team) == team: continue
		var t := _segment_cylinder_t(from, to, pod.pos, POD_HIT_RADIUS, POD_HEIGHT)
		if t < float(result.t):
			var point := from.lerp(to, t)
			var normal := _cylinder_normal(point, pod.pos, POD_HEIGHT)
			result.merge({"t": t, "normal": normal, "surface": "pod", "actor_id": -1, "pod_id": pod.id}, true)
	return result

func _segment_box_hit(from: Vector3, to: Vector3, box: AABB) -> Dictionary:
	var delta := to - from
	var near := 0.0
	var far := 1.0
	var normal := Vector3.ZERO
	for axis in 3:
		if absf(delta[axis]) < 0.0000001:
			if from[axis] < box.position[axis] or from[axis] > box.end[axis]: return {"t": 2.0, "normal": Vector3.ZERO}
		else:
			var a := (box.position[axis] - from[axis]) / delta[axis]
			var b := (box.end[axis] - from[axis]) / delta[axis]
			var entry := minf(a, b)
			if entry > near:
				near = entry; normal = Vector3.ZERO; normal[axis] = -signf(delta[axis])
			far = minf(far, maxf(a, b))
			if near > far: return {"t": 2.0, "normal": Vector3.ZERO}
	if normal == Vector3.ZERO and delta.length_squared() > 0.00001: normal = -delta.normalized()
	return {"t": near, "normal": normal}

func _cylinder_normal(point: Vector3, center: Vector2, height: float) -> Vector3:
	if point.y >= height - 0.0001: return Vector3.UP
	if point.y <= 0.0001: return Vector3.DOWN
	var normal := Vector3(point.x - center.x, 0.0, point.z - center.y)
	return normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP

func _segment_cylinder_t(from: Vector3, to: Vector3, center: Vector2, radius: float, height: float) -> float:
	var offset := Vector2(from.x, from.z) - center
	var delta := Vector2(to.x - from.x, to.z - from.z)
	var a := delta.dot(delta)
	var near := 0.0
	var far := 1.0
	if a < 0.0000001:
		if offset.length_squared() > radius * radius: return 2.0
	else:
		var b := 2.0 * offset.dot(delta)
		var c := offset.dot(offset) - radius * radius
		var discriminant := b * b - 4.0 * a * c
		if discriminant < 0.0: return 2.0
		near = maxf(near, (-b - sqrt(discriminant)) / (2.0 * a))
		far = minf(far, (-b + sqrt(discriminant)) / (2.0 * a))
	var dy := to.y - from.y
	if absf(dy) < 0.0000001:
		if from.y < 0.0 or from.y > height: return 2.0
	else:
		var bottom := -from.y / dy
		var top := (height - from.y) / dy
		near = maxf(near, minf(bottom, top)); far = minf(far, maxf(bottom, top))
	return near if near <= far else 2.0

func deploy_pod(actor_id: int) -> bool:
	if state != "playing" or actor_id < 0 or actor_id >= actors.size(): return false
	var actor := actors[actor_id]
	if not actor.alive or float(actor.pod_cd) > 0.000001 or owner_at(actor.pos) != int(actor.team): return false
	if not is_scoreable(cell_at(actor.pos)): return false
	for pod in pods:
		if pod.owner_id == actor_id: return false
	var pod := {"id": _allocate_id(), "owner_id": actor_id, "team": actor.team, "pos": actor.pos, "fuse": POD_FUSE, "hp": POD_HP}
	pods.append(pod); actor.pod_cd = POD_COOLDOWN
	events.append({"type": "pod_placed", "id": pod.id, "owner_id": actor_id, "team": actor.team, "pos": actor.pos})
	return true

func _update_pods() -> void:
	var remaining: Array[Dictionary] = []
	for pod in pods:
		pod.fuse = maxf(0.0, float(pod.fuse) - FIXED_DT)
		if float(pod.fuse) <= 0.000001:
			_paint_splat(pod.pos, POD_RADIUS, int(pod.team), int(pod.owner_id), int(pod.id))
			events.append({"type": "pod_burst", "id": pod.id, "owner_id": pod.owner_id, "team": pod.team, "pos": pod.pos, "world_pos": Vector3(pod.pos.x, 0.04, pod.pos.y), "normal": Vector3.UP, "radius": POD_RADIUS, "seed": pod.id})
		else: remaining.append(pod)
	pods = remaining

func damage_actor(actor_id: int, amount: float, source_id: int = -1) -> bool:
	if state != "playing" or actor_id < 0 or actor_id >= actors.size() or not is_finite(amount) or amount <= 0.0: return false
	var actor := actors[actor_id]
	if not actor.alive or _spawn_team(actor.pos) == int(actor.team): return false
	if source_id >= 0 and source_id < actors.size() and actors[source_id].team == actor.team: return false
	actor.hp = maxf(0.0, float(actor.hp) - amount)
	_event("hit", actor)
	if float(actor.hp) <= 0.0:
		actor.alive = false; actor.respawn_left = RESPAWN_TIME; actor.dash_left = 0.0; actor.defeats += 1
		if source_id >= 0 and source_id < actors.size(): actors[source_id].kills += 1
		_event("defeat", actor)
	return true

func _respawn(actor: Dictionary) -> void:
	actor.alive = true; actor.hp = MAX_HP; actor.water = MAX_WATER
	actor.pos = _spawn_position(int(actor.id)); actor.respawn_left = 0.0
	actor.dash_left = 0.0; actor.shot_cd = 0.0; actor.refill_wait = 0.0
	# Defeat does not bypass ability cooldowns or erase a planted seed pod.
	actor.dash_cd = maxf(0.0, float(actor.dash_cd) - RESPAWN_TIME)
	actor.pod_cd = maxf(0.0, float(actor.pod_cd) - RESPAWN_TIME)
	actor.bot_path = []; actor.bot_think = 0.0; actor.bot_rest = false
	_event("respawn", actor)

func _paint_disc(origin: Vector2, radius: float, team: int, owner_id: int = -1) -> int:
	# Exact circular helper for arrangements and migration tests; live liquid uses organic splats.
	return _paint_stamp(origin, radius, team, owner_id, 0, false)

func _paint_splat(origin: Vector2, radius: float, team: int, owner_id: int, seed_value: int) -> int:
	return _paint_stamp(origin, radius, team, owner_id, seed_value, true)

func _paint_stamp(origin: Vector2, radius: float, team: int, owner_id: int, seed_value: int, organic: bool) -> int:
	var changed := 0
	var wetted := false
	var bound := radius * (1.32 if organic else 1.0)
	var phase := float(seed_value % 997) * 0.0713
	# A fine mask must not multiply full-map LOS work. Only cover touching this stamp can occlude it.
	var nearby_cover: Array[Rect2] = []
	var stamp_bounds := Rect2(origin - Vector2.ONE * bound, Vector2.ONE * bound * 2.0)
	for rect in obstacles:
		if rect.intersects(stamp_bounds, true): nearby_cover.append(rect)
	var satellites: Array[Vector3] = []
	if organic:
		for i in 4:
			var angle := phase + float(i) * 1.618 + sin(phase + i) * 0.2
			var offset := Vector2(cos(angle), sin(angle)) * radius * (1.10 + 0.06 * sin(phase * 2 + i))
			satellites.append(Vector3(offset.x, offset.y, radius * (0.10 + 0.06 * absf(sin(phase + i * 2.1)))))
	for y in range(maxi(0, floori((origin.y - bound) / CELL_SIZE)), mini(GRID_H, ceili((origin.y + bound) / CELL_SIZE) + 1)):
		for x in range(maxi(0, floori((origin.x - bound) / CELL_SIZE)), mini(GRID_W, ceili((origin.x + bound) / CELL_SIZE) + 1)):
			var cell := Vector2i(x, y)
			if not is_scoreable(cell): continue
			var center := cell_center(cell)
			var offset := center - origin
			var extent := radius
			if organic:
				var angle := offset.angle()
				extent *= 0.92 + 0.13 * sin(angle * 3.0 + phase) + 0.08 * sin(angle * 7.0 - phase * 1.7)
			var included := offset.length_squared() <= extent * extent
			if not included and organic:
				for droplet in satellites:
					if offset.distance_squared_to(Vector2(droplet.x, droplet.y)) <= droplet.z * droplet.z:
						included = true; break
			if not included: continue
			var occluded := false
			for rect in nearby_cover:
				if _segment_rect_t(origin, center, rect) <= 0.99999:
					occluded = true; break
			if occluded: continue
			var index := y * GRID_W + x
			painted_at[index] = elapsed; wetted = true
			var previous := ownership[index]
			if previous == team: continue
			if previous >= 0: score_cells[previous] -= 1
			ownership[index] = team; score_cells[team] += 1; changed += 1
			coverage_rgb[index * 3] = 255 if team == 0 else 0
			coverage_rgb[index * 3 + 1] = 255 if team == 1 else 0
	if wetted: wet_revision += 1
	if changed > 0:
		grid_revision += 1
		if owner_id >= 0 and owner_id < actors.size(): actors[owner_id].painted += changed
		_update_score()
	return changed

func _update_score() -> void:
	for team in 2:
		score[team] = 100.0 * score_cells[team] / maxf(1.0, scoreable_cells)

func _finish() -> void:
	state = "finished"; time_left = 0.0
	winner = -1 if score_cells[0] == score_cells[1] else (0 if score_cells[0] > score_cells[1] else 1)
	projectiles.clear()
	events.append({"type": "finished", "winner": winner, "score": score.duplicate(), "score_cells": score_cells.duplicate()})

func coverage() -> Array[float]:
	return score.duplicate()

func drain_events() -> Array[Dictionary]:
	var result := events.duplicate(true)
	events.clear()
	return result

func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.y / CELL_SIZE))

func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE

func is_scoreable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_W or cell.y >= GRID_H: return false
	return _scoreable[cell.y * GRID_W + cell.x] == 1

func owner_at(pos: Vector2) -> int:
	var cell := cell_at(pos)
	if not is_scoreable(cell): return -1
	return ownership[cell.y * GRID_W + cell.x]

func line_of_sight(from: Vector2, to: Vector2) -> bool:
	return _segment_block_t(from, to) > 0.99999

func _spawn_position(id: int) -> Vector2:
	return Vector2(2.0 if id < 2 else 30.0, 10.5 if id % 2 == 0 else 13.5)

func _spawn_team(pos: Vector2) -> int:
	for team in spawn_zones.size():
		if spawn_zones[team].has_point(pos): return team
	return -1

func _inside_obstacle(pos: Vector2) -> bool:
	for rect in obstacles:
		if rect.has_point(pos): return true
	return false

func _circle_rect_intersects(pos: Vector2, radius: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(pos.x, rect.position.x, rect.end.x), clampf(pos.y, rect.position.y, rect.end.y))
	return nearest.distance_squared_to(pos) < radius * radius - 0.0000001

func _segment_block_t(from: Vector2, to: Vector2, shot_team: int = -1) -> float:
	var result := 2.0
	for rect in obstacles:
		result = minf(result, _segment_rect_t(from, to, rect))
	if shot_team >= 0:
		result = minf(result, _segment_rect_t(from, to, spawn_zones[1 - shot_team]))
	# Arena walls also stop projectiles, including outward shots at an edge.
	if to.x < 0.0 or to.x > WORLD_W or to.y < 0.0 or to.y > WORLD_H:
		var delta := to - from
		if to.x < 0.0 and delta.x != 0.0: result = minf(result, (0.0 - from.x) / delta.x)
		if to.x > WORLD_W and delta.x != 0.0: result = minf(result, (WORLD_W - from.x) / delta.x)
		if to.y < 0.0 and delta.y != 0.0: result = minf(result, (0.0 - from.y) / delta.y)
		if to.y > WORLD_H and delta.y != 0.0: result = minf(result, (WORLD_H - from.y) / delta.y)
	return result

func _segment_rect_t(from: Vector2, to: Vector2, rect: Rect2) -> float:
	var delta := to - from
	var near := 0.0
	var far := 1.0
	for axis in 2:
		if absf(delta[axis]) < 0.0000001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]: return 2.0
		else:
			var a := (rect.position[axis] - from[axis]) / delta[axis]
			var b := (rect.end[axis] - from[axis]) / delta[axis]
			near = maxf(near, minf(a, b)); far = minf(far, maxf(a, b))
			if near > far: return 2.0
	return near

func _segment_circle_t(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var delta := to - from
	var offset := from - center
	if offset.length_squared() <= radius * radius: return 0.0
	var a := delta.dot(delta)
	if a < 0.0000001: return 2.0
	var b := 2.0 * offset.dot(delta)
	var c := offset.dot(offset) - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0: return 2.0
	var t := (-b - sqrt(discriminant)) / (2.0 * a)
	return t if t >= 0.0 and t <= 1.0 else 2.0

func _allocate_id() -> int:
	var result := _next_id
	_next_id += 1
	return result

func _event(kind: String, actor: Dictionary) -> void:
	events.append({"type": kind, "id": actor.id, "owner_id": actor.id, "team": actor.team, "pos": actor.pos})

func _bot_input(actor: Dictionary) -> Dictionary:
	actor.bot_think -= FIXED_DT; actor.bot_decision -= FIXED_DT
	if float(actor.bot_decision) <= 0.0:
		actor.bot_aim_error = Vector2(rng.randf_range(-0.38, 0.38), rng.randf_range(-0.38, 0.38))
		actor.bot_decision = rng.randf_range(0.25, 0.45)
	if float(actor.water) < 10.0: actor.bot_rest = true
	if float(actor.water) >= 72.0: actor.bot_rest = false
	if float(actor.bot_think) <= 0.0 or Vector2(actor.pos).distance_to(actor.bot_goal) < 0.55:
		actor.bot_goal = _choose_paint_goal(actor)
		actor.bot_path = _find_path(_nav_cell_at(actor.pos), _nav_cell_at(actor.bot_goal), int(actor.team))
		actor.bot_think = rng.randf_range(0.65, 1.05)
	var move := _path_direction(actor)
	var aim: Vector2 = actor.bot_goal
	var shoot := false
	var enemy_distance := SHOT_RANGE
	var enemy_id := -1
	for other in actors:
		if not other.alive or other.team == actor.team or _spawn_team(other.pos) == int(other.team): continue
		var distance := Vector2(actor.pos).distance_to(other.pos)
		if distance < enemy_distance and line_of_sight(actor.pos, other.pos):
			enemy_distance = distance; enemy_id = int(other.id)
	# Nearby hostile pods take priority so a bot can meaningfully deny territory.
	var hostile_pod: Dictionary = {}
	var pod_distance := 7.0
	for pod in pods:
		var distance := Vector2(actor.pos).distance_to(pod.pos)
		if pod.team != actor.team and distance < pod_distance and line_of_sight(actor.pos, pod.pos):
			hostile_pod = pod; pod_distance = distance
	if not hostile_pod.is_empty():
		aim = hostile_pod.pos + Vector2(actor.bot_aim_error) * 0.3
		shoot = not actor.bot_rest
	elif enemy_id >= 0:
		var toward: Vector2 = (Vector2(actors[enemy_id].pos) - Vector2(actor.pos)).normalized()
		aim = actors[enemy_id].pos + actor.bot_aim_error
		shoot = not actor.bot_rest
		var strafe := Vector2(-toward.y, toward.x) * float(actor.bot_strafe)
		if enemy_distance < 3.5 or actor.bot_rest or float(actor.hp) <= 25.0:
			move = (strafe * 0.5 - toward).normalized()
		elif enemy_distance < 7.0:
			move = (strafe + move * 0.35).normalized()
	elif not actor.bot_rest:
		var paint_target := _visible_paint_target(actor)
		if paint_target != Vector2.INF:
			aim = paint_target
			shoot = true
	var deploy := false
	if float(actor.pod_cd) <= 0.000001 and owner_at(actor.pos) == int(actor.team):
		var useful := 0
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var c := _nav_cell_at(actor.pos) + Vector2i(dx, dy)
				if is_scoreable(cell_at(_nav_center(c))) and owner_at(_nav_center(c)) != int(actor.team): useful += 1
		deploy = useful >= 8
	var dash: bool = float(actor.dash_cd) <= 0.0 and enemy_id >= 0 and (enemy_distance < 4.0 or actor.bot_rest)
	var aim_height := 0.0
	if not hostile_pod.is_empty(): aim_height = POD_HEIGHT * 0.5
	elif enemy_id >= 0: aim_height = ACTOR_CENTER_HEIGHT
	return {"move": move, "aim": aim, "aim_world": Vector3(aim.x, aim_height, aim.y), "shoot": shoot, "pod": deploy, "dash": dash}

func _choose_paint_goal(actor: Dictionary) -> Vector2:
	var best: Vector2 = actor.pos
	var best_value := INF
	# Sample the whole arena, rather than getting trapped repainting a nearby tile.
	for _candidate in 85:
		var cell := Vector2i(rng.randi_range(0, NAV_W - 1), rng.randi_range(0, NAV_H - 1))
		var point := _nav_center(cell)
		if not is_scoreable(cell_at(point)) or owner_at(point) == int(actor.team): continue
		if not _actor_position_clear(point, int(actor.team)): continue
		var value := Vector2(actor.pos).distance_to(point)
		# Distinct gardeners prefer opposite lanes while remaining free to flank.
		var lane_y := 5.0 if int(actor.id) % 2 == 0 else 19.0
		value += absf(point.y - lane_y) * 0.18
		if owner_at(point) == 1 - int(actor.team): value -= 1.5
		for friend in actors:
			if friend.id != actor.id and friend.team == actor.team and friend.alive:
				value += maxf(0.0, 4.0 - point.distance_to(friend.pos)) * 0.5
		if value < best_value: best_value = value; best = point
	return best

func _visible_paint_target(actor: Dictionary) -> Vector2:
	var best := Vector2.INF
	var best_value := INF
	var origin: Vector2 = actor.pos
	var cell := _nav_cell_at(origin)
	# A short local scan encourages continuous ground painting along each route.
	for dy in range(-6, 7, 2):
		for dx in range(-6, 7, 2):
			var candidate := cell + Vector2i(dx, dy)
			var point := _nav_center(candidate)
			if not is_scoreable(cell_at(point)): continue
			if owner_at(point) == int(actor.team) or not line_of_sight(origin, point): continue
			var distance := origin.distance_to(point)
			if distance > SHOT_RANGE or distance < 0.6: continue
			var value := distance + point.distance_to(actor.bot_goal) * 0.2
			if value < best_value: best_value = value; best = point
	return best

func _find_path(from: Vector2i, target: Vector2i, team: int) -> Array:
	if from == target: return [_nav_center(target)]
	var queue: Array[Vector2i] = [from]
	var previous: Dictionary = {from: from}
	var index := 0
	while index < queue.size():
		var current := queue[index]; index += 1
		if current == target: break
		for direction in NAV_DIRS:
			var next: Vector2i = current + direction
			if previous.has(next) or not _actor_position_clear(_nav_center(next), team): continue
			previous[next] = current; queue.append(next)
	if not previous.has(target): return []
	var path: Array = []
	var cursor := target
	while cursor != from:
		path.push_front(_nav_center(cursor)); cursor = previous[cursor]
	return path

func _path_direction(actor: Dictionary) -> Vector2:
	var path: Array = actor.bot_path
	while not path.is_empty() and Vector2(actor.pos).distance_to(path[0]) < 0.2:
		path.pop_front()
	if path.is_empty(): return Vector2.ZERO
	return (Vector2(path[0]) - Vector2(actor.pos)).normalized()

func _nav_cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / NAV_CELL_SIZE), floori(pos.y / NAV_CELL_SIZE))

func _nav_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * NAV_CELL_SIZE
