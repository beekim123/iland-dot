extends RefCounted
const Island = preload("data/island.gd")
const SPEED := 2.8
const PLAYER_RADIUS := 0.33
const REACH := 1.25
static var _geometry_cache: Dictionary = {}
var map_data: Dictionary = {}
var script_id := 0
var pos := Vector2.ZERO
var checkpoint := Vector2.ZERO
var heading := 0.0
var time := 0.0
var health := 3
var status := "running"
var paused := false
var shelter_id := ""
var invulnerable_until := 0.0
var interaction := {"kind":"","target":"","progress":0.0,"required":0.0}
var result: Dictionary = {}
var score := 0
var lit_beacons: Array[String] = []
var called_at := -1.0
var arrives_at := -1.0
var _move := Vector2.ZERO
var _held := false
var _edge := false
var _input_lock := false
var _locked_direction := Vector2.ZERO
var _events: Array = []
var _announced: Dictionary = {}
var _hit: Dictionary = {}
var _closed: Array[String] = []
var _walk: Array[PackedVector2Array] = []
var _holes: Array[PackedVector2Array] = []
var _hubs: Array[PackedVector2Array] = []
var _road_polygons: Dictionary = {}
var _boundaries: Array = []

func start(which_script: int = 0, _seed: int = 0) -> void:
	script_id = posmod(which_script,3); map_data = Island.build(script_id)
	pos = map_data.spawn; checkpoint = pos; heading = 0.0; time = 0.0; health = 3
	status = "running"; paused = false; shelter_id = ""; invulnerable_until = 0.0
	interaction = {"kind":"","target":"","progress":0.0,"required":0.0}
	result = {}; score = 0; lit_beacons.clear(); called_at = -1.0; arrives_at = -1.0
	_move = Vector2.ZERO; _held = false; _edge = false; _input_lock = false; _events.clear(); _announced.clear(); _hit.clear(); _closed.clear()
	_hubs.clear(); _road_polygons.clear()
	for center: Vector2 in map_data.nodes.values(): _hubs.append(Island.hub_polygon(center))
	for road: Dictionary in map_data.roads: _road_polygons[road.id]=Island.road_polygon(road)
	# Prewarm this script's seven finite topologies once, never rebuilding during play.
	var ordered: Array=map_data.roads.filter(func(r): return r.closes_at>=0)
	ordered.sort_custom(func(a,b): return a.closes_at<b.closes_at)
	_rebuild_walk()
	for road: Dictionary in ordered:
		_closed.append(road.id); _rebuild_walk()
	_closed.clear(); _rebuild_walk()

func command(input: Dictionary) -> void:
	if input.has("pause"): paused = bool(input.pause)
	var next_move: Vector2 = (input.get("move",_move) as Vector2).limit_length(1.0)
	if not next_move.is_finite(): next_move=Vector2.ZERO
	var down := bool(input.get("interact",_held))
	var rising := down and not _held
	if _input_lock and (not down or next_move.distance_to(_locked_direction)>0.1):
		_input_lock=false; _cancel()
	_move=next_move
	if rising:
		_edge=true
		_locked_direction=_move
		_input_lock=true
	_held=down
	if not _held: _cancel()
	elif not _input_lock and _move.length_squared()>0.0001: _cancel()

func tick(dt: float) -> void:
	if not is_finite(dt) or paused or status != "running" or dt <= 0.0: return
	var remaining := minf(dt,360.0)
	while remaining>0.000001 and status=="running":
		var step := minf(remaining,1.0/60.0)
		_step(step); remaining -= step

func _step(dt: float) -> void:
	time += dt
	_schedule()
	if shelter_id != "" and _shelter(shelter_id).expires_at<=time:
		_emit("shelter_ejected",shelter_id); shelter_id = ""
	if _edge:
		_edge=false
		_press()
		# An E press stops the actor even if movement remains physically held.
		# A changed/released direction or released E unlocks movement again.
	if _move.length_squared()>0.0001 and not _input_lock:
		_cancel()
		if shelter_id!="": _emit("shelter_left",shelter_id); shelter_id=""
		heading=atan2(-_move.x,-_move.y)
		_move_player(_move*SPEED*dt)
	if _held and _input_lock and interaction.kind!="":
		if interaction.kind == "balloon" and not _exit_open("balloon"): _cancel()
		else:
			interaction.progress += dt
			if interaction.progress+0.000001>=interaction.required:
				if interaction.kind=="balloon": _finish("success","balloon")
				elif interaction.kind=="call":
					called_at=time; arrives_at=time+12.0; _emit("airship_called","airship"); _cancel()
	for rock: Dictionary in map_data.rocks:
		if time>=rock.impact_at and time<rock.ends_at and shelter_id=="" and pos.distance_to(rock.position)<=rock.radius+PLAYER_RADIUS:
			_damage(rock.id,"rock")
	if time>=330.0-0.0000001 and status=="running":
		time=330.0; _finish("rescued","timeout")

func _schedule() -> void:
	var rebuild := false
	for road: Dictionary in map_data.roads:
		if road.closes_at<0: continue
		if time>=road.warns_at: _once("road_warning",road.id)
		if time>=road.closes_at and not _closed.has(road.id):
			_closed.append(road.id); rebuild=true; _emit("road_closed",road.id)
			if Geometry2D.is_point_in_polygon(pos,_road_polygons[road.id]) and not _in_hub(pos):
				_damage("lava_"+road.id,"lava"); pos=checkpoint
	for shelter: Dictionary in map_data.shelters:
		if time>=shelter.warns_at: _once("shelter_warning",shelter.id)
		if time>=shelter.expires_at: _once("shelter_expired",shelter.id)
	for rock: Dictionary in map_data.rocks:
		if time>=rock.warns_at: _once("rock_warning",rock.id)
		if time>=rock.impact_at: _once("rock_impact",rock.id)
	if rebuild:
		_rebuild_walk()
		if not _walkable(pos):
			_damage("lava_boundary","lava"); pos=checkpoint

func _press() -> void:
	if shelter_id!="": _emit("shelter_left",shelter_id); shelter_id=""; return
	for e: Dictionary in map_data.exits:
		if pos.distance_to(e.position)>REACH: continue
		if e.id=="airship":
			if called_at<0: interaction={"kind":"call","target":"airship","progress":0.0,"required":1.0}
			elif time>=arrives_at and _exit_open("airship"): _finish("success","airship")
		elif _exit_open(e.id):
			if e.id=="boat": _finish("success","boat")
			else: interaction={"kind":"balloon","target":"balloon","progress":0.0,"required":6.0}
		return
	for b: Dictionary in map_data.beacons:
		if pos.distance_to(b.position)<=REACH and not lit_beacons.has(b.id):
			lit_beacons.append(b.id); score+=100; _emit("beacon_lit",b.id); return
	for s: Dictionary in map_data.shelters:
		if pos.distance_to(s.position)<=REACH and time<s.expires_at:
			shelter_id=s.id; _emit("shelter_entered",s.id); return

func _exit_open(id: String) -> bool:
	for e: Dictionary in map_data.exits:
		if e.id==id:
			for window: Vector2 in e.windows:
				if time>=window.x and time<=window.y: return true
	return false

func _shelter(id: String) -> Dictionary:
	for s: Dictionary in map_data.shelters:
		if s.id==id: return s
	return {}

func _damage(id: String, kind: String) -> void:
	if kind!="lava":
		if _hit.has(id): return
		_hit[id]=true
	if time<invulnerable_until: return
	health-=1; invulnerable_until=time+2.0; _cancel(); _emit("damage",id,{"kind":kind,"health":health})
	if health<=0: _finish("rescued","health")

func _finish(outcome: String, reason: String) -> void:
	if status!="running": return
	status=outcome
	if outcome=="success": score+=1000+health*100
	result={"status":outcome,"reason":reason,"exit":reason if outcome=="success" else "","score":score,"beacons":lit_beacons.size(),"health":health,"time":time,"script_id":script_id}
	_cancel(); _emit("finished",reason,result)

func _cancel() -> void:
	interaction={"kind":"","target":"","progress":0.0,"required":0.0}

func _once(kind: String,id: String) -> void:
	var key := kind+":"+id
	if not _announced.has(key): _announced[key]=true; _emit(kind,id)

func _emit(kind: String,id: String,extra: Dictionary = {}) -> void:
	var event := {"type":kind,"id":id,"time":time}
	event.merge(extra); _events.append(event)
	if _events.size()>256: _events.pop_front()

func drain_events() -> Array:
	var copy := _events.duplicate(true); _events.clear(); return copy

func _in_hub(point: Vector2) -> bool:
	var centers: Array=map_data.nodes.values()
	for i in centers.size():
		var distance: float=point.distance_squared_to(centers[i])
		if distance<8.88: return true
		if distance<=9.0 and Geometry2D.is_point_in_polygon(point,_hubs[i]): return true
	return false

func _rebuild_walk() -> void:
	var ids := _closed.duplicate(); ids.sort()
	var key := ",".join(ids)
	if _geometry_cache.has(key):
		_walk.assign(_geometry_cache[key].surfaces); _boundaries.assign(_geometry_cache[key].boundaries)
		return
	# Derive the boundary of the actual union directly from source edge arrangements.
	# Iterative polygon merges can mis-handle transient holes when graph cycles open.
	_walk.clear(); _holes.clear(); _boundaries.clear()
	for hub in _hubs: _walk.append(hub)
	for road: Dictionary in map_data.roads:
		if not _closed.has(road.id): _walk.append(_road_polygons[road.id])
	var source_edges: Array = []
	for polygon in _walk:
		for i in polygon.size():
			var a: Vector2=polygon[i]
			var b: Vector2=polygon[(i+1)%polygon.size()]
			source_edges.append({"a":a,"b":b,"bounds":Rect2(a.min(b),a.max(b)-a.min(b)).grow(0.00001)})
	for edge: Dictionary in source_edges:
		var a: Vector2=edge.a
		var b: Vector2=edge.b
		var delta := b-a
		var length_sq := delta.length_squared()
		var ts: Array[float]=[0.0,1.0]
		for other: Dictionary in source_edges:
			if not edge.bounds.intersects(other.bounds,true): continue
			var hit = Geometry2D.segment_intersects_segment(a,b,other.a,other.b)
			if hit!=null: ts.append(clampf((hit-a).dot(delta)/length_sq,0,1))
			# Collinear shared endpoints also partition boundary intervals.
			for endpoint: Vector2 in [other.a,other.b]:
				if _point_segment_distance_sq(endpoint,a,b)<0.0000000001:
					ts.append(clampf((endpoint-a).dot(delta)/length_sq,0,1))
		ts.sort()
		for i in range(ts.size()-1):
			if ts[i+1]-ts[i]<0.000001: continue
			var c := a+delta*ts[i]
			var d := a+delta*ts[i+1]
			var middle := (c+d)*0.5
			var normal := delta.normalized().orthogonal()*0.0001
			if _strict_center_supported(middle+normal)==_strict_center_supported(middle-normal): continue
			_boundaries.append({"a":c,"b":d,"bounds":Rect2(c.min(d),c.max(d)-c.min(d)).grow(PLAYER_RADIUS)})

	_geometry_cache[key]={"surfaces":_walk.duplicate(),"boundaries":_boundaries.duplicate()}

func _strict_center_supported(point: Vector2) -> bool:
	# Native is_point_in_polygon treats near-edge points as boundary points. For
	# exposed-edge classification use a strict ray crossing, with no edge tolerance.
	for polygon in _walk:
		var inside := false
		var j := polygon.size()-1
		for i in polygon.size():
			var a: Vector2=polygon[i]
			var b: Vector2=polygon[j]
			if (a.y>point.y)!=(b.y>point.y):
				if point.x<(b.x-a.x)*(point.y-a.y)/(b.y-a.y)+a.x: inside=not inside
			j=i
		if inside: return true
	return false

func _center_supported(point: Vector2) -> bool:
	for polygon in _walk:
		if Geometry2D.is_point_in_polygon(point,polygon): return true
	return false

func _walkable(point: Vector2) -> bool:
	if not point.is_finite() or not _center_supported(point): return false
	# Exact disk-to-raw-union clearance: polygon offset round joins are approximate
	# and can leak an actor footprint at acute diagonal-road junctions.
	for edge: Dictionary in _boundaries:
		if edge.bounds.has_point(point) and _point_segment_distance_sq(point,edge.a,edge.b)<PLAYER_RADIUS*PLAYER_RADIUS: return false
	return true

func _point_segment_distance_sq(point: Vector2,a: Vector2,b: Vector2) -> float:
	return point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,a,b))

func _segment_clear(a: Vector2,b: Vector2) -> bool:
	if not _walkable(a) or not _walkable(b): return false
	if a.distance_squared_to(b)<0.0000000001: return true
	var motion_bounds := Rect2(a.min(b),a.max(b)-a.min(b)).grow(0.000001)
	# Swept disk = capsule. A segment disjoint from the union boundary stays in
	# the same component; capsule clearance is the exact segment/segment distance.
	for edge: Dictionary in _boundaries:
		if not motion_bounds.intersects(edge.bounds,true): continue
		var c: Vector2=edge.a
		var d: Vector2=edge.b
		if Geometry2D.segment_intersects_segment(a,b,c,d)!=null: return false
		var minimum := minf(minf(_point_segment_distance_sq(a,c,d),_point_segment_distance_sq(b,c,d)),minf(_point_segment_distance_sq(c,a,b),_point_segment_distance_sq(d,a,b)))
		if minimum<PLAYER_RADIUS*PLAYER_RADIUS: return false
	return true

func _move_player(delta: Vector2) -> void:
	var target := pos+delta
	var contact := target+delta.normalized()*PLAYER_RADIUS
	for road: Dictionary in map_data.roads:
		if _closed.has(road.id) and not _in_hub(contact) and Geometry2D.is_point_in_polygon(contact,_road_polygons[road.id]):
			_damage("lava_"+road.id,"lava"); pos=checkpoint; return
	if _segment_clear(pos,target): pos=target
	else:
		var x := pos+Vector2(delta.x,0)
		var z := pos+Vector2(0,delta.y)
		if _segment_clear(pos,x): pos=x
		elif _segment_clear(pos,z): pos=z
	# Only actually visited safe hub centers are checkpoints; never a forward destination.
	for center: Vector2 in map_data.nodes.values():
		if pos.distance_to(center)<0.4: checkpoint=pos

func snapshot() -> Dictionary:
	var roads: Array = map_data.roads.duplicate(true)
	for r: Dictionary in roads: r.state="closed" if _closed.has(r.id) else ("warning" if r.warns_at>=0 and time>=r.warns_at else "open")
	var shelters: Array = map_data.shelters.duplicate(true)
	for s: Dictionary in shelters: s.state="expired" if time>=s.expires_at else ("warning" if time>=s.warns_at else "open")
	var rocks: Array = map_data.rocks.duplicate(true)
	for r: Dictionary in rocks: r.state="spent" if time>=r.ends_at else ("impact" if time>=r.impact_at else ("warning" if time>=r.warns_at else "pending"))
	var exits: Array = map_data.exits.duplicate(true)
	for e: Dictionary in exits: e.open=_exit_open(e.id); e.called_at=called_at if e.id=="airship" else -1.0; e.arrives_at=arrives_at if e.id=="airship" else -1.0
	var beacons: Array = map_data.beacons.duplicate(true)
	for b: Dictionary in beacons: b.lit=lit_beacons.has(b.id)
	return {"map":map_data.duplicate(true),"script_id":script_id,"time":time,"status":status,"paused":paused,"position":pos,"heading":heading,"health":health,"checkpoint":checkpoint,"invulnerable_until":invulnerable_until,"shelter_id":shelter_id,"interaction":interaction.duplicate(),"roads":roads,"shelters":shelters,"rocks":rocks,"exits":exits,"beacons":beacons,"score":score,"result":result.duplicate(true)}
