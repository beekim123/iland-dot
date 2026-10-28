extends RefCounted
## Original procedural toy-town assets; no textures, external models or collisions.
const CREAM = "e4d5b1"
const INK = "355b65"
const LEAF = "537e62"
const WOOD = "96674c"
const CORAL = "a95e48"
const TEAL = "4e797f"
static func _mesh(root: Node3D, mesh: Mesh, at: Vector3, color: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = at
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = .85
	n.material_override = m
	root.add_child(n)
	return n
static func _box(root: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(root,m,at,color)
static func _oval(root: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = .5
	m.height = 1
	m.radial_segments = 12
	m.rings = 6
	var n := _mesh(root,m,at,color)
	n.scale = size
	return n
static func _cyl(root: Node3D, at: Vector3, bottom: float, top: float, height: float, color: String) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = height
	m.radial_segments = 12
	return _mesh(root,m,at,color)
static func _roof(root: Node3D, width: float, depth: float, base: float, rise: float, color: String) -> void:
	var a := Vector3(-width,base,-depth)
	var b := Vector3(width,base,-depth)
	var c := Vector3(width,base,depth)
	var d := Vector3(-width,base,depth)
	var e := Vector3(0,base+rise,-depth)
	var f := Vector3(0,base+rise,depth)
	var faces := [[a,e,f,d],[e,b,c,f],[a,b,e],[d,f,c],[a,d,c,b]]
	var normals := [Vector3(-rise,width,0).normalized(),Vector3(rise,width,0).normalized(),Vector3.FORWARD,Vector3.BACK,Vector3.DOWN]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in faces.size():
		var face: Array = faces[i]
		for j in range(1,face.size()-1):
			var v0: Vector3 = face[0]
			var v1: Vector3 = face[j]
			var v2: Vector3 = face[j+1]
			if (v1-v0).cross(v2-v0).dot(normals[i]) > 0:
				var tmp := v1
				v1 = v2
				v2 = tmp
			for v: Vector3 in [v0,v1,v2]:
				st.set_normal(normals[i])
				st.add_vertex(v)
	_mesh(root,st.commit(),Vector3.ZERO,color)
static func _window(root: Node3D, x: float, accent: String) -> void:
	_box(root,Vector3(x,2,7.03),Vector3(2.15,1.8,.14),CREAM)
	_box(root,Vector3(x,2,7.12),Vector3(1.8,1.48,.08),INK)
	_box(root,Vector3(x,2,7.18),Vector3(.10,1.5,.07),CREAM)
	_box(root,Vector3(x,2,7.18),Vector3(1.8,.10,.07),CREAM)
	_box(root,Vector3(x,1.05,7.15),Vector3(2.45,.14,.3),CREAM)
	for side in [-1,1]:
		_box(root,Vector3(x+side*1.3,2,7.03),Vector3(.38,1.75,.18),accent)
		for y in [1.5,1.8,2.1,2.4]:
			_box(root,Vector3(x+side*1.3,y,7.14),Vector3(.31,.07,.05),CREAM)
static func make_shop(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "OriginalSeasideShop%d" % index
	var wall: String = ["d88762","e7b851","77a6a0","7898b0"][index%4]
	var roof: String = CORAL if index%2==0 else TEAL
	_box(root,Vector3(0,1.95,0),Vector3(14,3.9,14),wall)
	_box(root,Vector3(0,.22,0),Vector3(14.12,.44,14.12),CREAM)
	_box(root,Vector3(0,3.85,0),Vector3(14.45,.22,14.45),CREAM)
	_roof(root,7.35,7.35,3.96,1.65,roof)
	_cyl(root,Vector3(4,5.2,-3),.40,.34,1.55,WOOD)
	_cyl(root,Vector3(4,6,-3),.48,.48,.18,CREAM)
	for side in 4:
		var facade := Node3D.new()
		facade.rotation.y = side*PI/2
		root.add_child(facade)
		for x in [-4.5,4.5]:
			_window(facade,x,roof)
		_box(facade,Vector3(0,1.15,7.05),Vector3(1.95,2.3,.18),CREAM)
		_oval(facade,Vector3(0,2.28,7.05),Vector3(1.95,1.05,.18),CREAM)
		_box(facade,Vector3(0,1.08,7.17),Vector3(1.60,2.15,.10),TEAL)
		_box(facade,Vector3(0,1.62,7.24),Vector3(1.20,.87,.05),INK)
		_box(facade,Vector3(0,1.62,7.28),Vector3(.07,.87,.03),CREAM)
		_oval(facade,Vector3(.55,.98,7.28),Vector3(.13,.13,.10),"e7b851")
		for stripe in 7:
			var n := _box(facade,Vector3(-1.5+stripe*.5,2.95,7.55),Vector3(.49,.12,1.2),CREAM if stripe%2==0 else roof)
			n.rotation.x = .15
			_oval(facade,Vector3(-1.5+stripe*.5,2.80,8.1),Vector3(.5,.28,.1),CREAM if stripe%2==0 else roof)
		_box(facade,Vector3(0,3.43,7.12),Vector3(3.2,.55,.18),CREAM)
		if index%4==0:
			for k in 5:
				var a := k*TAU/5
				_oval(facade,Vector3(cos(a)*.2,3.43+sin(a)*.15,7.25),Vector3(.25,.22,.08),CORAL)
			_oval(facade,Vector3(0,3.43,7.30),Vector3(.15,.15,.06),"e7b851")
		elif index%4==1:
			_oval(facade,Vector3(0,3.43,7.25),Vector3(.53,.34,.10),"e7b851")
			_oval(facade,Vector3(.22,3.58,7.26),Vector3(.23,.09,.06),LEAF)
		elif index%4==2:
			for k in 5:
				var n := _oval(facade,Vector3((k-2)*.1,3.43,7.25),Vector3(.16,.36-abs(k-2)*.05,.08),CORAL)
				n.rotation.z = (2-k)*.22
		else:
			_box(facade,Vector3(0,3.43,7.25),Vector3(.6,.32,.06),TEAL)
			for s in [-1,1]:
				var n := _box(facade,Vector3(s*.14,3.47,7.30),Vector3(.32,.035,.02),CREAM)
				n.rotation.z = s*.48
		for x in [-6.8,6.8]:
			_box(facade,Vector3(x,1.95,7.05),Vector3(.22,3.7,.12),CREAM)
	return root
static func make_post() -> Node3D:
	var root := Node3D.new()
	root.name = "ParcelCollectionKiosk"
	_box(root,Vector3(0,.95,0),Vector3(1.8,1.9,2),TEAL)
	_roof(root,.9,1,2,.42,CORAL)
	_box(root,Vector3(0,1.3,1.01),Vector3(1.5,.85,.04),INK)
	for x in [-.8,.8]:
		_box(root,Vector3(x,1.3,1.04),Vector3(.1,1,.08),CREAM)
	_box(root,Vector3(0,.9,.89),Vector3(1.65,.14,.22),CREAM)
	_box(root,Vector3(0,1.83,1.04),Vector3(1.65,.23,.05),"e7b851")
	for x in [-.44,.31]:
		_box(root,Vector3(x,1.12,.88),Vector3(.52,.32,.24),"ba8d5e")
		_box(root,Vector3(x,1.12,1.008),Vector3(.08,.32,.01),CREAM)
	_box(root,Vector3(0,.42,1.01),Vector3(.65,.37,.025),CREAM)
	_box(root,Vector3(0,.42,1.03),Vector3(.45,.05,.02),TEAL)
	var label := Label3D.new()
	label.text = "POST"
	label.font_size = 64
	label.pixel_size = .003
	label.position = Vector3(0,1.83,1.08)
	label.modulate = Color(INK)
	root.add_child(label)
	return root
static func make_tree() -> Node3D:
	var root := Node3D.new()
	root.name = "RoundSaltwindTree"
	_cyl(root,Vector3(0,.95,0),.19,.12,1.9,WOOD)
	for side in [-1,1]:
		var b := _cyl(root,Vector3(side*.22,1.6,0),.08,.05,.8,WOOD)
		b.rotation.z = -side*.6
	_oval(root,Vector3(0,2.5,0),Vector3(2.15,2.4,2.1),LEAF)
	_oval(root,Vector3(-.62,2.25,.24),Vector3(1.5,1.6,1.5),"487e65")
	_oval(root,Vector3(.6,2.65,-.12),Vector3(1.55,1.65,1.5),"537e62")
	return root
static func make_animal(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "SeasideOtter" if index%2==0 else "SeasideRabbit"
	var fur := WOOD if index%2==0 else CREAM
	for s in [-1,1]:
		_oval(root,Vector3(s*.23,.12,0),Vector3(.3,.24,.44),fur)
	_oval(root,Vector3(0,.6,0),Vector3(.83,.95,.68),TEAL if index%2==0 else CORAL)
	_oval(root,Vector3(0,1.1,-.02),Vector3(.78,.72,.66),fur)
	for s in [-1,1]:
		_oval(root,Vector3(s*.3,1.4,0),Vector3(.23,.25 if index%2==0 else .6,.21),fur)
		_oval(root,Vector3(s*.18,1.17,-.322),Vector3(.085,.105,.05),INK)
		var arm := _oval(root,Vector3(s*.43,.65,0),Vector3(.21,.48,.25),fur)
		arm.rotation.z = s*.18
	_oval(root,Vector3(0,1,-.34),Vector3(.4,.25,.2),CREAM)
	_oval(root,Vector3(0,1.09,-.44),Vector3(.12,.08,.07),INK)
	_box(root,Vector3(.15,.54,-.35),Vector3(.35,.32,.1),"ba8d5e")
	_box(root,Vector3(.15,.69,-.41),Vector3(.38,.07,.04),CREAM)
	for s in [-1,1]:
		_oval(root,Vector3(s*.18-.014,1.19,-.350),Vector3(.022,.027,.012),CREAM)
	_merge(root)
	return root
static func _merge(root: Node3D) -> void:
	var groups: Dictionary = {}
	for n: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false):
		var color: String = n.material_override.albedo_color.to_html()
		if not groups.has(color):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_material(n.material_override)
			groups[color] = st
		groups[color].append_from(n.mesh,0,n.transform)
		n.free()
	var combined := ArrayMesh.new()
	for key in groups:
		groups[key].commit(combined)
	var mesh := MeshInstance3D.new()
	mesh.mesh = combined
	root.add_child(mesh)

static func make_lighthouse() -> Node3D:
	var root := Node3D.new()
	root.name = "StripedSeasideBeacon"
	# Ground origin; same 1.7 maximum tower radius as previous landmark.
	_cyl(root,Vector3(0,4.5,0),1.7,1.1,9,CREAM)
	for y in [2.4,5.1,7.8]:
		var radius := lerpf(1.7,1.1,y/9.0)
		_cyl(root,Vector3(0,y,0),radius+.05,radius,.65,CORAL)
	_cyl(root,Vector3(0,9.1,0),1.32,1.32,.22,TEAL)
	_cyl(root,Vector3(0,9.7,0),.88,.88,1.0,"e7b851")
	for k in 8:
		var a := k*TAU/8
		_cyl(root,Vector3(cos(a)*.93,9.7,sin(a)*.93),.055,.055,1.1,TEAL)
	_cyl(root,Vector3(0,10.42,0),1.16,0,.65,CORAL)
	_cyl(root,Vector3(0,10.9,0),.055,.055,.45,TEAL)
	return root

static func make_flowerbox() -> Node3D:
	var root := Node3D.new()
	root.name = "WindowFlowerBox"
	_box(root,Vector3(0,.3,0),Vector3(1.6,.6,.65),WOOD)
	_box(root,Vector3(0,.6,0),Vector3(1.7,.12,.75),CREAM)
	for k in 5:
		var x := (k-2)*.3
		_oval(root,Vector3(x,.78,0),Vector3(.52,.43,.55),LEAF)
		_oval(root,Vector3(x,.98,.05),Vector3(.25,.24,.24),CORAL if k%2==0 else "e7b851")
		_oval(root,Vector3(x,1.03,.16),Vector3(.10,.10,.08),CREAM)
	return root
