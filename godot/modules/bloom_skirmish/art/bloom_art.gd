extends RefCounted
## Original sunlit greenhouse sports art; rebuilt for a separate visual identity. Ground is Y=0, gardener faces -Z.
## Animal GLBs contain real weighted skeletons and authored PBR surfaces.
## No external model assets or runtime Blender dependency. Static props use vertex colors.
const TEAL := Color("2f62ff")
const CORAL := Color("ff8a1f")
const CREAM := Color("dce1e1")
const INK := Color("252e38")
const GOLD := Color("a6b3c1")
const LEAF := Color("536e52")
const LEAF_LIGHT := Color("91ab73")
const SOIL := Color("846450")
const WOOD := Color("d9a270")
static var _cache: Dictionary = {}
static var _materials: Dictionary = {}
static var _animal_scenes: Dictionary = {}

static func team_color(team: int) -> Color:
	return TEAL if team == 0 else CORAL

static func _material(kind: String = "cloth") -> StandardMaterial3D:
	if _materials.has(kind): return _materials[kind]
	var mat:=StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo=true;mat.vertex_color_is_srgb=true
	mat.roughness=.86;mat.metallic_specular=.30
	if kind=="coated": mat.roughness=.28;mat.metallic=.22;mat.metallic_specular=.65
	elif kind=="mineral": mat.roughness=.94;mat.metallic_specular=.18
	elif kind=="glass":
		mat.roughness=.08;mat.metallic_specular=.85;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	_materials[kind]=mat
	return mat

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func _finish(st: SurfaceTool, material_kind: String = "cloth") -> ArrayMesh:
	st.index()
	var mesh := st.commit()
	mesh.surface_set_material(0, _material(material_kind))
	return mesh

static func _primitive(kind: String) -> Mesh:
	if _cache.has(kind): return _cache[kind]
	var mesh: Mesh
	match kind:
		"ball":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 16
			s.rings = 8
			mesh = s
		"bud":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 8
			s.rings = 3
			mesh = s
		"tiny":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 10
			s.rings = 5
			mesh = s
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 16
			mesh = c
		"open_cylinder":
			var c := CylinderMesh.new()
			c.top_radius=.5; c.bottom_radius=.5; c.height=1; c.radial_segments=20; c.cap_top=false; c.cap_bottom=false
			mesh=c
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.34
			c.height = 1.0
			c.radial_segments = 20
			mesh = c
		"box":
			var b := BoxMesh.new()
			b.size = Vector3.ONE
			mesh = b
		"ring":
			var t := TorusMesh.new()
			t.inner_radius = 0.36
			t.outer_radius = 0.5
			t.rings = 20
			t.ring_segments = 8
			mesh = t
	_cache[kind] = mesh
	return mesh

static func _shape(st: SurfaceTool, kind: String, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh := _primitive(kind)
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis := Basis.from_euler(rot).scaled(size)
	# Scale belongs in the local basis, then rotation (nonuniform plush volumes).
	basis = Basis.from_euler(rot) * Basis.from_scale(size)
	var normal_basis := basis.inverse().transposed()
	st.set_color(color)
	for i in indices:
		st.set_normal((normal_basis * norms[i]).normalized())
		st.add_vertex(basis * verts[i] + pos)

static func _ball(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	_shape(st, "ball", pos, size, color, rot)

static func _tiny(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	_shape(st, "tiny", pos, size, color, rot)

static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var d := b - a
	if d.length() < 0.0001: return
	var rot := Quaternion(Vector3.UP, d.normalized()).get_euler()
	_shape(st, "cylinder", (a + b) * 0.5, Vector3(radius * 2.0, d.length(), radius * 2.0), color, rot)
	_tiny(st, a, Vector3.ONE * radius * 2.0, color)
	_tiny(st, b, Vector3.ONE * radius * 2.0, color)

## Rounded cuboid using analytic bevel normals. Eight support strips per face.
static func _round(st: SurfaceTool, center: Vector3, size: Vector3, radius: float, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var basis := Basis.from_euler(rot)
	var h := size * 0.5
	radius = minf(radius, minf(h.x, minf(h.y, h.z)) * 0.9)
	var inner := h - Vector3.ONE * radius
	st.set_color(color)
	for normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var u: Vector3 = Vector3.UP.cross(normal).normalized() if absf(normal.y) < 0.5 else Vector3.RIGHT
		var v := normal.cross(u)
		var au := 1.0 - radius / absf(u.dot(h))
		var bv := 1.0 - radius / absf(v.dot(h))
		var us := [-1.0, -au, au, 1.0]
		var vs := [-1.0, -bv, bv, 1.0]
		for iy in 3:
			for ix in 3:
				for corner: Vector2i in [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1), Vector2i(0,0), Vector2i(1,1), Vector2i(1,0)]:
					var raw := (normal + u * float(us[ix+corner.x]) + v * float(vs[iy+corner.y])) * h
					var core := raw.clamp(-inner, inner)
					var n := (raw - core).normalized()
					st.set_normal(basis * n)
					st.add_vertex(center + basis * (core + n * radius))

## Convex pointed plush leaf, with a subtle seam stitched onto its face.
static func _leaf(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, seam: bool = false, cheap: bool = false) -> void:
	_shape(st, "bud" if cheap else "ball", pos, size, color, rot)
	var basis := Basis.from_euler(rot)
	if seam:
		_tube(st, pos + basis * Vector3(0, size.y * 0.44, -size.z * 0.12), pos + basis * Vector3(0, size.y * 0.44, size.z * 0.34), size.y * 0.06, color.lightened(0.25))

static func _node(mesh: Mesh, name: String, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.name = name
	n.position = pos
	return n

static func _part(root: Node3D, st: SurfaceTool, name: String, pos: Vector3) -> MeshInstance3D:
	var n := _node(_finish(st), name, pos)
	n.set_meta("rest", pos)
	root.add_child(n)
	return n

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, color: Color) -> void:
	st.set_color(color)
	if (b-a).cross(c-a).dot(na+nb+nc) > 0.0:
		st.set_normal(na); st.add_vertex(a)
		st.set_normal(nc); st.add_vertex(c)
		st.set_normal(nb); st.add_vertex(b)
	else:
		st.set_normal(na); st.add_vertex(a)
		st.set_normal(nb); st.add_vertex(b)
		st.set_normal(nc); st.add_vertex(c)

## Authored cross-section lofts: chin, shoulders, waist and tapered garments.
## Ring Vector4 = height, half-width, half-depth, fore/aft offset.
static func _loft(st: SurfaceTool, pos: Vector3, rings: Array, color: Color, sides: int = 16, rot: Vector3 = Vector3.ZERO, squareness: float = 1.0) -> void:
	var basis := Basis.from_euler(rot)
	var vertices: Array = []; var normals: Array = []
	for ri in rings.size():
		var ring: Vector4 = rings[ri]
		var previous: Vector4 = rings[maxi(0,ri-1)]
		var next: Vector4 = rings[mini(rings.size()-1,ri+1)]
		var dy := maxf(.001,next.x-previous.x)
		var slope_x := (next.y-previous.y)/dy
		var slope_z := (next.z-previous.z)/dy
		var row: Array[Vector3] = []; var ns: Array[Vector3] = []
		for j in sides:
			var a := TAU*float(j)/float(sides)
			var cx := cos(a); var sz := sin(a)
			var x := signf(cx)*pow(absf(cx),squareness)
			var z := signf(sz)*pow(absf(sz),squareness)
			row.append(pos+basis*Vector3(x*ring.y,ring.x,z*ring.z+ring.w))
			var n := Vector3(cx/maxf(.01,ring.y),-(cx*cx*slope_x+sz*sz*slope_z)*4.0,sz/maxf(.01,ring.z)).normalized()
			ns.append(basis*n)
		vertices.append(row); normals.append(ns)
	for ri in rings.size()-1:
		for j in sides:
			var k := (j+1)%sides
			_tri(st,vertices[ri][j],vertices[ri+1][j],vertices[ri+1][k],normals[ri][j],normals[ri+1][j],normals[ri+1][k],color)
			_tri(st,vertices[ri][j],vertices[ri+1][k],vertices[ri][k],normals[ri][j],normals[ri+1][k],normals[ri][k],color)
	for top in [false,true]:
		var index := rings.size()-1 if top else 0
		var ring: Vector4 = rings[index]
		var center := pos+basis*Vector3(0,ring.x,ring.w)
		var normal := basis*(Vector3.UP if top else Vector3.DOWN)
		for j in sides: _tri(st,center,vertices[index][j],vertices[index][(j+1)%sides],normal,normal,normal,color)

## A panel is an extruded authored polygon, not a rounded box decal.
static func _plate(st: SurfaceTool, points: Array, z: float, depth: float, color: Color, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> void:
	var basis := Basis.from_euler(rot)
	var center := Vector2.ZERO
	for p: Vector2 in points: center += p
	center /= float(points.size())
	for side in [-1.0,1.0]:
		var normal := basis*Vector3(0,0,side)
		var middle := pos+basis*Vector3(center.x,center.y,z+depth*.5*side)
		for i in points.size():
			var p: Vector2 = points[i]; var q: Vector2 = points[(i+1)%points.size()]
			_tri(st,middle,pos+basis*Vector3(p.x,p.y,z+depth*.5*side),pos+basis*Vector3(q.x,q.y,z+depth*.5*side),normal,normal,normal,color)
	for i in points.size():
		var p: Vector2=points[i];var q: Vector2=points[(i+1)%points.size()]
		var mid := (p+q)*.5-center
		var n := basis*Vector3(mid.x,mid.y,0).normalized()
		var a:=pos+basis*Vector3(p.x,p.y,z-depth*.5); var b:=pos+basis*Vector3(q.x,q.y,z-depth*.5)
		var c:=pos+basis*Vector3(q.x,q.y,z+depth*.5); var d:=pos+basis*Vector3(p.x,p.y,z+depth*.5)
		_tri(st,a,b,c,n,n,n,color);_tri(st,a,c,d,n,n,n,color)

## Folded three-dimensional pointed petal with a raised center ridge and sharp tip.
static func _petal(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var basis:=Basis.from_euler(rot)
	var profiles := [Vector3(0,.22,0),Vector3(.28,.5,.45),Vector3(.67,.34,.85),Vector3(1,.002,1)]
	var rows: Array=[]
	for p: Vector3 in profiles:
		var y:=p.z*size.y
		rows.append([pos+basis*Vector3(-p.y*size.x,y,p.x*size.z),pos+basis*Vector3(0,y+size.y*.24,p.x*size.z),pos+basis*Vector3(p.y*size.x,y,p.x*size.z),pos+basis*Vector3(0,y-size.y*.12,p.x*size.z)])
	for i in rows.size()-1:
		for j in 4:
			var k: int=(j+1)%4
			var a: Vector3=rows[i][j];var b:Vector3=rows[i+1][j];var c:Vector3=rows[i+1][k];var d:Vector3=rows[i][k]
			var n:=-(b-a).cross(c-a).normalized()
			if n.length()<.5: n=Vector3.UP
			var shade:=color if j<2 else color.darkened(.16)
			_tri(st,a,b,c,n,n,n,shade);_tri(st,a,c,d,n,n,n,shade)

static func _helmet_back(st: SurfaceTool) -> void:
	var rings := [Vector4(-.18,.135,.14,.035),Vector4(-.08,.215,.19,.015),Vector4(.08,.243,.211,0),Vector4(.20,.205,.18,0),Vector4(.27,.10,.10,0)]
	for ri in rings.size()-1:
		var r:Vector4=rings[ri];var q:Vector4=rings[ri+1]
		for i in 14:
			var a:=PI*float(i)/14;var b:=PI*float(i+1)/14
			var v0:=Vector3(cos(a)*r.y,r.x,sin(a)*r.z+r.w)
			var v1:=Vector3(cos(a)*q.y,q.x,sin(a)*q.z+q.w)
			var v2:=Vector3(cos(b)*q.y,q.x,sin(b)*q.z+q.w)
			var v3:=Vector3(cos(b)*r.y,r.x,sin(b)*r.z+r.w)
			var n0:=Vector3(cos(a),.1,sin(a)).normalized();var n1:=Vector3(cos(b),.1,sin(b)).normalized()
			_tri(st,v0,v1,v2,n0,n0,n1,CREAM);_tri(st,v0,v2,v3,n0,n1,n1,CREAM)

static func _component(parent: Node3D, st: SurfaceTool, name: String, material_kind: String, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var n:=_node(_finish(st,material_kind),name,pos)
	parent.add_child(n)
	return n

static func make_gardener(team: int, variant: int = 0) -> Node3D:
	# Compatibility entry point. Animal art only: never silently fall back to a human.
	var species: String=["rabbit","fox","otter","raccoon"][posmod(variant,4)]
	return make_animal(species,team,variant)

static func make_animal(species: String, team: int, variant: int = 0) -> Node3D:
	assert(species in ["rabbit","fox","otter","raccoon"],"Unknown animal species")
	var color_name := "blue" if team == 0 else "orange"
	var path := "res://modules/bloom_skirmish/art/models/animals/rigged/%s/%s_%s_rigged.glb" % [species,species,color_name]
	if not ResourceLoader.exists(path):
		push_error("Requested animal asset is not ready/imported (no fallback): " + path)
		return null
	if not _animal_scenes.has(path): _animal_scenes[path] = load(path)
	var scene: PackedScene = _animal_scenes[path]
	if scene == null: return null
	var imported := scene.instantiate() as Node3D
	var rig: Node3D = imported
	# Preserve the imported scene/animation track hierarchy. Only the independent,
	# unanimated weapon is exposed directly at the public actor root.
	var skeletons := imported.find_children("*","Skeleton3D",true,false)
	var players := imported.find_children("*","AnimationPlayer",true,false)
	if skeletons.is_empty() or players.is_empty():
		push_error("Rigged animal must contain a real Skeleton3D and bone animation: " + path)
		imported.free()
		return null
	var skeleton := skeletons[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	var weapon := imported.find_child("Weapon",true,false) as Node3D
	assert(weapon != null and weapon.has_node("Muzzle"),"Rigged animal weapon anchors missing")
	if weapon.get_parent() != rig:
		var rest := _transform_relative_to(weapon,rig)
		_clear_scene_owner(weapon)
		weapon.get_parent().remove_child(weapon)
		rig.add_child(weapon)
		weapon.transform = rest
	weapon.set_meta("rest",weapon.position)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.set_process(false)
	player.set_physics_process(false)
	player.stop()
	rig.set_meta("skeleton",skeleton)
	rig.set_meta("animation_player",player)
	rig.set_meta("skinned",true)
	rig.set_meta("visual_generation","cartoon-animal-skinned-v1")
	_enable_imported_vertex_colors(rig)
	rig.name = "Bloom_%s_%s" % [species,color_name]
	rig.set_meta("team",team)
	rig.set_meta("variant",variant)
	rig.set_meta("species",species)
	rig.set_meta("asset_path",path)
	return rig

static func _clear_scene_owner(node: Node) -> void:
	node.owner = null
	for child in node.get_children(): _clear_scene_owner(child)

static func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent != ancestor:
		assert(parent is Node3D,"Animal hierarchy must reach the supplied root")
		result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

static func apply_gardener_aim_pitch(rig: Node3D, pitch: float) -> void:
	# Animal-specific articulated nozzle: rear receiver and short-paw grip remain
	# still. The nozzle pivot and independent physical Muzzle share one point.
	var nozzle := rig.get_node_or_null("Weapon/AimNozzle") as Node3D
	if nozzle:
		var recoil := float(rig.get_meta("nozzle_recoil",0.0))
		nozzle.rotation.x = pitch + recoil
		rig.set_meta("aim_pitch",pitch)
		if rig.has_meta("head_base_rotation"):
			var skeleton: Skeleton3D = rig.get_meta("skeleton")
			var head: int = rig.get_meta("head_bone")
			var base: Quaternion = rig.get_meta("head_base_rotation")
			var clip_basis: Basis = rig.get_meta("head_clip_basis")
			# Rotate only the head branch, from the freshly sampled clip pose.
			# Cached base makes repeated aim calls non-accumulating; chest/arms stay put.
			var axis := (clip_basis.inverse() * Vector3.RIGHT).normalized()
			skeleton.set_bone_pose_rotation(head,(base * Quaternion(axis,pitch * 0.25)).normalized())
	elif bool(rig.get_meta("skinned",false)):
		# Transitional rig asset missing the agreed joint must fail visibly in QA,
		# never rotate the entire weapon and pull the animal's paws apart.
		rig.set_meta("aim_joint_missing",true)

static func _animate_skinned(rig: Node3D, time: float, speed: float, shooting: bool, dash: bool) -> void:
	var player: AnimationPlayer = rig.get_meta("animation_player")
	var clip := "dash" if dash else ("run" if speed > 0.08 else ("spray" if shooting else "idle"))
	var rate := clampf(speed * 2.6,0.25,2.6) if clip == "run" else 1.0
	rig.set_meta("locomotion_playback_rate",rate)
	var sample_time := time * rate
	if rig.has_meta("last_evaluated_time"):
		var previous_time := float(rig.get_meta("last_evaluated_time"))
		if time >= previous_time and str(rig.get_meta("locomotion_clip","")) == clip:
			sample_time = float(rig.get_meta("locomotion_phase",0.0)) + (time - previous_time) * rate
		else:
			sample_time = 0.0
	rig.set_meta("locomotion_clip",clip)
	rig.set_meta("locomotion_phase",sample_time)
	var one_shot := false
	if rig.has_meta("reaction"):
		var reaction: Dictionary = rig.get_meta("reaction")
		var age := maxf(0.0,time - float(reaction.start))
		var reaction_clip := str(reaction.kind)
		if reaction_clip == "victory": reaction_clip = "celebration"
		elif reaction_clip == "pod_placed": reaction_clip = "pod"
		if player.has_animation(reaction_clip):
			var duration := player.get_animation(reaction_clip).length
			if age < duration or reaction_clip in ["defeat","celebration"]:
				clip = reaction_clip
				sample_time = age
				one_shot = reaction_clip != "celebration"
			else:
				rig.remove_meta("reaction")
	assert(player.has_animation(clip),"Required animal bone clip missing: " + clip)
	var animation := player.get_animation(clip)
	var at := minf(sample_time,maxf(0.0,animation.length - 0.00001)) if one_shot else fposmod(sample_time,maxf(animation.length,0.001))
	# Explicit evaluation is deterministic and pause-safe. No automatic advance,
	# wall clock, or accumulated IK correction is used. Locomotion phase uses only
	# last_evaluated_time, never the event-writable animation_clock.
	if player.current_animation != clip: player.play(clip,0.0)
	player.seek(at,true)
	var skeleton: Skeleton3D = rig.get_meta("skeleton")
	var head := skeleton.find_bone("Head")
	if head >= 0:
		rig.set_meta("head_bone",head)
		rig.set_meta("head_base_rotation",skeleton.get_bone_pose_rotation(head))
		rig.set_meta("head_clip_basis",skeleton.get_bone_global_pose(head).basis)
	rig.set_meta("animation_clip",clip)
	rig.set_meta("last_evaluated_time",time)
	rig.set_meta("nozzle_recoil",-absf(sin(time * 38.0)) * 0.035 if shooting else 0.0)
	apply_gardener_aim_pitch(rig,float(rig.get_meta("aim_pitch",0.0)))

static func _enable_imported_vertex_colors(node: Node) -> void:
	# Godot 4.7.2 GLB import can retain COLOR_0 but leave material usage disabled.
	# glTF vertex colors are already linear: do not apply a second sRGB decode.
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_COLOR]!=null and not arrays[Mesh.ARRAY_COLOR].is_empty():
				var mat:=node.mesh.surface_get_material(surface) as StandardMaterial3D
				if mat:
					mat.vertex_color_use_as_albedo=true
					mat.vertex_color_is_srgb=false
	for child in node.get_children():_enable_imported_vertex_colors(child)

static func react_gardener(rig: Node3D, kind: String, strength: float = 1.0) -> void:
	if kind in ["clear","reset"]:
		if rig.has_meta("reaction"): rig.remove_meta("reaction")
		return
	var duration := .34 if kind == "hit" else (.58 if kind == "pod" else 2.2)
	rig.set_meta("reaction",{"kind":kind,"start":float(rig.get_meta("animation_clock",0.0)),"duration":duration,"strength":clampf(strength,0,1)})

static func animate_gardener(rig: Node3D, time: float, speed: float, shooting: bool = false, dash: bool = false) -> void:
	rig.set_meta("animation_clock",time)
	_animate_skinned(rig,time,speed,shooting,dash)

static func _flower(st: SurfaceTool, center: Vector3, radius: float, col: Color, petals: int = 5) -> void:
	# A flower is sub-pixel-sized at gameplay zoom: smooth shaded low-poly petals,
	# not thousands of redundant sphere triangles per blossom burst.
	for i in petals:
		var a := TAU*float(i)/float(petals)
		_shape(st,"bud",center+Vector3(cos(a)*radius*0.43,0,sin(a)*radius*0.43),Vector3(radius*0.60,radius*0.20,radius*0.91),col,Vector3(0,PI/2.0-a,0))
	_shape(st,"bud",center+Vector3(0,radius*0.085,0),Vector3(radius*0.50,radius*0.23,radius*0.50),GOLD)
	_shape(st,"bud",center+Vector3(-radius*0.05,radius*0.20,-radius*0.03),Vector3.ONE*radius*0.075,CREAM)

static func _sprig(st: SurfaceTool, base: Vector3, height: float, col: Color = LEAF) -> void:
	_tube(st,base,base+Vector3(0,height,0),0.025,col.darkened(0.1))
	_leaf(st,base+Vector3(-height*0.18,height*0.58,0),Vector3(height*0.52,0.075,height*0.23),col,Vector3(0,0,-0.42))
	_leaf(st,base+Vector3(height*0.18,height*0.78,0.025),Vector3(height*0.50,0.07,height*0.25),col.lightened(0.1),Vector3(0,0,0.38))

static func make_prop(kind: String, team: int = 0) -> Node3D:
	var key := "prop_%s_%d" % [kind,team]
	if _cache.has(key): return _node(_cache[key],kind)
	var st := _begin()
	var col := team_color(team)
	match kind:
		"pot", "planter", "pot_simple":
			# A deep ceramic nursery vessel, not a top-down flower platter.
			_shape(st,"cone",Vector3(0,.43,0),Vector3(1.22,.82,1.22),Color("e9c49c"))
			_shape(st,"ring",Vector3(0,.84,0),Vector3(1.30,1.2,1.30),CREAM)
			_shape(st,"cylinder",Vector3(0,.82,0),Vector3(1.05,.035,1.05),SOIL)
			_shape(st,"ring",Vector3(0,.105,0),Vector3(.84,.8,.84),Color("be9576"))
			# Low sprouting flowers let first-person-level projectiles read cleanly.
			var flower_count := 1 if kind == "pot_simple" else 5
			for i in flower_count:
				var a := float(i)*TAU/float(flower_count)
				var radius := 0.0 if kind == "pot_simple" else .29
				var p := Vector3(cos(a)*radius,.84,sin(a)*radius)
				_sprig(st,p,.16+.02*(i%2),LEAF)
				_flower(st,p+Vector3(0,.18,0),.20,col.lightened(.2))
			var badge_angles := [0.0,PI] if kind == "pot_simple" else [0.0,PI/2.0,PI,PI*1.5]
			for a: float in badge_angles:
				var badge_pos := Vector3(sin(a)*.555,.43,cos(a)*.555)
				_tiny(st,badge_pos,Vector3(.23,.24,.035),col,Vector3(0,a,0))
				var side := Vector3(cos(a),0,-sin(a))
				_tube(st,badge_pos-side*.05+Vector3(0,-.065,0),badge_pos+side*.05+Vector3(0,.065,0),.012,CREAM)
		"crate":
			_round(st,Vector3(0,.42,0),Vector3(1.15,.82,1.05),.06,Color("aa7454"))
			for z in [-.52,.52]:
				for y in [.17,.41,.65]:
					_round(st,Vector3(0,y,z),Vector3(1.20,.21,.08),.025,WOOD)
			for x in [-.53,.53]:
				_round(st,Vector3(x,.44,0),Vector3(.11,.90,1.10),.027,Color("eac08b"))
				for z in [-.53,.53]:
					for y in [.15,.72]:
						_tiny(st,Vector3(x,y,z),Vector3.ONE*.045,Color("805c4b"))
			_shape(st,"cylinder",Vector3(0,.85,0),Vector3(.90,.05,.82),SOIL)
			for x in [-.28,.25]:
				_sprig(st,Vector3(x,.87,0),.21,LEAF_LIGHT)
			for z in [-.577,.577]:
				_round(st,Vector3(0,.43,z),Vector3(.40,.26,.025),.012,CREAM)
				_tiny(st,Vector3(0,.43,z*1.025),Vector3(.14,.16,.018),col)
		"fence":
			for x in [-0.67,0.67]:
				_round(st,Vector3(x,0.36,0),Vector3(0.16,0.72,0.17),0.055,CREAM)
				_ball(st,Vector3(x,0.72,0),Vector3(0.23,0.14,0.23),GOLD)
			for y in [0.27,0.51]:
				_round(st,Vector3(0,y,0),Vector3(1.38,0.12,0.13),0.035,Color("f4ddb6"))
			for x in [-0.34,0,0.34]:
				_round(st,Vector3(x,0.39,0),Vector3(0.11,0.45,0.11),0.035,CREAM)
		"chime":
			_round(st,Vector3(0,0.04,0),Vector3(0.57,0.08,0.41),0.04,WOOD)
			_tube(st,Vector3(0,0.05,0),Vector3(0,1.15,0),0.048,WOOD)
			_tube(st,Vector3(0,1.15,0),Vector3(0.48,1.15,0),0.042,WOOD)
			_ball(st,Vector3(0.39,0.95,0),Vector3(0.39,0.22,0.35),col)
			for i in 3:
				var x := 0.26 + float(i)*0.13
				_tube(st,Vector3(x,0.94,0),Vector3(x,0.57-0.06*(i%2),0),0.012,CREAM)
				_shape(st,"cylinder",Vector3(x,0.65-0.06*(i%2),0),Vector3(0.047,0.20,0.047),GOLD)
			_leaf(st,Vector3(0.39,0.43,0),Vector3(0.14,0.23,0.035),col)
		"flower":
			_sprig(st,Vector3.ZERO,0.30)
			_flower(st,Vector3(0,0.32,0),0.28,col)
		"seed_pod", "pod":
			_ball(st,Vector3(0,0.22,0),Vector3(0.44,0.42,0.44),col)
			for i in 6:
				var a := float(i)*TAU/6.0
				_leaf(st,Vector3(cos(a)*0.13,0.33,sin(a)*0.13),Vector3(0.11,0.065,0.26),LEAF_LIGHT,Vector3(0,PI/2-a,0))
			_tube(st,Vector3(0,0.39,0),Vector3(0.035,0.54,0),0.032,LEAF)
			_tiny(st,Vector3(0.035,0.55,0),Vector3.ONE*0.105,GOLD)
			for x in [-0.07,0.07]:
				_tiny(st,Vector3(x,0.22,-0.208),Vector3(0.033,0.049,0.017),INK)
		"mushroom":
			_shape(st,"cone",Vector3(0,0.13,0),Vector3(0.12,0.25,0.12),CREAM)
			_ball(st,Vector3(0,0.27,0),Vector3(0.40,0.20,0.36),col)
			for i in 3:
				_tiny(st,Vector3(-0.1+i*0.10,0.35,-0.04),Vector3.ONE*0.055,CREAM)
		"stone":
			_ball(st,Vector3(0,0.09,0),Vector3(0.48,0.18,0.35),Color("c8c8b0"))
		_:
			_sprig(st,Vector3.ZERO,0.35)
	var mesh := _finish(st)
	_cache[key] = mesh
	return _node(mesh,kind)

static func make_seed(team: int) -> Node3D:
	var key := "seed_%d" % team
	if not _cache.has(key):
		var st := _begin()
		_ball(st,Vector3.ZERO,Vector3(0.16,0.16,0.28),team_color(team).lightened(0.15))
		_tiny(st,Vector3(-0.028,0.04,-0.065),Vector3(0.04,0.035,0.09),CREAM)
		_leaf(st,Vector3(0.055,0,0.08),Vector3(0.14,0.04,0.13),LEAF_LIGHT,Vector3(0,-0.5,0))
		_cache[key] = _finish(st)
	return _node(_cache[key],"Seed")

## Low blossoming patch: safe to pulse/scale as one node, no unbounded particles.
static func make_bloom(team: int, radius: float = 1.0) -> Node3D:
	var key := "bloom_%d" % team
	if not _cache.has(key):
		var st := _begin()
		for i in 7:
			var a := float(i)*2.399963
			var r := 0.0 if i == 0 else 0.44 + 0.17*float(i%2)
			var p := Vector3(cos(a)*r,0.055+float(i%3)*0.025,sin(a)*r)
			_leaf(st,p,Vector3(0.49,0.065,0.27),LEAF_LIGHT,Vector3(0,a,0),false,true)
			_flower(st,p+Vector3(0,0.06,0),0.28 if i == 0 else 0.19,team_color(team).lightened(float(i%2)*0.18))
		_cache[key] = _finish(st)
	var root := _node(_cache[key],"BloomPatch")
	root.scale = Vector3.ONE*radius
	return root

## Airy greenhouse frames live outside collision bounds and never cover the arena.
static func _greenhouse_arch(st: SurfaceTool, center: Vector3, yaw: float, width: float = 7.5) -> void:
	var basis := Basis(Vector3.UP,yaw)
	var iron := Color("9bbdb0")
	for side in [-1.0,1.0]:
		var base := center + basis*Vector3(side*width*.5,0,0)
		_round(st,base+Vector3(0,.20,0),Vector3(.32,.40,.32),.055,CREAM)
		_tube(st,base+Vector3(0,.35,0),base+Vector3(0,2.25,0),.075,iron)
	for i in 12:
		var a := PI*float(i)/12.0
		var b := PI*float(i+1)/12.0
		var p := center+basis*Vector3(cos(a)*width*.5,2.25+sin(a)*1.75,0)
		var q := center+basis*Vector3(cos(b)*width*.5,2.25+sin(b)*1.75,0)
		_tube(st,p,q,.075,iron)
	_tube(st,center+basis*Vector3(-width*.44,2.45,0),center+basis*Vector3(width*.44,2.45,0),.027,Color("cbb38b"))
	for i in 5:
		var local := Vector3(-width*.32+float(i)*width*.16,2.25,0)
		_leaf(st,center+basis*local,Vector3(.26,.38,.065),[TEAL.lightened(.35),GOLD,CORAL.lightened(.35)][i%3],Vector3(0,yaw,-.15+float(i%2)*.3))
	_ball(st,center+Vector3(0,4.03,0),Vector3(.22,.22,.22),GOLD)

static func _place(parent: Node3D, item: Node3D, position: Vector3, yaw: float = 0.0, size: Vector3 = Vector3.ONE) -> void:
	item.position = position
	item.rotation.y = yaw
	item.scale = size
	parent.add_child(item)

## Visual-only floating nursery. Collision + territory plane are owned by gameplay.
## Rect2 obstacles are exact X/Z footprints. Dictionaries accept rect / bounds.
static func make_arena(obstacles: Array, spawn_zones: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "FloatingNursery"
	var st := _begin()
	# Opaque deep diorama foundation, rolled ceramic rim, pale planting tiles.
	_round(st,Vector3(16,-0.54,12),Vector3(46.0,1.03,38.0),0.42,Color("eac59d"))
	_round(st,Vector3(16,-1.09,12),Vector3(44.6,0.52,36.6),0.24,Color("b98c6b"))
	_round(st,Vector3(16,-1.37,12),Vector3(42.4,0.24,34.4),0.12,Color("916d5d"))
	for z in [-0.32,24.32]:
		_round(st,Vector3(16,0.045,z),Vector3(33.05,0.23,0.60),0.105,Color("f8e6c6"))
		for x in range(0,33,2):
			_round(st,Vector3(float(x),0.17,z),Vector3(0.055,0.012,0.51),0.005,Color("d6b994"))
	for x in [-0.32,32.32]:
		_round(st,Vector3(x,0.045,12),Vector3(0.60,0.23,24.2),0.105,Color("f8e6c6"))
		for z in range(0,25,2):
			_round(st,Vector3(x,0.17,float(z)),Vector3(0.51,0.012,0.055),0.005,Color("d6b994"))
	# Protected nursery mats are intentionally pale, never mistaken for painted turf.
	for team in spawn_zones.size():
		var zone: Variant = spawn_zones[team]
		if not zone is Rect2: continue
		var rect: Rect2 = zone
		var c := rect.get_center()
		var color := team_color(team)
		_round(st,Vector3(c.x,0.022,c.y),Vector3(rect.size.x-0.10,0.06,rect.size.y-0.10),0.025,color.lightened(0.82))
		# A sewn dashed edge says "fabric home mat", not capturable territory.
		var inset := 0.22
		for side in [-1.0,1.0]:
			for step in 9:
				var z := rect.position.y+0.35+float(step)*(rect.size.y-0.70)/8.0
				_round(st,Vector3(c.x+side*(rect.size.x*.5-inset),0.062,z),Vector3(0.055,0.018,0.20),0.008,color.lightened(.24))
			for step in 6:
				var x := rect.position.x+0.35+float(step)*(rect.size.x-0.70)/5.0
				_round(st,Vector3(x,0.062,c.y+side*(rect.size.y*.5-inset)),Vector3(0.20,0.018,0.055),0.008,color.lightened(.24))
		var petals := 3 if team == 0 else 5
		for i in petals:
			var angle := TAU*float(i)/float(petals)
			var center := Vector3(c.x+cos(angle)*0.42,0.064,c.y+sin(angle)*0.42)
			_shape(st,"ball",center,Vector3(.68,.025,.78 if team == 0 else 1.05),color.lightened(.30),Vector3(0,PI/2-angle,0))
		if team == 1:
			_shape(st,"cylinder",Vector3(c.x,0.078,c.y),Vector3(.43,.012,.43),GOLD.lightened(.20))
		else:
			_round(st,Vector3(c.x,0.078,c.y+.55),Vector3(.10,.012,.45),0.005,color.lightened(.24),Vector3(0,-.25,0))
	# Continuous low rails make the unchanged playable boundary readable in 3D.
	# The greenhouse service terrace outside these rails is scenery, not walkable turf.
	for y in [.28,.55]:
		for z in [-.48,24.48]:
			_tube(st,Vector3(-.48,y,z),Vector3(32.48,y,z),.047,Color("e8d9b6"))
		for x in [-.48,32.48]:
			_tube(st,Vector3(x,y,-.48),Vector3(x,y,24.48),.047,Color("e8d9b6"))
	for x in range(0,33,4):
		_round(st,Vector3(float(x),.34,24.48),Vector3(.15,.68,.15),.035,CREAM)
		_ball(st,Vector3(float(x),.71,24.48),Vector3(.22,.13,.22),GOLD)
	# Third-person skyline: open greenhouse arches, never a camera-obscuring roof.
	# All frame planes are >=6.5m outside the field, beyond the 5m chase boom.
	for x in [7.0,25.0]:
		_greenhouse_arch(st,Vector3(x,-.15,-6.5),0)
		_greenhouse_arch(st,Vector3(x,-.15,30.5),PI)
	_greenhouse_arch(st,Vector3(-6.5,-.15,12),PI/2.0,8.5)
	_greenhouse_arch(st,Vector3(38.5,-.15,12),-PI/2.0,8.5)
	# Hand-shaped soft cloud clusters provide depth from any chase-camera heading.
	for cloud: Vector3 in [Vector3(-10,6,-7),Vector3(14,7,-12),Vector3(43,6,-3),Vector3(44,7,28),Vector3(15,7.5,38),Vector3(-12,6.5,26)]:
		_ball(st,cloud,Vector3(5.5,1.15,2.2),Color("e8efe6"))
		_ball(st,cloud+Vector3(-1.3,.5,.05),Vector3(2.4,1.7,2.0),Color("f5f4e9"))
		_ball(st,cloud+Vector3(.5,.7,0),Vector3(3.0,2.1,2.1),Color("f5f4e9"))
		_ball(st,cloud+Vector3(2.0,.25,.1),Vector3(1.8,1.2,1.7),Color("f5f4e9"))
	root.add_child(_node(_finish(st),"NurseryDioramaBase"))
	# Sparse edge dressing keeps center and team silhouettes unobscured.
	for i in 9:
		var x := 2.0+float(i)*3.5
		_place(root,make_prop("fence"),Vector3(x,0,-0.48))
		if i%2 == 0:
			_place(root,make_prop("flower",i%2),Vector3(x+0.8,0,-0.30),0,Vector3.ONE*0.8)
	for i in 7:
		var z := 1.5+float(i)*3.5
		_place(root,make_prop("fence"),Vector3(-0.48,0,z),PI/2)
		_place(root,make_prop("fence"),Vector3(32.48,0,z),PI/2)
	for p: Vector3 in [Vector3(-0.55,0,-0.55),Vector3(32.55,0,-0.55),Vector3(-0.55,0,24.55),Vector3(32.55,0,24.55)]:
		_place(root,make_prop("pot",0 if p.x < 16 else 1),p,0,Vector3.ONE*1.2)
	for x in [5.0,27.0]:
		_place(root,make_prop("chime",0 if x < 16 else 1),Vector3(x,0,-0.55),PI/2)
	# Small workbench gardens on the exterior service terrace ground the arches.
	for x in [3.4,10.6,21.4,28.6]:
		_place(root,make_prop("pot_simple",0 if x < 16 else 1),Vector3(x,-.03,-2.8),0,Vector3(.9,.9,.9))
		_place(root,make_prop("pot_simple",0 if x < 16 else 1),Vector3(x,-.03,26.8),0,Vector3(.9,.9,.9))
	for i in obstacles.size():
		var data: Variant = obstacles[i]
		var rect := Rect2()
		if data is Rect2: rect = data
		elif data is Dictionary: rect = data.get("rect",data.get("bounds",Rect2()))
		if rect.size.x <= 0 or rect.size.y <= 0: continue
		var center := rect.get_center()
		if i%3 == 0:
			# Do NOT stretch one round pot across a 5m collider: that reads as a flat
			# platter at shoulder height. Fill a low rectangular base with separate
			# proper ceramic vessels, retaining the exact original collision footprint.
			var base_st := _begin()
			_round(base_st,Vector3(center.x,.075,center.y),Vector3(rect.size.x,.15,rect.size.y),.06,Color("ccad85"))
			root.add_child(_node(_finish(base_st),"PlanterIslandBase"))
			var cols := maxi(1,roundi(rect.size.x/1.75))
			var rows := maxi(1,roundi(rect.size.y/1.85))
			var cell := rect.size/Vector2(cols,rows)
			var diameter := minf(cell.x,cell.y)*.88
			for row in rows:
				for col in cols:
					var p := rect.position+Vector2(col+.5,row+.5)*cell
					_place(root,make_prop("pot_simple",i%2),Vector3(p.x,.02,p.y),float(row+col)*PI/2,Vector3(diameter/1.3,1.04,diameter/1.3))
		else:
			var prop := make_prop("crate",i%2)
			var scale_v := Vector3(rect.size.x/1.20,1.05,rect.size.y/1.10)
			_place(root,prop,Vector3(center.x,0,center.y),0,scale_v)
	# Spawn mats are decorative; runtime owns protection and gameplay indicators.
	root.set_meta("spawn_zone_count",spawn_zones.size())
	return root
