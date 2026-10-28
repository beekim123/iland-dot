extends Node3D
## Read-only presentation of the authoritative island. All navigable surfaces are
## precisely derived from map_data. Decorative land is visibly BELOW walkways.
const Batch = preload("clay_batch.gd")
const Island = preload("../../data/island.gd")
const SAND := Color("c6beaa")
const CREAM := Color("fff0cb")
const SLATE := Color("425e68")
const TEAL := Color("24a6a0")
const ORANGE := Color("ed7c3d")
const RED := Color("dc573e")
const GREEN := Color("b0e1a5")
var map_data: Dictionary = {}
var road_visuals: Dictionary = {}
var shelter_visuals: Dictionary = {}
var exit_visuals: Dictionary = {}
var beacon_visuals: Dictionary = {}
var rock_visuals: Dictionary = {}
var coastline := PackedVector2Array()
var batches: Dictionary = {}
var triangle_count := 0
var _last_time := 0.0
var _escape_elapsed := 0.0
var _last_status := "running"

func build(data: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	map_data = data.duplicate(true)
	batches.clear(); road_visuals.clear(); shelter_visuals.clear()
	exit_visuals.clear(); beacon_visuals.clear(); rock_visuals.clear()
	triangle_count = 0; _escape_elapsed = 0; _last_time = 0; _last_status = "running"
	_build_island()
	for id in data.nodes:
		var p: Vector2 = data.nodes[id]
		_batch(p).cylinder(_v(p,-0.465),float(data.hub_radius),0.87,Color("687575"))
		_polygon(_batch(p), Island.hub_polygon(p), 0.0, SAND)
	for road: Dictionary in data.roads: _road(road)
	for shelter: Dictionary in data.shelters: _shelter(shelter)
	for e: Dictionary in data.exits: _exit(e)
	for b: Dictionary in data.beacons: _beacon(b)
	for r: Dictionary in data.rocks: _rock(r)
	for key in batches:
		var batch = batches[key]
		batch.create(self,"Terrain_"+str(key))
		triangle_count += batch.triangles

func _batch(p: Vector2):
	var key := Vector2i(floori(p.x/16.0),floori(p.y/16.0))
	if not batches.has(key): batches[key] = Batch.new()
	return batches[key]

func _v(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3(p.x,y,p.y)

func _polygon(batch, polygon: PackedVector2Array, height: float, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(polygon)
	var linear := color.srgb_to_linear()
	for i in range(0,indices.size(),3):
		# Godot clockwise front faces: XY CCW mapped to XZ has cross -UP.
		for j in [0,1,2]:
			batch.vertices.append(_v(polygon[indices[i+j]],height))
			batch.normals.append(Vector3.UP)
			batch.colors.append(linear)
		batch.triangles += 1

func _build_island() -> void:
	var land = _batch(Vector2.ZERO)
	coastline.clear()
	# Radial scallops with broad coves, a projecting northern volcano cape.
	for i in 96:
		var a := TAU*i/96.0
		var scallop := 1.0+0.048*sin(a*7.0)+0.026*cos(a*11.0)
		var shore := Vector2(cos(a)*34.0,sin(a)*43.0-5.0)*scallop
		# South harbour inlet reaches the boat while preserving the full K hub.
		if shore.y>27.2 and absf(shore.x)<10.0: shore.y=minf(shore.y,27.2+absf(shore.x)*0.9)
		coastline.append(shore)
	_polygon(land,coastline,-1.28,Color("b0a18d"))
	var inner := PackedVector2Array()
	for p in coastline: inner.append(p*0.96)
	_polygon(land,inner,-1.2,Color("789a8d"))
	for i in coastline.size():
		var p := coastline[i]; var q := coastline[(i+1)%coastline.size()]
		var mesh := ArrayMesh.new(); var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([_v(p,-1.28),_v(q,-1.8),_v(q,-1.28),_v(p,-1.28),_v(p,-1.8),_v(q,-1.8)])
		var outward := Vector3(p.x+q.x,0,p.y+q.y+10).normalized()
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([outward,outward,outward,outward,outward,outward])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		land.add(mesh,Transform3D.IDENTITY,Color("897e73"))
	var sea = Batch.new()
	sea.box(Vector3(0,-1.9,0),Vector3(400,0.12,400),Color("318c98"))
	sea.create(self,"TealSea")
	triangle_count += sea.triangles
	# Shoreline foam clusters and outlying pebbles are never gameplay obstacles.
	for i in range(0,96,3):
		var p: Vector2 = coastline[i]*1.04
		var b = _batch(p)
		b.sphere(_v(p,-1.72),Vector3(2.4,0.07,0.45),Color("a8dad1"))
		if i%9==0: b.sphere(_v(p,-1.15),Vector3(1.7,1.5,2.0),SLATE)
	# Large volcano entirely outside the authoritative walkways.
	var volcano = _batch(Vector2(0,-39))
	volcano.cylinder(Vector3(0,2.7,-39),10.0,6.0,Color("976d55"),4.2)
	for i in 10:
		var a := i*TAU/10.0
		volcano.sphere(Vector3(cos(a)*7.0,0.1,-39+sin(a)*7.0),Vector3(5.0,3.4,4.4),Color("8b7564"))
	# Rounded channels descend the inaccessible north cape only.
	for i in 3:
		var a := -0.2+i*1.4
		var top := Vector3(cos(a)*3.0,6.85,-39+sin(a)*3.0)
		var foot := Vector3(cos(a)*8.4,0.8,-39+sin(a)*8.4)
		volcano.beam(top,foot,0.55,Color("654f49"))
		volcano.beam(top+Vector3(0,0.12,0),foot+Vector3(0,0.12,0),0.19,Color("d47e50"))
	volcano.cylinder(Vector3(0,6.1,-39),4.3,1.6,Color("b88c67"),3.3)
	volcano.cylinder(Vector3(0,6.91,-39),3.2,0.12,Color("653f3c"))
	volcano.cylinder(Vector3(0,6.99,-39),2.35,0.08,ORANGE)
	for i in 12:
		var angle := TAU*i/12.0
		volcano.sphere(Vector3(cos(angle)*3.35,6.85,-39+sin(angle)*3.35),Vector3(1.7,0.8,1.6),Color("a98262"))
	# Bounded clay ash puffs live high over crater, never over road warnings.
	for i in 5:
		volcano.sphere(Vector3(0.6*i,8.5+i*0.9,-39),Vector3(2.0+i*0.35,1.4,1.8),Color("b6aaa0"))
	# Distinct planted pockets: reject every authoritative walkway with margin.
	for i in 75:
		var p := Vector2(sin(i*2.399)*sqrt(float(i)/75.0)*29,cos(i*2.399)*sqrt(float(i)/75.0)*34)
		if _near_walkway(p,2.8) or p.y < -28.0: continue
		var b = _batch(p)
		b.sphere(_v(p,-0.8),Vector3(2.8,1.1,2.7),Color("67756c"))
		if i%3==0:
			b.beam(_v(p,-1.1),_v(p+Vector2(0.2,0),1.6),0.15,Color("a87951"))
			for j in 5:
				var a := j*TAU/5
				b.sphere(_v(p+Vector2(cos(a),sin(a))*0.65,1.65),Vector3(1.7,0.35,0.85),Color("648d71"))

	# Island interior is a rugged, sunken basalt garden, not walkable flat lawn.
	for x in [-9.0,9.0]:
		for z in [-16.0,0.0,16.0]:
			var p := Vector2(x,z)
			if _near_walkway(p,3.4): continue
			var b = _batch(p)
			b.sphere(_v(p,-1.12),Vector3(12,0.22,10),Color("425d60"))
			for i in 9:
				var a := i*2.399
				var q := p+Vector2(cos(a),sin(a))*sqrt(float(i))*1.05
				var h := 1.2+fmod(i*0.71,1.4)
				b.sphere(_v(q,-1.0+h*0.35),Vector3(2.3,h,2.2),Color("6d7773") if i%2==0 else Color("7b8274"))
				if i%3==0: b.sphere(_v(q+Vector2(0.5,0.4),h*0.45-0.8),Vector3(1.3,0.8,1.6),Color("718b72"))

func _near_walkway(p: Vector2, margin: float) -> bool:
	for center: Vector2 in map_data.nodes.values():
		if p.distance_to(center)<float(map_data.hub_radius)+margin: return true
	for road: Dictionary in map_data.roads:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p,road.a,road.b))<float(road.width)*0.5+margin: return true
	return false

func _road(road: Dictionary) -> void:
	var a: Vector2 = road.a; var b: Vector2 = road.b
	var center := (a+b)*0.5
	var batch = _batch(center)
	batch.box(_v(center,-0.465),Vector3(road.width,0.87,a.distance_to(b)),Color("687575"),atan2(b.x-a.x,b.y-a.y))
	_polygon(batch,Island.road_polygon(road),0.0,SAND)
	# Subtle slab seams, readable as built elevated safe causeways.
	var seam_direction := (b-a).normalized()
	for step in range(3,int(a.distance_to(b))-2,2):
		batch.box(_v(a+seam_direction*step,0.012),Vector3(road.width*0.97,0.015,0.025),Color("838b85"),atan2(seam_direction.x,seam_direction.y))
	var delta := (b-a).normalized(); var side := delta.orthogonal()
	# Low slate edge dots mark the true safe corridor; no high blocking rails.
	for step in range(2,int(a.distance_to(b))-1,2):
		for sign_value in [-1.0,1.0]:
			batch.box(_v(a+delta*step+side*(road.width*0.5+0.12)*sign_value,-0.01),Vector3(0.28,0.06,0.38),SLATE)
	var node := Node3D.new(); node.name="Road_"+road.id; add_child(node)
	var warning_batch = Batch.new()
	for step in range(3,int(a.distance_to(b))-2,3):
		var p := a+delta*step
		warning_batch.box(_v(p,0.045),Vector3(0.18,0.03,road.width*0.78),ORANGE,-atan2(delta.y,delta.x))
	var warning: MeshInstance3D = warning_batch.create(node,"TwentySecondWarning",true)
	warning.visible=false
	var lava_batch = Batch.new()
	# Leave 3m hub disks untouched; closure is visible between node platforms.
	var length := maxf(0.1,a.distance_to(b)-6.0)
	lava_batch.box(Vector3.ZERO,Vector3(road.width,0.09,length),Color("d85a37"))
	for i in 4:
		lava_batch.sphere(Vector3(sin(i*2.1)*road.width*0.28,0.06,(float(i)/3.0-0.5)*length*0.9),Vector3(0.65,0.08,0.8),Color("ffb14f"))
	var lava: MeshInstance3D = lava_batch.create(node,"SlowLava",true)
	lava.position=_v(center,0.07); lava.rotation.y=atan2(delta.x,delta.y); lava.visible=false
	road_visuals[road.id]={"warning":warning,"lava":lava,"center":center}
	triangle_count += warning_batch.triangles+lava_batch.triangles

func _shelter(s: Dictionary) -> void:
	var p: Vector2 = s.position
	var body = _batch(p)
	# Four open arch entries; supports sit outside the exact hub disk and road strips.
	for offset in [Vector2(-2.45,-2.45),Vector2(2.45,-2.45),Vector2(-2.45,2.45),Vector2(2.45,2.45)]:
		var on_road := false
		for road: Dictionary in map_data.roads:
			if (p+offset).distance_to(Geometry2D.get_closest_point_to_segment(p+offset,road.a,road.b))<road.width*0.5+0.2: on_road=true
		if not on_road: body.cylinder(_v(p+offset,1.2),0.17,2.4,SLATE)
	body.ring(_v(p,0.028),2.7,0.09,SLATE)
	var root := Node3D.new(); root.name=s.id; root.position=_v(p); add_child(root)
	var partial = Batch.new()
	partial.sphere(Vector3(0,2.8,-1.8),Vector3(6.0,1.0,2.6),SLATE)
	partial.box(Vector3(0,2.45,2.4),Vector3(3.2,0.25,0.45),CREAM)
	for sign_value in [-1.0,1.0]:
		var corner := Vector3(sign_value*2.6,1.15,-2.6)
		var blocked := false
		for road: Dictionary in map_data.roads:
			var at := p+Vector2(corner.x,corner.z)
			if at.distance_to(Geometry2D.get_closest_point_to_segment(at,road.a,road.b))<road.width*0.5+0.6: blocked=true
		if blocked: continue
		partial.box(corner,Vector3(1.3,2.3,0.32),SLATE,-sign_value*PI/4)
		partial.box(corner+Vector3(0,0.3,0.2),Vector3(0.8,0.17,0.12),CREAM,-sign_value*PI/4)
	partial.create(root,"PermanentRearShellAndDoorLintel")
	triangle_count+=partial.triangles
	var roof_batch = Batch.new()
	roof_batch.sphere(Vector3(0,2.8,0),Vector3(6.9,1.7,6.9),SLATE)
	roof_batch.cylinder(Vector3(0,2.48,0),3.4,0.15,CREAM)
	var roof: MeshInstance3D = roof_batch.create(root,"CutawayCanopy")
	var light_batch = Batch.new()
	light_batch.ring(Vector3(0,2.58,0),3.46,0.13,GREEN)
	var light: MeshInstance3D = light_batch.create(root,"ProtectionIndicator",true)
	var amber_batch = Batch.new()
	amber_batch.ring(Vector3(0,2.58,0),3.46,0.13,ORANGE)
	var amber: MeshInstance3D = amber_batch.create(root,"ExpiryWarning",true)
	amber.visible=false
	# Reachable console beside the open central standing position.
	body.cylinder(_v(p+Vector2(0.72,0),0.34),0.12,0.68,SLATE)
	body.box(_v(p+Vector2(0.72,0),0.76),Vector3(0.38,0.25,0.3),CREAM)
	body.box(_v(p+Vector2(0.72,0.17),0.79),Vector3(0.25,0.13,0.04),TEAL)
	shelter_visuals[s.id]={"roof":roof,"light":light,"amber":amber,"position":p}
	triangle_count += roof_batch.triangles+light_batch.triangles+amber_batch.triangles

func _exit(e: Dictionary) -> void:
	var p: Vector2 = e.position
	var fixed = _batch(p)
	fixed.ring(_v(p,0.035),2.6,0.1,CREAM)
	fixed.cylinder(_v(p+Vector2(0.7,0),0.4),0.12,0.8,SLATE)
	fixed.box(_v(p+Vector2(0.7,0),0.85),Vector3(0.44,0.32,0.35),CREAM)
	fixed.box(_v(p+Vector2(0.7,0.2),0.87),Vector3(0.28,0.18,0.04),TEAL)
	var root := Node3D.new(); root.name="Rescue_"+e.id; root.position=_v(p); add_child(root)
	var model = Batch.new()
	var boarding := Vector3.ZERO
	if e.id=="boat":
		# Vessel outboard of south hub, with an uninterrupted gangway to its deck.
		boarding=Vector3(0,0,4.7)
		fixed.box(_v(p+Vector2(0,2.5),-0.12),Vector3(2.2,0.24,5),Color("b28b61"))
		for x in [-1.4,1.4]: fixed.cylinder(_v(p+Vector2(x,3.7),0.25),0.16,1.5,SLATE)
		model.sphere(Vector3(0,-0.95,4.7),Vector3(3.4,2.0,5.1),SLATE)
		model.box(Vector3(0,0.25,4.7),Vector3(2.8,0.18,3.8),CREAM)
		model.box(Vector3(0,1.05,5.5),Vector3(1.9,1.5,1.8),CREAM)
		model.box(Vector3(0,1.3,4.56),Vector3(1.25,0.55,0.08),TEAL)
		model.box(Vector3(0,1.86,5.5),Vector3(2.3,0.25,2.1),ORANGE)
		for side in [-1.0,1.0]:
			for z in [5.15,5.85]:
				model.sphere(Vector3(side*0.97,1.15,z),Vector3(0.05,0.38,0.38),TEAL)
			model.beam(Vector3(side*1.3,0.65,3.2),Vector3(side*1.3,0.65,4.3),0.045,CREAM)
		model.beam(Vector3(0,1.95,5.6),Vector3(0,3.2,5.6),0.07,SLATE)
		model.sphere(Vector3(0,0.85,3.4),Vector3(0.75,0.75,0.18),ORANGE)
	elif e.id=="balloon":
		boarding=Vector3(0,0,0)
		model.cylinder(Vector3(0,-0.1,0),1.6,0.2,Color("aa7857"))
		# Open basket with low rear wicker panels; front entry stays unclosed.
		for side in [-1.0,1.0]:
			model.box(Vector3(side*1.3,0.28,-0.55),Vector3(0.12,0.55,1.1),Color("ab886a"))
			model.beam(Vector3(side*1.3,0.57,-1.1),Vector3(side*1.3,0.57,0),0.055,CREAM)
		model.box(Vector3(0,0.28,-1.25),Vector3(2.5,0.55,0.12),Color("ab886a"))
		model.beam(Vector3(-1.2,0.6,-1.2),Vector3(-1.1,3.3,-2.5),0.04,CREAM)
		model.beam(Vector3(1.2,0.6,-1.2),Vector3(1.1,3.3,-2.5),0.04,CREAM)
		# Open basket mouth avoids hiding the boarding traveler.
		for x in [-1.2,1.2]:
			model.beam(Vector3(x,0.4,0),Vector3(x,3.3,-2.5),0.055,SLATE)
		model.sphere(Vector3(0,5.2,-2.5),Vector3(4.8,5.3,4.8),ORANGE)
		model.sphere(Vector3(0,5.24,-2.6),Vector3(3.0,5.35,4.85),CREAM)
		model.cylinder(Vector3(0,2.8,-2.5),0.42,0.5,SLATE)
		for x in [-3.1,3.1]:
			fixed.beam(_v(p+Vector2(x,-3.1),0.1),_v(p+Vector2(x*0.4,-2.5),3.0),0.035,CREAM)
	else:
		boarding=Vector3(-4.6,0,0)
		fixed.box(_v(p+Vector2(-2.8,0),-0.12),Vector3(5.6,0.24,2.1),CREAM)
		fixed.beam(_v(p+Vector2(-3.1,-2.4),0),_v(p+Vector2(-3.1,-2.4),4),0.14,SLATE)
		model.sphere(Vector3(-5.5,4.5,0),Vector3(7.6,3.1,3.5),CREAM)
		model.sphere(Vector3(-5.5,4.6,0),Vector3(7.7,1.1,3.54),TEAL)
		model.box(Vector3(-5,1.1,0),Vector3(3.6,1.3,1.8),SLATE)
		model.box(Vector3(-3.15,1.25,0),Vector3(0.08,0.55,1.1),TEAL)
		for x in [-6.4,-3.8]: model.beam(Vector3(x,1.7,0),Vector3(x,3.5,0),0.07,SLATE)
		model.box(Vector3(-8.8,4.5,0),Vector3(1.6,0.15,3.6),ORANGE)
	var vehicle: MeshInstance3D = model.create(root,"Vehicle")
	var lamp_batch = Batch.new(); lamp_batch.ring(Vector3(0,0.055,0),2.35,0.13,GREEN)
	var lamp: MeshInstance3D = lamp_batch.create(root,"BoardingWindow",true)
	exit_visuals[e.id]={"vehicle":vehicle,"lamp":lamp,"boarding":_v(p)+boarding,"root":root}
	triangle_count += model.triangles+lamp_batch.triangles

func _beacon(b: Dictionary) -> void:
	var p: Vector2=b.position; var fixed=_batch(p)
	# Controls at the actual interaction point, no buried trigger ball.
	fixed.cylinder(_v(p+Vector2(0.5,0),0.65),0.12,1.3,SLATE)
	fixed.cylinder(_v(p+Vector2(0.5,0),0.17),0.32,0.34,CREAM)
	var batch=Batch.new(); batch.sphere(_v(p+Vector2(0.5,0),1.42),Vector3(0.55,0.65,0.55),GREEN)
	var light: MeshInstance3D=batch.create(self,b.id,true)
	beacon_visuals[b.id]=light; triangle_count+=batch.triangles

func _rock(r: Dictionary) -> void:
	var root:=Node3D.new(); root.position=_v(r.position); root.name=r.id; add_child(root)
	var mark=Batch.new(); mark.ring(Vector3(0,0.095,0),r.radius,0.13,RED)
	mark.box(Vector3(0,0.10,0),Vector3(0.10,0.025,r.radius*1.25),RED,PI/4)
	mark.box(Vector3(0,0.10,0),Vector3(0.10,0.025,r.radius*1.25),RED,-PI/4)
	var warning: MeshInstance3D=mark.create(root,"FourSecondExactRadius",true)
	var rock=Batch.new(); rock.sphere(Vector3.ZERO,Vector3(0.8,0.85,0.75),SLATE)
	var stone: MeshInstance3D=rock.create(root,"FallingClayRock")
	root.visible=false
	rock_visuals[r.id]={"root":root,"warning":warning,"stone":stone}
	triangle_count+=mark.triangles+rock.triangles

func update_state(snapshot: Dictionary, _events: Array = []) -> void:
	var time: float=snapshot.get("time",0.0)
	var player: Vector2=snapshot.get("position",Vector2.ZERO)
	for r: Dictionary in snapshot.get("roads",[]):
		if not road_visuals.has(r.id): continue
		var v: Dictionary=road_visuals[r.id]
		v.warning.visible=r.state=="warning"
		v.lava.visible=r.state=="closed"
		# Lava accumulates gradually AFTER the fully announced closure.
		v.lava.scale.x=clampf((time-float(r.closes_at))/6.0,0.05,1.0)
		v.lava.scale.y=clampf((time-float(r.closes_at))/6.0,0.05,1.0)
	for s: Dictionary in snapshot.get("shelters",[]):
		if not shelter_visuals.has(s.id): continue
		var v: Dictionary=shelter_visuals[s.id]
		v.roof.visible=player.distance_to(s.position)>5.0 and snapshot.get("shelter_id","")!=s.id
		v.light.visible=s.state=="open"
		v.amber.visible=s.state=="warning"
		v.amber.scale=Vector3.ONE*(1.0+0.025*sin(time*5.0)) if s.state=="warning" else Vector3.ONE
	for b: Dictionary in snapshot.get("beacons",[]):
		if beacon_visuals.has(b.id): beacon_visuals[b.id].visible=bool(b.lit)
	for r: Dictionary in snapshot.get("rocks",[]):
		if not rock_visuals.has(r.id): continue
		var v: Dictionary=rock_visuals[r.id]
		v.root.visible=r.state=="warning" or r.state=="impact"
		v.warning.visible=v.root.visible
		v.stone.visible=r.state=="impact" or (r.state=="warning" and time>=r.impact_at-0.65)
		v.stone.position.y=maxf(0.3,(float(r.impact_at)-time)*9.0)
	for e: Dictionary in snapshot.get("exits",[]):
		if not exit_visuals.has(e.id): continue
		var v: Dictionary=exit_visuals[e.id]
		v.lamp.visible=bool(e.open)
		if e.id=="airship":
			v.vehicle.visible=float(e.get("called_at",-1))>=0
			v.vehicle.position.y=clampf((float(e.get("arrives_at",0))-time)*0.65,0,10)
	var status: String=snapshot.get("status","running")
	if status=="success":
		if _last_status!="success": _escape_elapsed=0.0
		var result: Dictionary=snapshot.get("result",{})
		var exit_id: String=result.get("exit",result.get("exit_id",""))
		if exit_visuals.has(exit_id):
			var vehicle: MeshInstance3D=exit_visuals[exit_id].vehicle
			var departing := maxf(0.0,_escape_elapsed-1.25)
			vehicle.position=Vector3(0,departing*1.2,0) if exit_id!="boat" else Vector3(0,0,departing*1.8)
	_last_status=status; _last_time=time

func _process(delta: float) -> void:
	# Presentation-only boarding flight, never affects gameplay or moving obstacles.
	if _last_status=="success": _escape_elapsed=minf(_escape_elapsed+delta,5.0)

func boarding_position(exit_id: String) -> Vector3:
	if not exit_visuals.has(exit_id): return Vector3.ZERO
	return exit_visuals[exit_id].boarding + exit_visuals[exit_id].vehicle.position

func geometry_report() -> Dictionary:
	var safe:=true
	for road: Dictionary in map_data.roads:
		for p: Vector2 in Island.road_polygon(road): safe=safe and Geometry2D.is_point_in_polygon(p,coastline)
	for p: Vector2 in map_data.nodes.values():
		for q: Vector2 in Island.hub_polygon(p): safe=safe and Geometry2D.is_point_in_polygon(q,coastline)
	return {"triangles":triangle_count,"terrain_contains_walkways":safe,"roads":road_visuals.size(),"shelters":shelter_visuals.size(),"exits":exit_visuals.size(),"beacons":beacon_visuals.size(),"spatial_batches":batches.size()}
