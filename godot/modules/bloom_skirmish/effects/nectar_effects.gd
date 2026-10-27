extends Node3D
## Original finite viscous nectar ribbons and inertial contact splashes.
## Rendering only: no paint state, collision, score or gameplay RNG is mutated.
## Runtime owns the clock. sync_projectiles(..., 0) freezes all motion on pause.
const LiquidShader = preload("nectar.gdshader")
const MAX_PROJECTILES := 64
const MAX_SPLASHES := 24
const MAX_DROPLETS := 160
const MAX_INSTANCES_PER_TEAM := 256
const RING_SIDES := 10
const TRAIL_STEPS := 10
const COLORS := [Color("2f62ff"), Color("ff8a1f")]
const FOAM := [Color("dce8ff"), Color("fff0da")]
var _clock := 0.0
var _splashes: Array[Dictionary] = []
var _droplets: Array[Dictionary] = []
var _stream_nodes: Array[MeshInstance3D] = []
var _bead_nodes: Array[MultiMeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _initialized := false
var _last_shots: Dictionary = {}
var active_projectile_count := 0
var active_droplet_count := 0
var active_splash_count := 0

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	if _initialized: return
	_initialized = true
	name = "ViscousNectar"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0; sphere.height = 2.0
	sphere.radial_segments = 12; sphere.rings = 6
	for team in 2:
		var material := ShaderMaterial.new()
		material.shader = LiquidShader
		material.set_shader_parameter("nectar_color", COLORS[team])
		material.set_shader_parameter("foam_color", FOAM[team])
		_materials.append(material)
		var stream := MeshInstance3D.new()
		stream.name = "NectarRibbonsTeam%d" % team
		stream.material_override = material
		stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stream); _stream_nodes.append(stream)
		var bead := MultiMeshInstance3D.new()
		bead.name = "BallisticDropletsTeam%d" % team
		bead.multimesh = MultiMesh.new()
		bead.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		bead.multimesh.mesh = sphere
		bead.multimesh.instance_count = MAX_INSTANCES_PER_TEAM
		bead.multimesh.visible_instance_count = 0
		bead.material_override = material
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bead); _bead_nodes.append(bead)

func reset() -> void:
	_initialize()
	_clock = 0.0; _splashes.clear(); _droplets.clear(); _last_shots.clear()
	active_projectile_count = 0; active_droplet_count = 0; active_splash_count = 0
	for stream in _stream_nodes: stream.mesh = null
	for bead in _bead_nodes: bead.multimesh.visible_instance_count = 0

func shot(event: Dictionary) -> void:
	# IDs are bounded to the four actors, not an ever-growing projectile history.
	_last_shots[int(event.get("id", 0))] = _clock

func impact(event: Dictionary) -> void:
	_initialize()
	var team := clampi(int(event.get("team", 0)), 0, 1)
	var pos2: Vector2 = event.get("pos", Vector2.ZERO)
	var pos: Vector3 = event.get("world_pos", Vector3(pos2.x, 0.055, pos2.y))
	var normal: Vector3 = event.get("normal", Vector3.UP)
	if normal.length_squared() < 0.01: normal = Vector3.UP
	normal = normal.normalized()
	var radius := clampf(float(event.get("radius", .88)), .15, 3.2)
	var seed_value := int(event.get("seed", event.get("shot_id", 1)))
	var phase := float(seed_value % 97) * .731
	if _splashes.size() >= MAX_SPLASHES: _splashes.pop_front()
	_splashes.append({"pos": pos + normal*.055, "normal": normal, "team": team,
		"radius": minf(radius, 1.7), "age": 0.0, "life": .46,
		"phase": phase, "ground": str(event.get("surface", "ground")) == "ground"})
	var tangent := normal.cross(Vector3.FORWARD).normalized()
	if tangent.length_squared() < .1: tangent = normal.cross(Vector3.RIGHT).normalized()
	var bitangent := normal.cross(tangent).normalized()
	var count := 12 if radius > 1.0 else 7
	for i in count:
		if _droplets.size() >= MAX_DROPLETS: _droplets.pop_front()
		var a := phase + TAU * float(i) / float(count)
		var r := .75 + .25*sin(float(i)*3.7+phase)
		var radial := tangent*cos(a) + bitangent*sin(a)
		var velocity := radial*(1.8+r*.9)*minf(radius,1.3) + normal*(2.0+r*2.2)
		_droplets.append({"pos": pos+normal*.06+radial*.08, "velocity": velocity,
			"team": team, "age": 0.0, "life": .32+r*.20, "radius": .038+r*.036})

func sync_projectiles(projectiles: Array, _actors: Array, dt: float) -> void:
	_initialize()
	dt = clampf(dt, 0.0, .15)
	_clock += dt
	for i in range(_droplets.size()-1, -1, -1):
		var drop: Dictionary = _droplets[i]
		drop.age = float(drop.age)+dt
		drop.velocity = Vector3(drop.velocity) + Vector3.DOWN*14.0*dt
		drop.pos = Vector3(drop.pos) + Vector3(drop.velocity)*dt
		if float(drop.age) >= float(drop.life) or Vector3(drop.pos).y < .035:
			_droplets.remove_at(i)
	for i in range(_splashes.size()-1, -1, -1):
		_splashes[i].age = float(_splashes[i].age)+dt
		if float(_splashes[i].age) >= float(_splashes[i].life): _splashes.remove_at(i)
	var surfaces: Array[Dictionary] = [_surface(), _surface()]
	var bead_counts: Array[int] = [0, 0]
	active_projectile_count = mini(projectiles.size(), MAX_PROJECTILES)
	for i in active_projectile_count:
		var projectile: Dictionary = projectiles[i]
		var team := clampi(int(projectile.get("team", 0)), 0, 1)
		var p2: Vector2 = projectile.get("pos", Vector2.ZERO)
		var head: Vector3 = projectile.get("world_pos", Vector3(p2.x,.85,p2.y))
		var dir2: Vector2 = projectile.get("dir", Vector2.RIGHT)
		var velocity: Vector3 = projectile.get("velocity", Vector3(dir2.x*19.0,0.0,dir2.y*19.0))
		var horizontal_speed := maxf(Vector2(velocity.x,velocity.z).length(), .1)
		var travelled := float(projectile.get("traveled", 1.8))
		var age := float(projectile.get("age", travelled/horizontal_speed))
		var tail_time := minf(.105, maxf(.0, age))
		var gravity := float(projectile.get("gravity", 9.8))
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		var phase := float(int(projectile.get("id", 0))%23)*.67
		for step in TRAIL_STEPS+1:
			var u := float(step)/float(TRAIL_STEPS)
			var back := tail_time*(1.0-u)
			var p := head-velocity*back+Vector3.DOWN*(.5*gravity*back*back)
			# Physical parabola carries the strand; tiny lateral necking is surface tension.
			var sideways := Vector3(-dir2.y,0.0,dir2.x)
			p += sideways*sin(u*TAU*1.4+phase+_clock*12.0)*.017*sin(u*PI)
			points.append(p)
			var neck := .83+.17*sin(u*TAU*1.5-phase+_clock*20.0)
			var taper := smoothstep(0.0,.15,u)*lerpf(1.0,.78,smoothstep(.78,1.0,u))
			radii.append(maxf(.009,(.112+.026*sin(u*PI))*neck*taper))
		if tail_time > .001: _append_tube(surfaces[team],points,radii)
		_write_bead(team,bead_counts,head,velocity,.126, .174)
		# One detached bead beside the thinning tail gives breakup without confetti.
		if age>.06 and (int(projectile.get("id",0))%3)==0:
			var back := minf(age,.073)
			var side := Vector3(-dir2.y,.0,dir2.x)
			var secondary := head-velocity*back+Vector3.DOWN*(.5*gravity*back*back)+side*.14
			_write_bead(team,bead_counts,secondary,velocity,.043,.085)
	for drop in _droplets:
		var fraction := float(drop.age)/float(drop.life)
		var radius := float(drop.radius)*smoothstep(1.0,.65,fraction)
		_write_bead(int(drop.team),bead_counts,Vector3(drop.pos),Vector3(drop.velocity),radius,radius*(1.3+minf(Vector3(drop.velocity).length()*.1,.7)))
	for splash in _splashes:
		_append_crown(surfaces[int(splash.team)],splash)
	for team in 2:
		var mesh: ArrayMesh
		if not surfaces[team].vertices.is_empty():
			var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = surfaces[team].vertices
			arrays[Mesh.ARRAY_NORMAL] = surfaces[team].normals
			arrays[Mesh.ARRAY_COLOR] = surfaces[team].colors
			arrays[Mesh.ARRAY_INDEX] = surfaces[team].indices
			mesh = ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_stream_nodes[team].mesh = mesh
		_bead_nodes[team].multimesh.visible_instance_count = bead_counts[team]
	active_droplet_count = _droplets.size()
	active_splash_count = _splashes.size()

func debug_stats() -> Dictionary:
	return {"projectiles": active_projectile_count,"droplets":_droplets.size(),"splashes":_splashes.size(),
		"max_projectiles":MAX_PROJECTILES,"max_droplets":MAX_DROPLETS,"max_splashes":MAX_SPLASHES,
		"render_nodes":_stream_nodes.size()+_bead_nodes.size(),"pooled_instances":2*MAX_INSTANCES_PER_TEAM}

func _surface() -> Dictionary:
	return {"vertices":PackedVector3Array(),"normals":PackedVector3Array(),"indices":PackedInt32Array(),"colors":PackedColorArray()}

func _write_bead(team: int, counts: Array[int], pos: Vector3, velocity: Vector3, radius: float, length_radius: float) -> void:
	if counts[team] >= MAX_INSTANCES_PER_TEAM or radius < .002: return
	var direction := velocity.normalized() if velocity.length_squared()>.001 else Vector3.UP
	var basis := Basis(Quaternion(Vector3.UP, direction))*Basis.from_scale(Vector3(radius,length_radius,radius))
	_bead_nodes[team].multimesh.set_instance_transform(counts[team],Transform3D(basis,pos))
	counts[team] += 1

func _append_tube(surface: Dictionary, points: PackedVector3Array, radii: PackedFloat32Array, pale: bool = false) -> void:
	var vertices: PackedVector3Array = surface.vertices
	var normals: PackedVector3Array = surface.normals
	var colors: PackedColorArray = surface.colors
	var indices: PackedInt32Array = surface.indices
	var start := vertices.size()
	for i in points.size():
		var direction := points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]
		if direction.length_squared()<.000001: direction = Vector3.FORWARD
		direction = direction.normalized()
		var side := direction.cross(Vector3.UP).normalized()
		if side.length_squared()<.1: side = Vector3.RIGHT
		var up := side.cross(direction).normalized()
		for j in RING_SIDES:
			var angle := TAU*float(j)/float(RING_SIDES)
			var n := side*cos(angle)+up*sin(angle)
			vertices.append(points[i]+n*radii[i]); normals.append(n)
			colors.append(Color(0,1,1,1) if pale else Color.WHITE)
	for i in points.size()-1:
		for j in RING_SIDES:
			var a := start+i*RING_SIDES+j
			var b := start+i*RING_SIDES+(j+1)%RING_SIDES
			var c := b+RING_SIDES; var d := a+RING_SIDES
			indices.append_array(PackedInt32Array([a,b,c,a,c,d]))
	surface.vertices=vertices; surface.normals=normals; surface.indices=indices; surface.colors=colors

func _append_crown(surface: Dictionary, splash: Dictionary) -> void:
	var age := float(splash.age); var fraction := age/float(splash.life)
	var radius := float(splash.radius)
	var normal: Vector3 = splash.normal
	var basis := Basis(Quaternion(Vector3.UP, normal))
	var center: Vector3 = splash.pos
	var phase := float(splash.phase)
	# A hollow fluted sheet opens, peaks and collapses. No solid flat flower sticker.
	if fraction < .72:
		var expansion := .13 + .48*(1.0-pow(1.0-minf(fraction/.72,1.0),2.0))
		var height := .42*sin(minf(fraction/.72,1.0)*PI)*minf(radius,1.3)
		var vertices: PackedVector3Array = surface.vertices
		var normals: PackedVector3Array = surface.normals
		var colors: PackedColorArray = surface.colors
		var indices: PackedInt32Array = surface.indices
		var start := vertices.size()
		for i in 25:
			var a := TAU*float(i)/24.0
			var spikes := .48+.52*pow(.5+.5*cos(a*6.0+phase),3.0)
			var direction := Vector3(cos(a),0,sin(a))
			var bottom := direction*radius*expansion
			var top := direction*radius*(expansion+.08)+Vector3.UP*(.025+height*spikes)
			vertices.append(center+basis*bottom); vertices.append(center+basis*top)
			var n := basis*(direction*.82+Vector3.UP*.57)
			normals.append(n); normals.append(n)
			colors.append(Color.WHITE); colors.append(Color.WHITE)
		for i in 24:
			var a := start+i*2
			# One clockwise-wound thin sheet; cull_disabled renders its inside without coplanar duplicates.
			indices.append_array(PackedInt32Array([a,a+3,a+1,a,a+2,a+3]))
		surface.vertices=vertices; surface.normals=normals; surface.indices=indices; surface.colors=colors
	# Thin capillary ring: contracts in thickness while spreading within the splat.
	var points := PackedVector3Array(); var radii := PackedFloat32Array()
	var ring_radius := radius*(.18+.49*fraction)
	for i in 25:
		var a := TAU*float(i)/24.0
		var irregular := 1.0+.055*sin(a*5.0+phase)
		points.append(center+basis*Vector3(cos(a)*ring_radius*irregular,.020,sin(a)*ring_radius*irregular))
		radii.append(.019*(1.0-fraction))
	_append_tube(surface,points,radii,true)
