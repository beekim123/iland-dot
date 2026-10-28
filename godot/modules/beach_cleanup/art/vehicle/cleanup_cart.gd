extends Node3D
## Original articulated cleanup miniature. Forward -Z, +Y up. API uses local target.
const TRASH_PATH := "res://modules/beach_cleanup/art/trash/"
var _shoulder: Node3D
var _elbow: Node3D
var _wrist: Node3D
var _slide: Node3D
var _left: Node3D
var _right: Node3D
var _wheels: Array[Node3D] = []
var _cargo_root: Node3D
var _wheel_spin := 0.0
var _ready_model := false
var _cargo_signature := "__uninitialized__"

func _ready() -> void:
	preload("res://modules/beach_cleanup/art/trash/trash_visual.gd").apply_palette(self)
	_shoulder = find_child("Shoulder", true, false) as Node3D
	_elbow = find_child("Elbow", true, false) as Node3D
	_wrist = find_child("Wrist", true, false) as Node3D
	_slide = find_child("TelescopicSlide", true, false) as Node3D
	_left = find_child("LeftJaw", true, false) as Node3D
	_right = find_child("RightJaw", true, false) as Node3D
	for wheel_name in ["WheelLFront", "WheelRFront", "WheelLRear", "WheelRRear"]:
		var wheel := find_child(wheel_name, true, false) as Node3D
		if wheel:
			_wheels.append(wheel)
	_cargo_root = Node3D.new()
	_cargo_root.name = "VisibleCargo"
	add_child(_cargo_root)
	_ready_model = true
	set_grab(0.0, Vector3(0, 0.18, -1.12))

func set_motion(speed: float, steering: float, dt: float) -> void:
	_wheel_spin += speed * dt / 0.235
	for wheel in _wheels:
		wheel.rotation.x = -_wheel_spin
		wheel.rotation.y = clampf(steering, -1.0, 1.0) * 0.23 if wheel.name.ends_with("Front") else 0.0

func set_grab(progress: float, target_local: Vector3) -> void:
	if not _ready_model or not _shoulder or not _elbow:
		return
	var p := clampf(progress, 0.0, 1.0)
	# Reach on first half, grip, then lift into the basket. Real two-link IK.
	var idle := Vector3(0.0, 1.02, -0.93)
	var toward_base := Vector3(-target_local.x, 0, -0.29 - target_local.z).normalized()
	var horizontal_to_target := Vector2(target_local.x, target_local.z + 0.29).length()
	var grip_pitch := lerpf(-PI * 0.5, -0.25, smoothstep(0.15, 0.45, horizontal_to_target))
	var pickup := target_local + Vector3(0, -sin(grip_pitch) * 0.25, 0) + toward_base * (cos(grip_pitch) * 0.25)
	var lifted := Vector3(target_local.x * 0.5, 1.30, -0.70)
	var basket := Vector3(0, 1.20, 0.24)
	var desired: Vector3
	if p <= 0.5:
		desired = idle.lerp(pickup, smoothstep(0.0, 0.5, p))
	elif p <= 0.65:
		desired = pickup.lerp(lifted, smoothstep(0.5, 0.65, p))
	elif p <= 0.85:
		var sweep := smoothstep(0.65, 0.85, p)
		desired = lifted.lerp(basket, sweep) + Vector3(0.16 * sin(sweep * PI), 0, 0)
	else:
		var sweep := smoothstep(0.85, 1.0, p)
		desired = basket.lerp(idle, sweep) + Vector3(0.16 * sin(sweep * PI), 0, 0)
	var delta := desired - _shoulder.position
	var planar := Vector2(Vector2(delta.x, delta.z).length(), delta.y)
	var forearm := clampf(planar.length() - 0.48 + 0.04, 0.45, 1.15)
	var extension := forearm - 0.45
	_wrist.position.z = -forearm
	if _slide:
		_slide.position.z = -(0.325 + extension * 0.5)
		_slide.scale.z = (0.25 + extension) / 0.25
	var distance := clampf(planar.length(), 0.15, 0.48 + forearm - 0.001)
	var bend := acos(clampf((distance * distance - 0.48 * 0.48 - forearm * forearm) / (2.0 * 0.48 * forearm), -1.0, 1.0))
	var angle := atan2(planar.y, planar.x) + atan2(forearm * sin(bend), 0.48 + forearm * cos(bend))
	_shoulder.rotation = Vector3(angle, atan2(-delta.x, -delta.z), 0)
	_elbow.rotation.x = -bend
	_wrist.rotation.x = -angle + bend + grip_pitch
	var opening := 0.5 * maxf(1.0 - smoothstep(0.25, 0.5, p), smoothstep(0.82, 0.9, p))
	_left.rotation.y = opening
	_right.rotation.y = -opening

func set_cargo(cargo_items: Array) -> void:
	if not _cargo_root:
		return
	var signature := JSON.stringify(cargo_items)
	if signature == _cargo_signature:
		return
	_cargo_signature = signature
	for child in _cargo_root.get_children():
		_cargo_root.remove_child(child)
		child.queue_free()
	for i in range(mini(cargo_items.size(), 12)):
		var item = cargo_items[i]
		var kind: String = str(item.get("kind", "bottle")) if item is Dictionary else str(item)
		if kind not in ["bottle", "can", "wrapper", "sandal", "crate", "net"]:
			kind = "bottle"
		var resource := load(TRASH_PATH + kind + ".tscn") as PackedScene
		if not resource:
			continue
		var model := resource.instantiate() as Node3D
		_cargo_root.add_child(model)
		model.position = Vector3(-0.23 + float(i % 3) * 0.23, 0.72 + float(i / 6) * 0.15, 0.14 + float((i / 3) % 2) * 0.22)
		model.scale = Vector3.ONE * (0.46 if kind in ["crate", "net"] else 0.7)
		model.rotation.y = float(i) * 1.7

func get_grip_world_position() -> Vector3:
	return _wrist.to_global(Vector3(0, 0, -0.25)) if _wrist else global_position
