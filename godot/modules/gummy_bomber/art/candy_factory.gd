extends RefCounted
## Original, self-contained soft-candy game art. Units: one board tile = 1 metre.
## Every root sits on ground Y=0. The -Z side is the face/front.
const CREAM = Color("fff0ca")
const COCOA = Color("683e55")
const INK = Color("372c48")
static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}

static func _mat(color: Color, shine: float = 0.35) -> StandardMaterial3D:
	var key := "%s/%.3f" % [color.to_html(), shine]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = shine
	_material_cache[key] = m
	return m

static func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, label: String = "Piece") -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.name = label
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

static func _ellipsoid(parent: Node3D, pos: Vector3, size: Vector3, color: Color, label: String = "Piece") -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = 16
	s.rings = 8
	var n := _mesh(parent, s, pos, color, label)
	n.scale = size
	return n

## Six rounded faces, with analytic smooth normals and bevels; not a scaled box primitive.
static func _rounded_mesh(size: Vector3, radius: float) -> ArrayMesh:
	var key := "%s/%.4f" % [str(size),radius]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axes := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var h := size * 0.5
	var inner := h - Vector3.ONE * radius
	var steps := 4
	for normal in axes:
		var u: Vector3 = Vector3.UP.cross(normal).normalized() if abs(normal.y) < 0.5 else Vector3.RIGHT
		var v: Vector3 = normal.cross(u)
		# Place support vertices at bevel boundaries instead of uniformly
		# spreading them across the flat face. Low tessellation retains shape.
		var au: float = 1.0 - radius / abs(u.dot(h))
		var bv: float = 1.0 - radius / abs(v.dot(h))
		var us := [-1.0, -au, 0.0, au, 1.0]
		var vs := [-1.0, -bv, 0.0, bv, 1.0]
		for iy in range(steps):
			for ix in range(steps):
				for corner in [Vector2i(0,0), Vector2i(0,1), Vector2i(1,1), Vector2i(0,0), Vector2i(1,1), Vector2i(1,0)]:
					var a: float = us[ix + corner.x]
					var b: float = vs[iy + corner.y]
					var raw: Vector3 = (normal + u * a + v * b) * h
					var core := raw.clamp(-inner, inner)
					var outward := (raw - core).normalized()
					st.set_normal(outward)
					st.add_vertex(core + outward * radius)
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh

static func _round(parent: Node3D, pos: Vector3, size: Vector3, radius: float, color: Color, label: String = "Piece") -> MeshInstance3D:
	return _mesh(parent, _rounded_mesh(size, radius), pos, color, label)

static func _face(root: Node3D, y: float, z: float, spacing: float = 0.12) -> void:
	for x in [-spacing, spacing]:
		_ellipsoid(root, Vector3(x,y,z), Vector3(0.068,0.095,0.035), INK, "Eye")
		_ellipsoid(root, Vector3(x-0.009,y+0.023,z-0.018), Vector3(0.02,0.025,0.012), Color.WHITE, "EyeSpark")
		_ellipsoid(root, Vector3(x*1.58,y-0.068,z+0.016), Vector3(0.09,0.038,0.022), Color("fca5b5"), "Cheek")
	_ellipsoid(root, Vector3(0,y-0.056,z-0.014), Vector3(0.05,0.028,0.018), INK, "Smile")

static func make_player() -> Node3D:
	var root := Node3D.new()
	root.name = "PeachyGumdrop"
	_ellipsoid(root, Vector3(0,0.31,0), Vector3(0.55,0.60,0.48), Color("ffb68f"), "Body")
	for x in [-0.17,0.17]:
		_ellipsoid(root,Vector3(x,0.065,-0.03),Vector3(0.18,0.13,0.23),Color("f67f98"),"Foot")
	for x in [-0.28,0.28]:
		_ellipsoid(root,Vector3(x,0.28,0),Vector3(0.12,0.22,0.14),Color("ffb68f"),"Hand")
	_face(root,0.36,-0.224)
	var crown := _ellipsoid(root,Vector3(0.035,0.617,0),Vector3(0.19,0.07,0.11),Color("8bd6af"),"MintLeaf")
	crown.rotation.z = -0.35
	_ellipsoid(root,Vector3(-0.10,0.49,-0.17),Vector3(0.08,0.13,0.018),Color("ffe6c9"),"Glaze")
	return root

static func make_enemy(kind: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "BerryJelly" if kind % 2 == 0 else "MintJelly"
	var col := Color("b49ce9") if kind % 2 == 0 else Color("76d5c7")
	_ellipsoid(root,Vector3(0,0.25,0),Vector3(0.60,0.49,0.53),col,"Body")
	for x in [-0.19,0.0,0.19]:
		_ellipsoid(root,Vector3(x,0.07,0),Vector3(0.20,0.14,0.40),col,"JellyFoot")
	_face(root,0.28,-0.252,0.115)
	for x in [-0.11,0.11]:
		var ear := _ellipsoid(root,Vector3(x,0.49,0),Vector3(0.09,0.19,0.1),col,"CandyTuft")
		ear.rotation.z = x*2
	_ellipsoid(root,Vector3(-0.13,0.36,-0.19),Vector3(0.07,0.1,0.02),Color("e8f5ff"),"Glaze")
	return root

static func make_bomb() -> Node3D:
	var root := Node3D.new()
	root.name = "SugarPopBomb"
	_ellipsoid(root,Vector3(0,0.23,0),Vector3(0.43,0.43,0.43),Color("f35a8c"),"Body")
	_round(root,Vector3(0,0.42,0),Vector3(0.13,0.08,0.13),0.025,CREAM,"FuseSocket")
	var fuse := _round(root,Vector3(0.035,0.49,0),Vector3(0.035,0.12,0.035),0.012,COCOA,"Fuse")
	fuse.rotation.z = -0.4
	_ellipsoid(root,Vector3(0.06,0.56,0),Vector3(0.09,0.09,0.09),Color("ffda63"),"Spark")
	for x in [-0.10,0.0,0.10]:
		_ellipsoid(root,Vector3(x,0.25,-0.204),Vector3(0.035,0.12,0.018),CREAM,"SugarStripe")
	return root

static func make_wall() -> Node3D:
	var root := Node3D.new()
	root.name = "ChocolateStone"
	_round(root,Vector3(0,0.34,0),Vector3(0.93,0.68,0.93),0.10,COCOA,"ChocolateBase")
	for x in [-0.225,0.225]:
		for z in [-0.225,0.225]:
			_round(root,Vector3(x,0.685,z),Vector3(0.40,0.09,0.40),0.035,Color("946477"),"ChocolateSquare")
	return root

static func make_crate() -> Node3D:
	var root := Node3D.new()
	root.name = "BreakableWafer"
	_round(root,Vector3(0,0.28,0),Vector3(0.82,0.56,0.82),0.07,Color("e7ad6e"),"Wafer")
	for y in [0.16,0.36]:
		_round(root,Vector3(0,y,0),Vector3(0.83,0.055,0.83),0.018,Color("fff0ca"),"CreamFilling")
	for x in [-0.24,0.0,0.24]:
		for z in [-0.24,0.0,0.24]:
			_round(root,Vector3(x,0.564,z),Vector3(0.18,0.025,0.18),0.012,Color("fbd39c"),"WaferGrid")
	return root

static func make_floor(variant: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "MarshmallowTile"
	_round(root,Vector3(0,-0.09,0),Vector3(0.98,0.18,0.98),0.06,Color("fff0d8") if variant % 2 == 0 else Color("f6d6d3"),"Tile")
	return root

static func make_pickup(kind: String = "range") -> Node3D:
	var root := Node3D.new()
	root.name = "Wrapped_" + kind
	var col := Color("ffd164")
	if kind == "capacity": col = Color("b49ce9")
	if kind == "speed": col = Color("78d8bd")
	_round(root,Vector3(0,0.27,0),Vector3(0.33,0.24,0.25),0.09,col,"Candy")
	for x in [-0.22,0.22]:
		var wrap := _round(root,Vector3(x,0.27,0),Vector3(0.13,0.21,0.17),0.025,col,"Wrapper")
		wrap.rotation.z = PI/4
	_round(root,Vector3(0,0.27,-0.132),Vector3(0.055,0.15,0.018),0.008,Color.WHITE,"Label")
	if kind == "range":
		_round(root,Vector3(0,0.27,-0.135),Vector3(0.16,0.045,0.018),0.008,Color.WHITE,"Plus")
	return root

static func make_blast() -> Node3D:
	var root := Node3D.new()
	root.name = "ConfettiPop"
	_ellipsoid(root,Vector3(0,0.23,0),Vector3(0.75,0.38,0.75),Color("fff3a8"),"Flash")
	for i in range(8):
		var a := float(i)*TAU/8.0
		var piece := _round(root,Vector3(cos(a)*0.36,0.22+0.06*(i%3),sin(a)*0.36),Vector3(0.09,0.14,0.04),0.015,[Color("ff729e"),Color("8be0d0"),Color("ffcf61")][i%3],"Confetti")
		piece.rotation = Vector3(a,0,a*0.7)
	return root
