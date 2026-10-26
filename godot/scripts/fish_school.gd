extends Node3D
## Original Blender fish, with deterministic coordinated schooling and tail propulsion.
const BoneActor = preload("res://scripts/bone_actor.gd")
const FISH_PATH := "res://resources/models/fish.glb"
var fish: Array[Dictionary] = []
var initialized := false

func setup(world: Node3D) -> void:
	if initialized: return
	if not get_parent(): world.add_child(self)
	name = "LivingFishSchools"
	var packed := load(FISH_PATH) as PackedScene
	if not packed:
		push_error("Missing authored fish.glb")
		return
	for school in range(2):
		for index in range(8):
			var body := packed.instantiate() as Node3D
			body.name = "School%dFish%02d" % [school,index]
			add_child(body)
			var size := 0.58 + float((index*3)%5)*0.035
			body.scale = Vector3.ONE*size
			var rig := BoneActor.bind_actor(body,"Swim")
			fish.append({"body":body,"school":school,"index":index,"rig":rig})
	initialized = true
	apply_motion(0.0)

func _position_at(t: float, school: int, index: int) -> Vector3:
	# A loose cohort follows one leader; individual fish no longer fill a whole circle.
	var speed := 0.18 if school == 0 else -0.16
	var phase := t*speed + float(school)*1.7
	var center := Vector2(-4.4,10.0) if school == 0 else Vector2(3.8,10.3)
	var leader := center + Vector2(cos(phase)*1.25,sin(phase)*0.50)
	var forward := Vector2(-sin(phase)*1.25,cos(phase)*0.50)*signf(speed)
	forward = forward.normalized()
	var side := Vector2(-forward.y,forward.x)
	var offsets: Array[Vector2] = [Vector2(-1.5,-0.8),Vector2(-0.7,0.45),Vector2(0.25,-0.8),Vector2(0.55,0.5),Vector2(1.65,-0.25),Vector2(-1.5,0.95),Vector2(-0.3,1.65),Vector2(0.65,1.65)]
	var offset := offsets[index]
	# Asynchronous small adjustments keep spacing without a mechanical perfect formation.
	offset += Vector2(sin(t*0.73+index*2.1),cos(t*0.61+index*1.8))*0.04
	var point := leader + side*offset.x + forward*offset.y
	var depth := -0.72 - float(index%3)*0.085 + sin(t*1.15+float(index)*1.8)*0.045
	return Vector3(point.x,depth,point.y)

func apply_motion(t: float) -> void:
	for entry in fish:
		var body: Node3D = entry.body
		var school: int = entry.school
		var index: int = entry.index
		var p := _position_at(t,school,index)
		var tangent := (_position_at(t+0.04,school,index)-_position_at(t-0.04,school,index)).normalized()
		body.position = p
		# Blender front -Y maps to Godot +Z.
		body.rotation = Vector3(-asin(clampf(tangent.y,-1.0,1.0)),atan2(tangent.x,tangent.z),sin(t*1.35+index)*0.055)
		BoneActor.sample(entry.rig,"Swim",t+float(index)*0.21)

func update_motion(t: float) -> void:
	apply_motion(t)
