extends RefCounted
## Original procedural underwater geometry; no textures, external models or dependencies.
const Gummy = preload("res://modules/fruit_gummy_snake/art/gummy_art.gd")
var candy = Gummy.new()
var tube_material:StandardMaterial3D
var sphere:SphereMesh

func _init() -> void:
	sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1.0;sphere.radial_segments=12;sphere.rings=6
	tube_material=candy.material(Color("61cdb6"),.22)
	tube_material.vertex_color_use_as_albedo=true
	tube_material.rim_enabled=true;tube_material.rim=.36;tube_material.rim_tint=.25

func fruit(kind:int)->Node3D:
	var root:Node3D=candy.fruit(posmod(kind,5))
	root.name="FloatingFruitGummy"
	# A separate small opaque sparkle avoids large alpha-sorted collectible quads.
	return root

func snake()->Node3D:
	var root:=Node3D.new();root.name="WaterSnake"
	var tube:=MeshInstance3D.new();tube.name="ContinuousBody";tube.material_override=tube_material;root.add_child(tube)
	var head:=Node3D.new();head.name="Head";root.add_child(head)
	candy.blob(head,Vector3.ZERO,Vector3(.58,.51,.70),Color("75ddc4"))
	candy.blob(head,Vector3(0,-.12,-.16),Vector3(.44,.23,.42),Color("b1ecce"))
	for side in [-1.0,1.0]:
		candy.blob(head,Vector3(side*.24,.14,-.23),Vector3(.22,.25,.19),Color("fff6dd"))
		candy.blob(head,Vector3(side*.255,.15,-.312),Vector3(.105,.14,.065),Color("173f4d"),false)
		candy.blob(head,Vector3(side*.247,.185,-.345),Vector3(.033,.044,.025),Color.WHITE,false)
		candy.blob(head,Vector3(side*.27,-.04,-.27),Vector3(.12,.065,.045),Color("f4a5bc"),false)
		var fin:=candy.blob(head,Vector3(side*.40,-.045,.16),Vector3(.27,.045,.22),Color("66b7cd"));fin.name="FinL" if side<0 else "FinR";fin.rotation.z=side*.25
	candy.blob(head,Vector3(0,.27,.10),Vector3(.10,.24,.30),Color("a1e9df"))
	var tail:=Node3D.new();tail.name="Tail";root.add_child(tail)
	var tip:=candy.blob(tail,Vector3(0,0,.08),Vector3(.055,.19,.26),Color("6cc3cc"));tip.rotation.x=.15
	return root

func update_snake(root:Node3D,body:Array[Vector3],forward:Vector3,time:float)->void:
	if body.size()<2:return
	var head:Node3D=root.get_node("Head")
	head.position=body[0];head.quaternion=Quaternion(Vector3.FORWARD,forward.normalized())
	head.get_node("FinL").rotation.z=-.25+sin(time*7.0)*.20
	head.get_node("FinR").rotation.z=.25-sin(time*7.0)*.20
	var samples:Array[Vector3]=[]
	for i in body.size()-1:
		var a:Vector3=body[maxi(0,i-1)];var b:Vector3=body[i];var c:Vector3=body[i+1];var d:Vector3=body[mini(body.size()-1,i+2)]
		samples.append(b)
		samples.append(b.cubic_interpolate(c,a,d,.5))
	samples.append(body[-1])
	var verts:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	const SIDES:=10
	var right:=Vector3.RIGHT
	for i in samples.size():
		var tangent:Vector3=(samples[mini(i+1,samples.size()-1)]-samples[maxi(i-1,0)]).normalized()
		if tangent.length_squared()<.01:tangent=-forward
		right=(right-tangent*right.dot(tangent)).normalized()
		if right.length_squared()<.01:right=tangent.cross(Vector3.FORWARD).normalized()
		var up:=tangent.cross(right).normalized()
		var tail_factor:=clampf(float(samples.size()-1-i)/2.0,0.0,1.0)
		var radius:=lerpf(.035,.25,smoothstep(0.0,1.0,tail_factor))
		for j in SIDES:
			var angle:=TAU*j/SIDES;var normal:=right*cos(angle)+up*sin(angle)
			verts.append(samples[i]+normal*radius);normals.append(normal)
			colors.append(Color(1.0,1.0,1.0).lerp(Color(.70,.87,.93),maxf(0.0,-normal.y)*.32))
			if i<samples.size()-1:
				var aidx:=i*SIDES+j;var bidx:=i*SIDES+(j+1)%SIDES
				indices.append_array(PackedInt32Array([aidx,aidx+SIDES,bidx,bidx,aidx+SIDES,bidx+SIDES]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	root.get_node("ContinuousBody").mesh=mesh
	var tail:Node3D=root.get_node("Tail");tail.position=body[-1]
	tail.quaternion=Quaternion(Vector3.FORWARD,(body[-2]-body[-1]).normalized())
	tail.rotate_object_local(Vector3.UP,sin(time*6.0)*.20)

func _batch(parent:Node3D,transforms:Array[Transform3D],color:Color)->void:
	if transforms.is_empty():return
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=sphere;mm.instance_count=transforms.size()
	for i in transforms.size():mm.set_instance_transform(i,transforms[i])
	var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=candy.material(color,.65);parent.add_child(node)

func _shape(at:Vector3,size:Vector3)->Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(size),at)

func _branch(a:Vector3,b:Vector3,width:float)->Transform3D:
	var delta:=b-a
	var basis:=Basis(Quaternion(Vector3.UP,delta.normalized())) * Basis.from_scale(Vector3(width,delta.length()+width,width))
	return Transform3D(basis,(a+b)*.5)

func ocean()->Node3D:
	var root:=Node3D.new();root.name="OpenWaterReef"
	candy.box(root,Vector3(0,-.55,0),Vector3(600,1,600),Color("658d91"),1.0)
	var rng:=RandomNumberGenerator.new();rng.seed=73923
	var rocks:Array[Transform3D]=[];var sand:Array[Transform3D]=[]
	var coral_a:Array[Transform3D]=[];var coral_b:Array[Transform3D]=[];var kelp:Array[Transform3D]=[];var particles:Array[Transform3D]=[]
	for i in 85:
		var p:=Vector3(rng.randf_range(-42,42),-.16,rng.randf_range(-42,42))
		var size:=rng.randf_range(1.2,4.8)
		sand.append(_shape(p,Vector3(size,.20,size*.65)))
		if i%3==0:rocks.append(_shape(p+Vector3(0,.3,0),Vector3(size*.6,.8,size*.45)))
		# Decorative reef stays below the Y=2 playable floor; tall reef is outside bounds.
		var tall:bool=absf(p.x)>25 or absf(p.z)>25
		var h:=rng.randf_range(2.0,7.0) if tall else rng.randf_range(.4,1.3)
		var bucket:Array[Transform3D]=coral_a if i%2==0 else coral_b
		var trunk_base:=p+Vector3(0,.05,0)
		var trunk_tip:=trunk_base+Vector3(.12,h*.75,.08)
		bucket.append(_branch(trunk_base,trunk_tip,.18))
		for branch in 4:
			var azimuth:=branch*TAU/4.0+float(i)
			var stem_start:=trunk_base.lerp(trunk_tip,.3+branch*.13)
			var spread:=Vector3(cos(azimuth),0,sin(azimuth))
			var joint:=stem_start+spread*h*.26+Vector3(0,h*.20,0)
			var end:=joint+spread*h*.13+Vector3(0,h*.24,0)
			bucket.append(_branch(stem_start,joint,.14));bucket.append(_branch(joint,end,.105))
			bucket.append(_branch(joint,joint+Vector3(-spread.z,.7,spread.x)*h*.22,.09))
		# Broad low fans contrast with the branched silhouette.
		for blade in 3:
			var fan:=_shape(p+Vector3(.8+blade*.15,h*.32,.4),Vector3(.10,h*.64,.40))
			fan.basis=Basis(Vector3.FORWARD,(blade-1)*.35)*fan.basis
			kelp.append(fan)
	# Natural shelves and rolling dunes sit below the swim-floor in the playable volume.
	for i in 25:
		var p:=Vector3(rng.randf_range(-45,45),-1.5,rng.randf_range(-45,45))
		var tall:bool=absf(p.x)>35 or absf(p.z)>35
		var height:=rng.randf_range(5,9) if tall else rng.randf_range(2,5)
		sand.append(_shape(p,Vector3(rng.randf_range(8,17),height,rng.randf_range(7,15))))

	for i in 110:
		particles.append(_shape(Vector3(rng.randf_range(-29,29),rng.randf_range(2,27),rng.randf_range(-29,29)),Vector3.ONE*rng.randf_range(.025,.075)))
	_batch(root,sand,Color("a8c9b3"));_batch(root,rocks,Color("6f9eab"));_batch(root,coral_a,Color("d590a6"));_batch(root,coral_b,Color("d6b37c"));_batch(root,kelp,Color("518e8d"));_batch(root,particles,Color("acded8"))
	# Corner marker chains make the full height readable without enclosing the camera in alpha walls.
	var markers:Array[Transform3D]=[]
	for x in [-24.0,24.0]:
		for z in [-24.0,24.0]:
			for y in range(2,27,3):markers.append(_shape(Vector3(x,y,z),Vector3(.15,.30,.15)))
	_batch(root,markers,Color("69c6ce"))
	# Overhead caustic-like light patches, one translucent plane per shaft, kept out of central view.
	var beam_material:=candy.material(Color(.44,.86,.86,.035),1.0).duplicate() as StandardMaterial3D
	beam_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;beam_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;beam_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	for i in 5:
		var beam:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=1.8;cylinder.bottom_radius=3.2;cylinder.height=25;cylinder.radial_segments=6
		beam.mesh=cylinder;beam.material_override=beam_material;beam.position=Vector3(-20+i*10,15,-19);beam.rotation.z=.12;beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(beam)
	return root
