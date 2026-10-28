extends Node3D
## Authoritative XY geometry; decorative foliage remains behind the play plane.
var terrain: Node3D
var ropes := {}
var fruits := {}
var current_segment := -1
var elapsed := 0.0
var rope_mesh: CylinderMesh
var tip_mesh: SphereMesh
var warning_mesh: BoxMesh
var mats := {}
func material(key: String, color: Color) -> StandardMaterial3D:
	if mats.has(key): return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	mats[key] = m
	return m
func mesh_node(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	(parent if parent != null else terrain).add_child(n)
	return n
func box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	return mesh_node(b,pos,mat)
func ellipsoid(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radial_segments=12; s.rings=6
	var n := mesh_node(s,pos,mat); n.scale=size
	return n
func rod(a: Vector3,b: Vector3,radius: float,mat: Material,parent: Node3D = null) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius=radius; c.bottom_radius=radius*1.12; c.height=maxf(a.distance_to(b),0.001); c.radial_segments=7
	var n := mesh_node(c,(a+b)*0.5,mat,parent)
	var d := (b-a).normalized()
	if absf(d.dot(Vector3.UP)) < 0.999: n.quaternion = Quaternion(Vector3.UP,d)
	elif d.y < 0: n.rotation.z=PI
	return n
func build(s: Dictionary) -> void:
	if terrain != null: terrain.free()
	terrain=Node3D.new(); add_child(terrain)
	ropes.clear(); fruits.clear(); current_segment=int(s.get("segment",0))
	rope_mesh=CylinderMesh.new(); rope_mesh.top_radius=.045; rope_mesh.bottom_radius=.05; rope_mesh.height=1.0; rope_mesh.radial_segments=7
	tip_mesh=SphereMesh.new(); tip_mesh.radius=.08; tip_mesh.height=.16; tip_mesh.radial_segments=8; tip_mesh.rings=4
	warning_mesh=BoxMesh.new(); warning_mesh.size=Vector3(.14,.08,.04)
	var biome=posmod(current_segment,4)
	var wood=material("wood_%d"%biome,[Color("995c37"),Color("7f7962"),Color("966139"),Color("7a8275")][biome])
	var grass=material("grass",Color("64b849"))
	var moss=material("moss",Color("bedb63"))
	var leaf=material("leaf",Color("318965"))
	var farleaf=material("farleaf",Color("76ad95"))
	var bounds: Rect2=s.get("bounds",Rect2(-5,-8,45,25))
	# Layered trunks and round crowns are deliberately far behind gameplay.
	for i in range(13):
		var x=bounds.position.x+float(i)*bounds.size.x/12.0
		rod(Vector3(x,-11,-7),Vector3(x+sin(i)*1.2,10,-7),0.23,material("farwood",Color("80a58b")))
		for j in range(3): ellipsoid(Vector3(x+(j-1)*1.5,9.2+sin(i+j),-6),Vector3(3.2,2.2,1.4),farleaf)
	for p in s.get("platforms",[]):
		var r: Rect2=p.rect
		box(Vector3(r.get_center().x,r.get_center().y,-0.28),Vector3(r.size.x,r.size.y,1.1),wood)
		# Cap TOP aligns to real collision plane, not an elevated decorative floor.
		box(Vector3(r.get_center().x,r.end.y-0.065,0),Vector3(r.size.x,0.13,1.22),grass)
		for i in range(maxi(1,int(r.size.x*1.3))):
			var x=r.position.x+0.22+i*0.74
			if x>r.end.x-0.1: break
			ellipsoid(Vector3(x,r.end.y-0.18,0.45),Vector3(0.35,0.22,0.16),moss)
		# Roots attach below solid platforms; never resemble traversable ropes.
		for i in range(3): rod(Vector3(r.get_center().x+(i-1)*r.size.x*.22,r.position.y,-.2),Vector3(r.get_center().x+(i-1)*.35,r.position.y-1.3,-.2),.13,wood)
	for v in s.get("vines",[]):
		var root:=Node3D.new(); terrain.add_child(root); ropes[str(v.id)]=root
		for i in range(8): mesh_node(rope_mesh,Vector3.ZERO,material("vine",Color("588c39")),root)
		mesh_node(tip_mesh,Vector3.ZERO,material("vine",Color("588c39")),root)
		for i in range(3): mesh_node(warning_mesh,Vector3.ZERO,material("warning",Color("ef9b43")),root)
		var a: Vector2=v.anchor
		# Actual anchor remains unchanged; a woody branch reaches it from back canopy.
		rod(Vector3(a.x-2.2,a.y+2.7,-3.6),Vector3(a.x,a.y+.08,-.18),.14,wood)
		rod(Vector3(a.x-.75,a.y+.85,-1.25),Vector3(a.x+1.15,a.y+1.4,-1.8),.085,wood)
		var cluster=[]
		for j in range(5):
			var t=Transform3D(Basis.IDENTITY,Vector3(a.x+(j-2)*.28,a.y+.4+absf(j-2)*.12,-.6))
			t.basis=Basis(Vector3.FORWARD,(j-2)*.35).scaled(Vector3(.65,.27,.35)); cluster.append(t)
		leaf_batch(cluster,leaf)
	for f in s.get("collectibles",[]):
		var root:=Node3D.new(); terrain.add_child(root); fruits[str(f.id)]=root
		var pos: Vector2=f.pos; root.position=Vector3(pos.x,pos.y,.15)
		# A small three-piece curved banana silhouette, readable from the camera.
		for j in range(3):
			var b:=SphereMesh.new(); b.radial_segments=10; b.rings=5
			var n:=mesh_node(b,Vector3((j-1)*.1,pow(float(j-1),2)*.06,0),material("banana",Color("ffdb55")),root); n.scale=Vector3(.15,.27,.14); n.rotation.z=(j-1)*-.45
	var ex: Rect2=s.get("exit_rect",Rect2(32,0,2,3))
	var x=ex.get_center().x; var y=ex.position.y
	# Treehouse background does not add an uncollidable floor.
	box(Vector3(x,y+1.2,-1.25),Vector3(2.3,2.2,.55),material("house",Color("cc9657")))
	box(Vector3(x,y+1.0,-.92),Vector3(.72,1.6,.08),material("door",Color("355a49")))
	rod(Vector3(x-1.5,y+2.35,-.85),Vector3(x,y+3.15,-.85),.25,leaf)
	rod(Vector3(x,y+3.15,-.85),Vector3(x+1.5,y+2.35,-.85),.25,leaf)
	build_biome(biome,bounds)

	update_snapshot(s,0)
func leaf_batch(transforms: Array, mat: Material) -> void:
	if transforms.is_empty(): return
	var sphere:=SphereMesh.new(); sphere.radial_segments=10; sphere.rings=5
	var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; mm.mesh=sphere; mm.instance_count=transforms.size()
	for i in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
	var instance:=MultiMeshInstance3D.new(); instance.multimesh=mm; instance.material_override=mat; terrain.add_child(instance)
func build_biome(biome: int,bounds: Rect2) -> void:
	var foliage: Array=[]
	match biome:
		0: # Fern gully: tall fan leaves below/behind the traversable plane.
			for x in [-1.0,6.0,13.0,21.0,29.0]:
				for j in range(7):
					var angle=(j-3)*.29
					var t=Transform3D(Basis(Vector3.FORWARD,angle).scaled(Vector3(.5,3.0,.35)),Vector3(x-sin(angle)*1.4,-.8+cos(angle)*.55,-5))
					foliage.append(t)
			leaf_batch(foliage,material("fern",Color("65a775")))
		1: # Wide cool waterfalls and crag silhouettes, not fake stepping ledges.
			for x in [5.0,20.0]:
				for side in [-1,1]:
					var crag=box(Vector3(x+side*2.7,1,-9),Vector3(2.2,17,1),material("cliff",Color("78999a"))); crag.rotation.z=side*.1
				box(Vector3(x,2,-8),Vector3(3.6,19,.12),material("fallbase",Color("91d6d5")))
				for j in range(5): box(Vector3(x-1.45+j*.7,2,-7.8),Vector3(.16,19,.08),material("fallfoam",Color("c5e9de")))
		2: # Branch canopy: sweeping giant limbs behind every gap.
			for x in [-1.0,13.0,27.0]:
				rod(Vector3(x,-9,-6),Vector3(x+2,9,-6),.8,material("canopywood",Color("8d9670")))
				rod(Vector3(x+1,2,-5),Vector3(x+6,6.5,-5),.42,material("canopywood",Color("8d9670")))
				for j in range(8):
					var t=Transform3D(Basis.IDENTITY.scaled(Vector3(2.2,1.1,.8)),Vector3(x+j*.85,5.6+j*.25,-5.5)); foliage.append(t)
			leaf_batch(foliage,material("goldcanopy",Color("9ab966")))
		3: # Ancient grove: broken mossy pillars and curved ruin arch in the distance.
			for x in [4.0,20.0]:
				var stone=material("ruinstone",Color("9fa993"))
				for side in [-1,1]:
					box(Vector3(x+side*2.5,.4,-7),Vector3(.9,7,.85),stone)
					for j in range(3): box(Vector3(x+side*2.5,-1.8+j*1.7,-6.52),Vector3(.95,.08,.07),material("ruinseam",Color("718776")))
				for j in range(7):
					var angle=float(j)*PI/6
					var block=box(Vector3(x+cos(angle)*2.5,3.8+sin(angle)*2.5,-7),Vector3(1.15,.8,.9),stone); block.rotation.z=angle-PI/2
					var t=Transform3D(Basis.IDENTITY.scaled(Vector3(.9,.25,.6)),block.position+Vector3(0,.5,.1)); foliage.append(t)
			leaf_batch(foliage,material("ruinmoss",Color("709565")))
func update_snapshot(s: Dictionary, delta: float) -> void:
	if terrain==null or current_segment!=int(s.get("segment",0)): build(s); return
	elapsed+=delta
	for v in s.get("vines",[]):
		var root: Node3D=ropes.get(str(v.id))
		if root==null: continue
		root.visible=not bool(v.get("broken",false))
		if not root.visible: continue
		var a: Vector2=v.anchor; var b: Vector2=v.get("tip",a+Vector2(0,-float(v.length)))
		var warning=bool(v.get("warning",false))
		var m=material("warning" if warning else "vine",Color("ef9b43") if warning else Color("588c39"))
		# Real tip/anchor control every link. Mild sag is cosmetic and zero at ends.
		var prev=Vector3(a.x,a.y,.04)
		for i in range(1,9):
			var t=float(i)/8.0; var p=a.lerp(b,t)
			p.x+=sin(t*PI)*sin(elapsed*2.1)*.028
			var nxt=Vector3(p.x,p.y,.04)
			var link: MeshInstance3D=root.get_child(i-1)
			link.position=(prev+nxt)*.5; link.scale=Vector3(1,prev.distance_to(nxt),1); link.material_override=m
			link.quaternion=Quaternion(Vector3.UP,(prev-nxt).normalized())
			prev=nxt
		var tip: MeshInstance3D=root.get_child(8); tip.position=Vector3(b.x,b.y,.04); tip.material_override=m
		# Falling leaf fragments signal weak rope in addition to the orange color.
		for j in range(3):
			var fragment: MeshInstance3D=root.get_child(9+j); fragment.visible=warning
			fragment.position=Vector3(b.x+.18*sin(j*2.0+elapsed),b.y+.8-fmod(elapsed*1.4+j*.3,1.0),.1)

	for f in s.get("collectibles",[]):
		var n: Node3D=fruits.get(str(f.id))
		if n!=null: n.visible=not bool(f.get("collected",false)); n.rotation.y=sin(elapsed*1.4)*.35
