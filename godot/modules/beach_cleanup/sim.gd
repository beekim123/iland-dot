extends RefCounted
## Deterministic rules. XZ Vector2; heading forward=(-sin(h),-cos(h)).
const Maps = preload("data/maps.gd")
const CAPACITY := 12
const CART_RADIUS := 0.55
const REACH := 1.8
const GRAB_TIME := 0.5
const SAVE_VERSION := 1
var map_data: Dictionary = {}
var map_id := 0
var variant := 0
var pos := Vector2.ZERO
var heading := 0.0
var speed := 0.0
var distance := 0.0
var unloads := 0
var phase := "cleaning"
var remaining: Array[String] = []
var cargo: Array[String] = []
var delivered: Array[String] = []
var restored_zones: Array[String] = []
var grab_target := ""
var grab_progress := 0.0
var paused := false
var _move := Vector2.ZERO
var _grab := false
var _unload_down := false
var _unload_pending := false
var _events: Array[Dictionary] = []
var _capacity_announced := false

func start(new_map_id: int = 0, new_variant: int = 0) -> void:
	map_id = clampi(new_map_id,0,2); variant = posmod(new_variant,Maps.VARIANT_COUNT)
	map_data = Maps.definition(map_id,variant)
	pos = map_data.start; heading = map_data.heading
	speed = 0; distance = 0; unloads = 0; phase = "cleaning"; paused = false
	remaining.clear(); cargo.clear(); delivered.clear(); restored_zones.clear(); _events.clear()
	for item: Dictionary in map_data.trash: remaining.append(item.id)
	_clear_input()

func _clear_input() -> void:
	_move = Vector2.ZERO; _grab = false; _unload_down = false; _unload_pending = false
	grab_target = ""; grab_progress = 0; _capacity_announced = false

func command(input: Dictionary) -> void:
	if input.has("pause"):
		paused = bool(input.pause)
		if paused: _clear_input()
	if paused: return
	if input.has("move") and input.move is Vector2:
		var movement: Vector2 = input.move
		_move = movement.limit_length() if movement.is_finite() else Vector2.ZERO
	if input.has("grab"):
		_grab = bool(input.grab)
		if not _grab: grab_target = ""; grab_progress = 0; _capacity_announced = false
	if input.has("unload"):
		var pressed := bool(input.unload)
		if pressed and not _unload_down: _unload_pending = true
		_unload_down = pressed

func capacity_used() -> int:
	var total := 0
	for id in cargo: total += int(item_by_id(id).cost)
	return total

func item_by_id(id: String) -> Dictionary:
	for item: Dictionary in map_data.get("trash",[]):
		if item.id == id: return item
	return {}

func tick(dt: float) -> void:
	if paused or phase != "cleaning" or not is_finite(dt) or dt <= 0: return
	var left := minf(dt,1.0)
	while left > 0.000001:
		var step := minf(left,1.0/60.0)
		_step(step); left -= step

func _step(dt: float) -> void:
	var previous := pos
	if _move.length_squared() > 0.001:
		heading = atan2(-_move.x,-_move.y)
	# The mechanical jaw braces the cart during its half-second closure.
	# Held driving resumes automatically after pickup; steering out of the cone
	# or releasing the mouse cancels immediately rather than trapping the cart.
	var braced := _grab and not grab_target.is_empty()
	if braced and (not can_grab(grab_target) or capacity_used() + int(item_by_id(grab_target).cost) > CAPACITY):
		grab_target = ""; grab_progress = 0; braced = false
	if not braced and _move.length_squared() > 0.001:
		var delta := _move * 4.0 * dt
		if is_walkable(pos + Vector2(delta.x,0)): pos.x += delta.x
		if is_walkable(pos + Vector2(0,delta.y)): pos.y += delta.y
	speed = pos.distance_to(previous) / dt
	distance += pos.distance_to(previous)
	if _unload_pending:
		_unload_pending = false
		for depot: Dictionary in map_data.depots:
			if pos.distance_to(depot.pos) <= float(depot.radius) and not cargo.is_empty():
				var count := cargo.size()
				delivered.append_array(cargo); cargo.clear(); unloads += 1; _capacity_announced = false
				_emit({"type":"unload","count":count,"depot":depot.id})
				if remaining.is_empty():
					phase = "complete"; _clear_input(); _emit({"type":"complete"})
				return
	if not _grab: return
	if grab_target.is_empty():
		var best := REACH + 1.0
		for id in remaining:
			var item := item_by_id(id)
			var d := pos.distance_to(item.pos)
			if d < best and can_grab(id):
				if capacity_used() + int(item.cost) > CAPACITY:
					if not _capacity_announced: _emit({"type":"capacity","id":id}); _capacity_announced = true
					continue
				grab_target = id; best = d
		if grab_target.is_empty(): return
	if not can_grab(grab_target): grab_target = ""; grab_progress = 0; return
	grab_progress += dt
	if grab_progress + 0.000001 < GRAB_TIME: return
	var target := grab_target
	grab_target = ""; grab_progress = 0
	if can_grab(target) and capacity_used() + int(item_by_id(target).cost) <= CAPACITY:
		remaining.erase(target); cargo.append(target); _emit({"type":"pickup","id":target})
		_update_ecology()

func can_grab(id: String) -> bool:
	if not remaining.has(id): return false
	var item := item_by_id(id)
	var offset: Vector2 = item.pos - pos
	if offset.length() > REACH or offset.length() < 0.01: return false
	if Vector2(-sin(heading),-cos(heading)).dot(offset.normalized()) < cos(deg_to_rad(40.0)): return false
	return line_clear(pos,item.pos,id)

func line_clear(a: Vector2, b: Vector2, ignore_id: String = "") -> bool:
	for obstacle: Dictionary in map_data.obstacles:
		if _segment_rect(a,b,obstacle.rect): return false
	for id in remaining:
		if id == ignore_id: continue
		var item := item_by_id(id)
		if bool(item.blocks) and Geometry2D.get_closest_point_to_segment(item.pos,a,b).distance_to(item.pos) < 0.48: return false
	return true

func _segment_rect(a: Vector2,b: Vector2,r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b): return true
	var corners := [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null: return true
	return false

func is_walkable(p: Vector2) -> bool:
	var half: Vector2 = map_data.size * 0.5 - Vector2.ONE * CART_RADIUS
	if absf(p.x) > half.x or absf(p.y) > half.y: return false
	for obstacle: Dictionary in map_data.obstacles:
		var r: Rect2 = obstacle.rect
		var closest := Vector2(clampf(p.x,r.position.x,r.end.x),clampf(p.y,r.position.y,r.end.y))
		if p.distance_to(closest) < CART_RADIUS: return false
	for id in remaining:
		var item := item_by_id(id)
		if bool(item.blocks) and p.distance_to(item.pos) < CART_RADIUS + 0.48: return false
	return true

func _update_ecology() -> void:
	for zone: Dictionary in map_data.zones:
		if restored_zones.has(zone.id): continue
		var clean := true
		for id in remaining:
			if item_by_id(id).zone == zone.id: clean = false; break
		if clean: restored_zones.append(zone.id); _emit({"type":"zone_restored","zone":zone.id})

func nearest_hint() -> Dictionary:
	var best: Dictionary = {}
	var d := INF
	for id in remaining:
		var item := item_by_id(id)
		var next := pos.distance_to(item.pos)
		if next < d: d = next; best = item
	return best.duplicate(true)

func _emit(event: Dictionary) -> void:
	_events.append(event)
	if _events.size() > 128: _events.pop_front()

func drain_events() -> Array[Dictionary]:
	var result := _events.duplicate(true)
	_events.clear()
	return result

func snapshot() -> Dictionary:
	return {"version":SAVE_VERSION,"map_id":map_id,"variant":variant,"pos":[pos.x,pos.y],"heading":heading,"distance":distance,"unloads":unloads,"phase":phase,"remaining":remaining.duplicate(),"cargo":cargo.duplicate(),"delivered":delivered.duplicate(),"restored_zones":restored_zones.duplicate()}

func restore(state: Dictionary) -> bool:
	# Validate into a separate candidate; a rejected save never mutates this game.
	if state.get("version",-1) != SAVE_VERSION: return false
	for key in ["map_id","variant","heading","distance","unloads"]:
		if not (state.get(key) is int or state.get(key) is float): return false
		if not is_finite(float(state[key])): return false
	if float(state.map_id) != floorf(float(state.map_id)) or int(state.map_id) < 0 or int(state.map_id) > 2: return false
	if float(state.variant) != floorf(float(state.variant)) or int(state.variant) < 0 or int(state.variant) >= Maps.VARIANT_COUNT: return false
	if float(state.distance) < 0 or float(state.unloads) < 0 or float(state.unloads) != floorf(float(state.unloads)): return false
	var location = state.get("pos")
	if not location is Array or location.size() != 2: return false
	for value in location:
		if not (value is int or value is float) or not is_finite(float(value)): return false
	var candidate = get_script().new()
	candidate.start(int(state.map_id),int(state.variant))
	var seen: Array[String] = []
	for key in ["remaining","cargo","delivered"]:
		if not state.get(key) is Array: return false
		candidate[key].clear()
		for id in state[key]:
			if not id is String or seen.has(id) or candidate.item_by_id(id).is_empty(): return false
			seen.append(id); candidate[key].append(id)
	if seen.size() != candidate.map_data.trash.size() or candidate.capacity_used() > CAPACITY: return false
	candidate.pos = Vector2(float(location[0]),float(location[1]))
	if not candidate.is_walkable(candidate.pos): return false
	var expected_phase := "complete" if candidate.remaining.is_empty() and candidate.cargo.is_empty() else "cleaning"
	if state.get("phase","") != expected_phase: return false
	candidate._update_ecology()
	if not state.get("restored_zones") is Array: return false
	var saved_zones: Array = state.restored_zones.duplicate()
	saved_zones.sort()
	var computed: Array = candidate.restored_zones.duplicate()
	computed.sort()
	if saved_zones != computed: return false
	start(int(state.map_id),int(state.variant))
	pos = candidate.pos; heading = float(state.heading); distance = float(state.distance); unloads = int(state.unloads)
	remaining.assign(candidate.remaining); cargo.assign(candidate.cargo); delivered.assign(candidate.delivered)
	restored_zones.assign(candidate.restored_zones); phase = expected_phase
	return true
