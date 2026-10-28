extends Node3D
## Y-up, -Z forward. Origin at the bicycle ground contact. No root-motion animation.
const FIRST_PERSON = preload("res://modules/pelican_pedal/art/models/first_person_rig.glb")
const FULL_RIDER = preload("res://modules/pelican_pedal/art/models/pelican_rider.glb")
const BICYCLE = preload("res://modules/pelican_pedal/art/models/bicycle.glb")
var first_person := true
var rider: Node3D
var bicycle: Node3D
var animator: AnimationPlayer
var wheels: Array[Node3D] = []
var current_clip := ""
var pedals: Array[Node3D] = []
var skeleton: Skeleton3D
var pedal_anchors: Dictionary = {}

func _ready() -> void:
	build()

func build() -> void:
	if is_instance_valid(rider): return
	bicycle = BICYCLE.instantiate()
	add_child(bicycle)
	rider = (FIRST_PERSON if first_person else FULL_RIDER).instantiate()
	add_child(rider)
	animator = _find_type(rider, "AnimationPlayer") as AnimationPlayer
	for n in bicycle.find_children("Wheel*", "Node3D", true, false):
		wheels.append(n as Node3D)
	for n in bicycle.find_children("Pedal*", "Node3D", true, false):
		pedals.append(n as Node3D)
	skeleton = _find_type(rider,"Skeleton3D") as Skeleton3D
	if skeleton != null:
		for pedal in pedals:
			var side := "L" if pedal.name == "PedalL" else "R"
			var bone := skeleton.find_bone("foot_" + side)
			var rest_point := Vector3(-0.22 if side == "L" else 0.22, 0.285, -0.1)
			pedal_anchors[pedal.name] = {"bone":bone,"point":skeleton.get_bone_global_rest(bone).affine_inverse() * rest_point}
		skeleton.skeleton_updated.connect(_sync_pedals)
	_play("idle")

func _find_type(n: Node, type_name: String) -> Node:
	if n.is_class(type_name): return n
	for child in n.get_children():
		var found := _find_type(child, type_name)
		if found != null: return found
	return null

func _play(clip: String) -> void:
	if animator == null: return
	for key in animator.get_animation_list():
		if str(key).get_slice("/", str(key).get_slice_count("/") - 1) == clip:
			if current_clip != clip:
				current_clip = clip
				animator.get_animation(key).loop_mode = Animation.LOOP_LINEAR
				animator.play(key, 0.16)
			return

func set_motion(speed: float, steering: float, braking: bool, delta: float) -> void:
	if not is_instance_valid(rider): build()
	var clip := "idle"
	if braking and absf(speed) > 0.1: clip = "brake"
	elif absf(steering) > 0.25: clip = "steer_left" if steering < 0.0 else "steer_right"
	elif absf(speed) > 0.1: clip = "pedal"
	_play(clip)
	if animator != null:
		animator.speed_scale = clampf(absf(speed) / 3.0, 0.35, 2.4) if clip == "pedal" else 1.0
	for wheel in wheels:
		wheel.rotate_x(-speed * maxf(delta, 0.0) / 0.29)

	_sync_pedals()

func _sync_pedals() -> void:
	if not is_inside_tree() or not is_instance_valid(skeleton) or not skeleton.is_inside_tree(): return
	for pedal in pedals:
		if not is_instance_valid(pedal) or not pedal.is_inside_tree():continue
		var anchor: Dictionary = pedal_anchors[pedal.name]
		pedal.global_position = skeleton.global_transform * skeleton.get_bone_global_pose(anchor.bone) * anchor.point
