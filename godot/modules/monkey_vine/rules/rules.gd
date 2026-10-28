class_name MonkeyVineRules
extends RefCounted
const Segments = preload("../data/segments.gd")
const H := 1.0 / 120.0
const RADIUS := 0.32
const HAND := Vector2(0,0.45)
const GRAB_RADIUS := 0.35
const GRAVITY := 13.0
var seed_value := 1
var segment := 0
var score := 0
var banked_score := 0
var phase := "playing"
var player_pos := Vector2.ZERO
var player_vel := Vector2.ZERO
var grounded := true
var vine_id := ""
var checkpoint := "start"
var facing := 1
var time := 0.0
var level: Dictionary = {}
var events: Array = []
var _accumulator := 0.0
var _rope_length := 0.0
var _cooldown := 0.0
var _last_vine := ""
var _attached_time := 0.0
var _failure_time := 0.0
var _pending_press := false
var _pending_release := false
var _checkpoint_pos := Vector2.ZERO
var _checkpoint_score := 0
var _checkpoint_fruit: Array = []
var _collected: Array = []
var _broken: Array = []
var _warned := false

func configure(new_seed: int, segment_index: int = 0) -> void:
	seed_value = new_seed
	segment = maxi(0,segment_index)
	score = 0
	banked_score = 0
	_load_segment()

func _load_segment() -> void:
	level = Segments.get_segment(seed_value,segment)
	player_pos = level.spawn
	_checkpoint_pos = player_pos
	player_vel = Vector2.ZERO
	grounded = true
	vine_id = ""
	checkpoint = "start"
	phase = "playing"
	time = 0
	_accumulator = 0
	_cooldown = 0
	_pending_press = false
	_pending_release = false
	_collected = []
	_checkpoint_fruit = []
	_broken = []
	_checkpoint_score = banked_score
	score = banked_score
	events = []

func step(dt: float, input: Dictionary) -> Dictionary:
	events = []
	if not is_finite(dt) or dt <= 0.0:
		return snapshot()
	_pending_press = _pending_press or bool(input.get("grab_pressed",false))
	_pending_release = _pending_release or bool(input.get("grab_released",false))
	_accumulator += dt
	while _accumulator + 0.00000001 >= H:
		_accumulator -= H
		_tick(input,_pending_press,_pending_release)
		_pending_press = false
		_pending_release = false
	return snapshot()

func _event(kind: String, id: String = "") -> void:
	events.append({"type":kind,"id":id,"pos":player_pos})

func _anchor(v: Dictionary, t: float) -> Vector2:
	return v.anchor + (Vector2(sin(t*1.2)*0.6,0) if v.type == "moving" else Vector2.ZERO)

func _anchor_vel(v: Dictionary, t: float) -> Vector2:
	return Vector2(cos(t*1.2)*0.72,0) if v.type == "moving" else Vector2.ZERO

func _vine(id: String) -> Dictionary:
	for v in level.vines:
		if v.id == id:
			return v
	return {}

func _release(kind: String = "release") -> void:
	if vine_id.is_empty(): return
	_last_vine = vine_id
	_cooldown = .18
	_event(kind,vine_id)
	vine_id = ""
	_warned = false

func _tick(input: Dictionary, pressed: bool, released: bool) -> void:
	time += H
	_cooldown = maxf(0,_cooldown-H)
	if phase == "failed":
		_failure_time += H
		if _failure_time >= .45: restart_checkpoint()
		return
	if phase == "segment_clear":
		_failure_time += H
		if _failure_time >= .55:
			advance_segment()
		return
	var axis := float(int(bool(input.get("right",false))) - int(bool(input.get("left",false))))
	if axis != 0: facing = int(axis)
	if released or not bool(input.get("grab_held",false)):
		_release()
	if grounded and pressed:
		player_vel.y = 5.5
		grounded = false
		_event("jump")
	if not vine_id.is_empty():
		_attached_time += H
		var attached := _vine(vine_id)
		if attached.type == "fragile":
			if not _warned:
				_warned = true
				_event("break_warning",vine_id)
			if _attached_time >= float(attached.warning_duration):
				_broken.append(vine_id)
				_release("vine_break")
	var old := player_pos
	if grounded:
		player_vel.x = move_toward(player_vel.x,axis*5.0,25.0*H)
	else:
		player_vel.x += axis*(10.0 if not vine_id.is_empty() else 3.5)*H
	player_vel.y -= GRAVITY*H
	player_vel.x += _wind_x()*H
	player_vel = player_vel.limit_length(8.0)
	var proposed := player_pos + player_vel*H
	if not vine_id.is_empty():
		var v := _vine(vine_id)
		var anchor := _anchor(v,time)
		var radial := (proposed+HAND-anchor).normalized()
		proposed = anchor + radial*_rope_length - HAND
		var anchor_velocity := _anchor_vel(v,time)
		var relative := player_vel-anchor_velocity
		player_vel = relative-radial*relative.dot(radial)+anchor_velocity
	var was_grounded := grounded
	grounded = false
	player_pos = _sweep(old,proposed)
	if grounded and not was_grounded: _event("land")
	if not vine_id.is_empty() and player_pos.distance_to(proposed) > .001:
		_release()
	if vine_id.is_empty() and bool(input.get("grab_held",false)) and not released and not grounded:
		_try_grab()
	for fruit in level.collectibles:
		if not fruit.id in _collected and player_pos.distance_to(fruit.pos) < .65:
			_collected.append(fruit.id)
			score += int(fruit.value)
			_event("collect",fruit.id)
	if grounded:
		for p in level.platforms:
			var r: Rect2 = p.rect
			if p.id != "start" and checkpoint != p.id and player_pos.x >= r.position.x+.4 and player_pos.x <= r.end.x-.4 and absf(player_pos.y-r.end.y-RADIUS)<.02:
				checkpoint = p.id
				_checkpoint_pos = Vector2(r.position.x+1,RADIUS+r.end.y)
				_checkpoint_score = score
				_checkpoint_fruit = _collected.duplicate()
				_event("checkpoint",checkpoint)
		if level.exit_rect.has_point(player_pos):
			banked_score = score+100
			score = banked_score
			phase = "segment_clear"
			_failure_time = 0
			_event("segment_clear",str(segment))
	if player_pos.y < -6 or player_pos.x < -4 or player_pos.x > 34:
		phase = "failed"
		_failure_time = 0
		_release()
		_event("fail")

func _try_grab() -> void:
	var best: Dictionary = {}
	var best_distance := GRAB_RADIUS
	for v in level.vines:
		if v.id in _broken or (v.id == _last_vine and _cooldown > 0): continue
		var anchor := _anchor(v,time)
		var tip := anchor+Vector2(0,-float(v.length))
		var distance := (player_pos+HAND).distance_to(tip)
		if (distance < best_distance or (is_equal_approx(distance,best_distance) and (best.is_empty() or str(v.id) < str(best.id)))) and not _blocked(player_pos+HAND,anchor):
			best = v
			best_distance = distance
	if best.is_empty(): return
	vine_id = best.id
	_rope_length = (player_pos+HAND).distance_to(_anchor(best,time))
	var radial := (player_pos+HAND-_anchor(best,time)).normalized()
	var av := _anchor_vel(best,time)
	var relative := player_vel-av
	player_vel = relative-radial*relative.dot(radial)+av
	_attached_time = 0
	_warned = false
	_event("grab",vine_id)

func _blocked(a: Vector2,b: Vector2) -> bool:
	for p in level.platforms:
		if _ray_rect(a,b,p.rect).hit: return true
	return false

## Ray/slab sweep against radius-expanded solid platforms. Tracks entering normal.
func _ray_rect(a: Vector2,b: Vector2,r: Rect2) -> Dictionary:
	var delta := b-a
	var enter := 0.0
	var leave := 1.0
	var normal := Vector2.ZERO
	for axis in range(2):
		if absf(delta[axis]) < 1e-10:
			if a[axis] <= r.position[axis] or a[axis] >= r.end[axis]: return {"hit":false}
		else:
			var t1: float = (r.position[axis]-a[axis])/delta[axis]
			var t2: float = (r.end[axis]-a[axis])/delta[axis]
			var n := Vector2.ZERO
			n[axis] = -signf(delta[axis])
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			if t1 >= enter:
				enter = t1
				normal = n
			leave = minf(leave,t2)
			if enter > leave: return {"hit":false}
	return {"hit": enter >= 0 and enter <= 1 and normal != Vector2.ZERO,"t":enter,"normal":normal}

func _sweep(a: Vector2,b: Vector2) -> Vector2:
	var current := a
	var target := b
	for _iteration in range(3):
		var earliest := 2.0
		var normal := Vector2.ZERO
		for p in level.platforms:
			var hit := _ray_rect(current,target,(p.rect as Rect2).grow(RADIUS))
			if hit.hit and float(hit.t)<earliest:
				earliest = hit.t
				normal = hit.normal
		if earliest > 1: return target
		current = current.lerp(target,earliest)
		var remaining := target-current
		remaining -= normal*minf(remaining.dot(normal),0)
		target = current+remaining
		player_vel -= normal*minf(player_vel.dot(normal),0)
		if normal.y > .5:
			grounded = true
	return current

func restart_checkpoint() -> void:
	player_pos = _checkpoint_pos
	player_vel = Vector2.ZERO
	grounded = true
	vine_id = ""
	phase = "playing"
	score = _checkpoint_score
	_collected = _checkpoint_fruit.duplicate()
	_broken.clear()
	_cooldown = 0
	_event("restart",checkpoint)

func _wind_x() -> float:
	return float(level.get("wind",0.0))*sin(time*1.5)

func snapshot() -> Dictionary:
	var vines: Array = []
	for original in level.get("vines",[]):
		var v: Dictionary = original.duplicate(true)
		v.anchor = _anchor(v,time)
		v.tip = player_pos+HAND if v.id == vine_id else v.anchor+Vector2(0,-float(v.length))
		v.broken = v.id in _broken
		v.warning = _attached_time/float(v.warning_duration) if v.id == vine_id and v.type == "fragile" else 0.0
		vines.append(v)
	var fruit: Array = level.get("collectibles",[]).duplicate(true)
	for f in fruit: f.collected = f.id in _collected
	return {"phase":phase,"player_pos":player_pos,"player_vel":player_vel,"grounded":grounded,"vine_id":vine_id,"grip_pos":player_pos+HAND,"segment":segment,"checkpoint":checkpoint,"score":score,"events":events.duplicate(true),"facing":facing,"time":time,"wind_x":_wind_x(),"vines":vines,"platforms":level.get("platforms",[]).duplicate(true),"collectibles":fruit,"spawn":level.get("spawn",Vector2.ZERO),"bounds":level.get("bounds",Rect2()),"exit_rect":level.get("exit_rect",Rect2()),"template_id":level.get("id",""),"swing_angle":0.0 if vine_id.is_empty() else (player_pos+HAND-_anchor(_vine(vine_id),time)).angle()+PI/2,"rope_length":_rope_length}

func advance_segment() -> void:
	if phase != "segment_clear": return
	segment += 1
	var previous_events := events.duplicate()
	var remaining_time := _accumulator
	_load_segment()
	_accumulator = remaining_time
	events = previous_events
	_event("segment_start",str(segment))

func export_progress() -> Dictionary:
	var cleared := phase == "segment_clear"
	return {"schema":1,"game_id":"monkey_vine","seed":seed_value,"segment":segment+1 if cleared else segment,"banked_score":banked_score,"checkpoint":"start" if cleared else checkpoint,"checkpoint_score":banked_score if cleared else _checkpoint_score,"collected":[] if cleared else _checkpoint_fruit.duplicate()}

func import_progress(data: Dictionary) -> bool:
	if data.get("schema") != 1 or data.get("game_id") != "monkey_vine": return false
	for key in ["seed","segment","banked_score","checkpoint_score"]:
		if not data.has(key) or not (data[key] is int or data[key] is float): return false
		if not is_finite(float(data[key])) or float(data[key]) != floor(float(data[key])): return false
	if absf(float(data.seed)) > 2147483647 or data.segment < 0 or data.segment > 1000000 or data.banked_score < 0 or data.banked_score > 1000000000: return false
	if not data.get("checkpoint") in ["start","rest","exit"]: return false
	if not data.get("collected") is Array: return false
	var candidate: Dictionary = Segments.get_segment(int(data.seed),int(data.segment))
	var valid_ids: Dictionary = {}
	for fruit in candidate.collectibles: valid_ids[fruit.id] = int(fruit.value)
	var seen: Array = []
	var expected := int(data.banked_score)
	for id in data.collected:
		if not id is String or not valid_ids.has(id) or id in seen: return false
		seen.append(id)
		expected += int(valid_ids[id])
	if expected != int(data.checkpoint_score): return false
	if data.checkpoint == "start" and not seen.is_empty(): return false
	seed_value = int(data.seed)
	segment = int(data.segment)
	banked_score = int(data.banked_score)
	_load_segment()
	checkpoint = data.checkpoint
	for platform in level.platforms:
		if platform.id == checkpoint and checkpoint != "start":
			_checkpoint_pos = Vector2(platform.rect.position.x+1,platform.rect.end.y+RADIUS)
	_checkpoint_score = int(data.checkpoint_score)
	_checkpoint_fruit = seen.duplicate()
	restart_checkpoint()
	events = []
	return true
