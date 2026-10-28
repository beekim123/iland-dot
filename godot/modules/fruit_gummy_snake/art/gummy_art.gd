extends RefCounted
## Original code-native meshes. Opaque glossy gummy look avoids transparent sorting ambiguity.
const FRUIT_COLORS := [Color("ee728a"),Color("ffb34d"),Color("f56889"),Color("ae8be3"),Color("ff7184")]
var materials := {}
var sphere: SphereMesh
var small_sphere: SphereMesh

func _init() -> void:
	sphere=SphereMesh.new();sphere.radial_segments=16;sphere.rings=8;sphere.radius=.5;sphere.height=1
	small_sphere=SphereMesh.new();small_sphere.radial_segments=10;small_sphere.rings=5;small_sphere.radius=.5;small_sphere.height=1

func material(color: Color, roughness: float=.24) -> StandardMaterial3D:
	var key := color.to_html()+str(roughness)
	if materials.has(key):return materials[key]
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=roughness;m.metallic=0.0;m.metallic_specular=.45
	materials[key]=m;return m

func blob(parent:Node3D, at:Vector3, scale_value:Vector3, color:Color, detail:bool=true) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=sphere if detail else small_sphere;node.position=at;node.scale=scale_value;node.material_override=material(color);parent.add_child(node);return node

func box(parent:Node3D, at:Vector3, size_value:Vector3, color:Color, roughness:float=.55) -> MeshInstance3D:
	var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size_value;n.mesh=mesh;n.material_override=material(color,roughness);n.position=at;parent.add_child(n);return n

func board() -> Node3D:
	var root:=Node3D.new();root.name="CreamCandyTray"
	box(root,Vector3(0,-.65,0),Vector3(80,.3,80),Color("bda8bb"),1)
	# Rounded tray perimeter is built with long glossy capsules and domed corners.
	box(root,Vector3(0,-.21,0),Vector3(17.4,.4,13.4),Color("f6e9cd"),.38)
	box(root,Vector3(0,.01,0),Vector3(16,.08,12),Color("e7d5b5"),.75)
	for x in [-8.45,8.45]:
		blob(root,Vector3(x,0,0),Vector3(.7,.7,13.5),Color("eadbbd"))
	for z in [-6.45,6.45]:
		blob(root,Vector3(0,0,z),Vector3(17.5,.7,.7),Color("eadbbd"))
	for x in [-8.4,8.4]:
		for z in [-6.4,6.4]:blob(root,Vector3(x,0,z),Vector3(.85,.7,.85),Color("eadbbd"))
	# Subtle regular stamps, one visual per cell, combined to one mesh draw call.
	var im:=ImmediateMesh.new();im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in 12:
		for x in 16:
			if (x+y)%2==0:
				var p:=Vector3(x-7.5,.057,y-5.5)
				for v in [Vector3(-.49,0,-.49),Vector3(.49,0,.49),Vector3(.49,0,-.49),Vector3(-.49,0,-.49),Vector3(-.49,0,.49),Vector3(.49,0,.49)]:im.surface_set_normal(Vector3.UP);im.surface_add_vertex(p+v)
	im.surface_end();var stamps:=MeshInstance3D.new();stamps.mesh=im;stamps.material_override=material(Color("e3d2b4"),1).duplicate();stamps.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;root.add_child(stamps)
	var grid:=ImmediateMesh.new();grid.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-7,8):_quad(grid,Vector3(x-.009,.066,-6),Vector3(x+.009,.066,6))
	for z in range(-5,6):_quad(grid,Vector3(-8,.066,z-.009),Vector3(8,.066,z+.009))
	grid.surface_end();var grid_node:=MeshInstance3D.new();grid_node.mesh=grid;grid_node.material_override=material(Color("d4c2a3"),1).duplicate();grid_node.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;root.add_child(grid_node)
	# Decorative candies live outside the playable walls, never look like collectible targets.
	for i in 7:
		var candy:=fruit(i%5);candy.position=Vector3(-9.2-float(i%2)*.7,.05,-4.6+float(i)*1.55);candy.scale=Vector3.ONE*.65;candy.rotation.y=i*.7;root.add_child(candy)
	return root

func segment(head:bool=false, index:int=0) -> Node3D:
	var root:=Node3D.new();root.name="GummyHead" if head else "GummySegment"
	var color:=Color("80d8af") if index%2==0 else Color("9ae5bd")
	blob(root,Vector3.ZERO,Vector3(.86,.68,.9) if head else Vector3(.79,.59,.79),color)
	blob(root,Vector3(-.15,.26,-.09),Vector3(.29,.055,.22),Color("e7fff1"),false)
	if head:
		for x in [-.23,.23]:
			blob(root,Vector3(x,.23,-.29),Vector3(.22,.23,.15),Color("fffaf0"),false)
			blob(root,Vector3(x,.245,-.36),Vector3(.11,.13,.07),Color("30494b"),false)
			blob(root,Vector3(x-.022,.28,-.4),Vector3(.034,.045,.025),Color.WHITE,false)
			blob(root,Vector3(x*1.4,.07,-.31),Vector3(.15,.07,.05),Color("ff9baf"),false)
		# Tiny leaf crest gives a fruit-candy identity rather than a snake predator silhouette.
		var leaf:=blob(root,Vector3(.05,.38,.03),Vector3(.16,.07,.32),Color("42a887"),false);leaf.rotation.z=-.4
	return root

func leaf(root:Node3D, at:Vector3, angle:float=0) -> void:
	var l:=blob(root,at,Vector3(.16,.055,.36),Color("57ae82"),false);l.rotation.y=angle;l.rotation.z=.15

func fruit(kind:int) -> Node3D:
	var root:=Node3D.new();root.name="Fruit_%d"%kind
	var c:Color=FRUIT_COLORS[kind]
	match kind:
		0:
			blob(root,Vector3(-.12,.30,0),Vector3(.48,.58,.54),c);blob(root,Vector3(.12,.30,0),Vector3(.48,.58,.54),c)
			box(root,Vector3(0,.61,0),Vector3(.065,.16,.065),Color("937059"));leaf(root,Vector3(.12,.65,0),.7)
		1:
			# An orange-segment gummy with rind, flesh and radial pith hints.
			blob(root,Vector3(0,.25,0),Vector3(.76,.46,.6),Color("ffc65f"))
			blob(root,Vector3(0,.31,-.02),Vector3(.60,.35,.48),c)
			for i in 3:
				var stripe:=box(root,Vector3((i-1)*.16,.476,0),Vector3(.025,.009,.30),Color("ffe4a3"));stripe.rotation.y=(i-1)*.22
		2:
			blob(root,Vector3(0,.29,0),Vector3(.60,.60,.64),c)
			blob(root,Vector3(0,.10,-.04),Vector3(.34,.26,.38),c)
			for i in 5:leaf(root,Vector3(0,.59,0),i*TAU/5)
			for i in 8:
				var a:=i*TAU/8;blob(root,Vector3(sin(a)*.245,.31+float(i%2)*.13,cos(a)*.25),Vector3(.033,.065,.025),Color("ffe1a2"),false)
		3:
			for p in [Vector3(-.16,.36,0),Vector3(.16,.36,0),Vector3(0,.28,.2),Vector3(0,.18,-.18),Vector3(0,.10,.03),Vector3(0,.52,-.06)]:blob(root,p,Vector3.ONE*.30,c,false)
			leaf(root,Vector3(.1,.65,-.05),.6)
		4:
			# Wedge-shaped candy, all geometry stays within one authoritative cell.
			var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			var a:=Vector3(-.36,.10,.24);var b:=Vector3(.36,.10,.24);var d:=Vector3(0,.10,-.35)
			var up:=Vector3(0,.34,0)
			for v in [a+up,b+up,d+up]:mesh.surface_set_normal(Vector3.UP);mesh.surface_add_vertex(v)
			for edge in [[a,b],[b,d],[d,a]]:
				var n:Vector3=(edge[1]-edge[0]).cross(Vector3.UP).normalized()
				for v in [edge[0],edge[1]+up,edge[0]+up,edge[0],edge[1],edge[1]+up]:mesh.surface_set_normal(n);mesh.surface_add_vertex(v)
			mesh.surface_end();var n:=MeshInstance3D.new();n.mesh=mesh;n.material_override=material(c).duplicate();n.material_override.cull_mode=BaseMaterial3D.CULL_DISABLED;root.add_child(n)
			box(root,Vector3(0,.20,.25),Vector3(.77,.30,.12),Color("7ac793"))
			box(root,Vector3(0,.26,.18),Vector3(.69,.25,.035),Color("e3edaa"))
			for x in [-.16,0,.16]:blob(root,Vector3(x,.45,.05),Vector3(.035,.018,.07),Color("784851"),false)
	blob(root,Vector3(-.12,.47,-.12),Vector3(.14,.025,.1),Color("fff3e9"),false)
	return root

func _quad(mesh:ImmediateMesh,a:Vector3,b:Vector3) -> void:
	for p in [a,Vector3(b.x,a.y,b.z),Vector3(b.x,a.y,a.z),a,Vector3(a.x,a.y,b.z),b]:mesh.surface_set_normal(Vector3.UP);mesh.surface_add_vertex(p)
