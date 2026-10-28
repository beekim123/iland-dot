extends Node3D
const Map = preload("data/map.gd")
const Props = preload("art/seaside_props.gd")
var stops: Array[Node3D] = []
var traffic: Array[Node3D] = []
var marker: Node3D
func _ready() -> void: build()
func mat(hex: String, roughness: float = .85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color=Color(hex); m.roughness=roughness; return m
func box(at: Vector3, size: Vector3, color: String, parent: Node3D = self) -> MeshInstance3D:
	var n := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size=size; n.mesh=mesh; n.material_override=mat(color); n.position=at; parent.add_child(n); return n
func sphere(at: Vector3, size: Vector3, color: String, parent: Node3D = self) -> MeshInstance3D:
	var n := MeshInstance3D.new(); var mesh := SphereMesh.new(); mesh.radius=.5; mesh.height=1; mesh.radial_segments=12; mesh.rings=6; n.mesh=mesh; n.scale=size; n.material_override=mat(color); n.position=at; parent.add_child(n); return n
func strip(a: Vector2,b: Vector2,width: float,color: String, lift := .02) -> void:
	var surf := SurfaceTool.new(); surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := (b-a).normalized().orthogonal()*width*.5
	var steps := maxi(1,int(a.distance_to(b)/2))
	for i in steps:
		var p := a.lerp(b,float(i)/steps); var q := a.lerp(b,float(i+1)/steps)
		var points := [p-side,p+side,q-side,q-side,p+side,q+side]
		for v: Vector2 in points: surf.add_vertex(Vector3(v.x,Map.height_at(v)+lift,v.y))
	surf.generate_normals(); var node := MeshInstance3D.new(); node.mesh=surf.commit(); node.material_override=mat(color); add_child(node)
func build() -> void:
	box(Vector3(0,-1.6,0),Vector3(180,1,180),"4fa6b9")
	# Entire rideable island ground is sampled from the same analytic height as physics.
	var surf := SurfaceTool.new(); surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-38,38,2):
		for x in range(-38,38,2):
			for p: Vector2 in [Vector2(x,z),Vector2(x+2,z),Vector2(x+2,z+2),Vector2(x,z),Vector2(x+2,z+2),Vector2(x,z+2)]:
				surf.add_vertex(Vector3(p.x,Map.height_at(p)-.04,p.y))
	surf.generate_normals(); var ground := MeshInstance3D.new(); ground.mesh=surf.commit(); ground.material_override=mat("839b65"); add_child(ground)
	for x: float in Map.ROAD_X: strip(Vector2(x,-30),Vector2(x,30),7,"b9a581")
	for z: float in Map.ROAD_Z: strip(Vector2(-30,z),Vector2(30,z),7,"b9a581")
	# Road edge inlays, deliberately flat rather than hidden collision lips.
	for x: float in Map.ROAD_X:
		for offset in [-3.4,3.4]: strip(Vector2(x+offset,-29),Vector2(x+offset,29),.12,"c7b99b",.04)
	for z: float in Map.ROAD_Z:
		for offset in [-3.4,3.4]: strip(Vector2(-29,z+offset),Vector2(29,z+offset),.12,"c7b99b",.04)
	var i := 0
	for rect: Rect2 in Map.buildings():
		var centre := rect.get_center(); var y := Map.height_at(centre)
		var shop:Node3D=Props.make_shop(i);shop.position=Vector3(centre.x,y,centre.y);add_child(shop)
		# Keep the existing flower-box footprints aligned with unchanged collision data.
		for side in [-1,1]:
			var flowers:Node3D=Props.make_flowerbox();flowers.position=Vector3(centre.x+side*4.5,y,centre.y+7.4);add_child(flowers)
		i+=1
	_harbour()
	for index in 9:
		var p: Vector2=Map.nodes()[index]; var base:=Node3D.new(); base.position=Vector3(p.x,Map.height_at(p),p.y); add_child(base)
		var pole:=box(Vector3(4.1,1,4.1),Vector3(.18,2,.18),"31596a",base)
		box(Vector3(4.1,2.05,4.1),Vector3(1.1,.65,.2),"fff0c6",base)
		var label:=Label3D.new(); label.text=str(index+1); label.font_size=80; label.pixel_size=.008; label.position=Vector3(4.1,2.05,4.25); label.modulate=Color("31596a"); label.no_depth_test=false; base.add_child(label)
		stops.append(base)
	# Beyond-road props never occupy the collision road corridor.
	for side in [-1,1]:
		for k in 9:
			var p:=Vector2(side*33.5,-30+k*7.5); var y:=Map.height_at(p)
			var tree:Node3D=Props.make_tree();tree.position=Vector3(p.x,y,p.y);add_child(tree)
	for side in [-1,1]:
		box(Vector3(side*37.1,1,0),Vector3(.35,2.1,75),"edc891")
		box(Vector3(0,Map.height_at(Vector2(0,side*37.1))+1,side*37.1),Vector3(75,2.1,.35),"edc891")
	for j in 2:
		var cart:Node3D=Props.make_animal(j);add_child(cart);traffic.append(cart)
	marker=Node3D.new(); add_child(marker)
	var ring:=MeshInstance3D.new(); var torus:=TorusMesh.new(); torus.inner_radius=1.2;torus.outer_radius=1.35;torus.rings=24;torus.ring_segments=8;ring.mesh=torus;ring.material_override=mat("ef8f42");marker.add_child(ring)
	_batch_static()
func update(sim) -> void:
	var p: Vector2=sim.target(); marker.position=Vector3(p.x,Map.height_at(p)+.18,p.y)
	marker.visible=sim.phase in ["pickup","delivery"]
	for i in traffic.size():
		var t: Vector2=Map.traffic_position(sim.elapsed,i); traffic[i].visible=sim.job_index>0
		traffic[i].position=Vector3(t.x,Map.height_at(t),t.y)
		var direction:Vector2=Map.traffic_position(sim.elapsed+.01,i)-t
		if direction.length_squared()>.000001:traffic[i].rotation.y=atan2(-direction.x,-direction.y)

func _harbour() -> void:
	# The south road opens on a working delivery pier. Gameplay pickup is node7 (0,24).
	for n in 10:
		box(Vector3(0,-.12,30+n*1.3),Vector3(6,.28,1.2),"907657")
	for side in [-1,1]:
		for z in [31,35,39,43]:
			box(Vector3(side*3,.4,z),Vector3(.2,1.2,.2),"795e49")
			if z<43:box(Vector3(side*3,.9,z+1.5),Vector3(.1,.12,3),"ad9270")
	# Postal kiosk sits off the clear carriageway.
	var post:Node3D=Props.make_post();post.position=Vector3(-4.7,0,29);add_child(post)
	for x in [-7,-5.7]:box(Vector3(x,.4,31),Vector3(1,.8,1),"ba8d5e")
	# Moored toy delivery boat beyond the playable quay.
	var boat:=Node3D.new();boat.position=Vector3(7,-.3,40);boat.rotation.y=.3;add_child(boat)
	sphere(Vector3.ZERO,Vector3(3.5,1.3,6.5),"416e85",boat)
	box(Vector3(0,.7,0),Vector3(2.8,.3,4.5),"c9aa75",boat)
	box(Vector3(0,1.55,-.6),Vector3(1.8,1.5,1.8),"e4cf9a",boat)
	box(Vector3(0,2.4,-.6),Vector3(2.2,.2,2.2),"ae674c",boat)
	box(Vector3(0,1.7,.33),Vector3(1.3,.65,.08),"365969",boat)
	# A recognisable lighthouse at the far north, visible above the market.
	var tower:Node3D=Props.make_lighthouse();tower.position=Vector3(-31,1.3,-31);add_child(tower)
	# Chalk lane dashes make the road readable without aggressive saturation.
	for z in range(-27,28,4):
		if abs(z)>4:strip(Vector2(-.08,z),Vector2(-.08,z+1.5),.14,"ded2b6",.05)

func _batch_static() -> void:
	# Static environment is merged by material; moving carts and target stay independent.
	var groups: Dictionary={}
	var sources: Array[MeshInstance3D]=[]
	for node in find_children("*","MeshInstance3D",true,false):
		var skip:=marker.is_ancestor_of(node)
		for moving in traffic:
			if moving.is_ancestor_of(node):skip=true
		if skip or node.mesh==null:continue
		for surface in node.mesh.get_surface_count():
			var material=node.material_override if node.material_override!=null else node.mesh.surface_get_material(surface)
			if not material is StandardMaterial3D:continue
			var key: String=material.albedo_color.to_html()+str(material.roughness)
			if not groups.has(key):
				var builder:=SurfaceTool.new();builder.begin(Mesh.PRIMITIVE_TRIANGLES);builder.set_material(material);groups[key]=builder
			groups[key].append_from(node.mesh,surface,global_transform.affine_inverse()*node.global_transform)
		sources.append(node)
	var combined:=ArrayMesh.new()
	for key in groups:groups[key].commit(combined)
	var batch:=MeshInstance3D.new();batch.name="StaticSeasideBatch";batch.mesh=combined;add_child(batch)
	for node in sources:node.get_parent().remove_child(node);node.queue_free()
