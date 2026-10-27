extends Node3D
## A real weighted Blender mesh. Eight-bone local poses compose swim, gulp,
## acceleration and turning without replacing runtime-owned world transforms.
const FISH_DIR := "res://modules/tide_gulp/art/fish/"
const PAINT = preload("res://modules/tide_gulp/shaders/watercolor.gdshader")
var species_id := "moonfish"
var stage := 0
var skeleton: Skeleton3D
var model: Node3D
var _variants: Dictionary = {}
var _speed := 0.0
var _turn := 0.0
var _mouth := 0.0
var _hit := 0.0
var _dash := 0.0
var _phase := 0.0
var _last_wash := -1.0
var _bone_ids: Dictionary = {}
var _material: ShaderMaterial

func setup(species: String, initial_stage: int = 0) -> void:
	species_id = species
	stage = clampi(initial_stage, 0, 5)
	_phase = float(posmod(species.hash(), 107)) * 0.071
	_material = ShaderMaterial.new()
	_material.shader = PAINT
	_material.set_shader_parameter("paper_strength", 0.027)
	_material.set_shader_parameter("pigment_strength", 0.09)
	if species_id == "moonfish":
		for detail in range(3): _load_model("moonfish_%d" % detail)
	_load_model(_model_id(stage))

func _model_id(s: int) -> String:
	return "moonfish_%d" % mini(2, s / 2) if species_id == "moonfish" else species_id

func _load_model(file_id: String) -> void:
	if model != null: model.visible = false
	if _variants.has(file_id):
		model = _variants[file_id]
	else:
		var path := FISH_DIR + file_id + ".glb"
		if not ResourceLoader.exists(path): path = FISH_DIR + "moonfish_0.glb"
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("Tide fish missing: " + path)
			return
		model = packed.instantiate() as Node3D
		add_child(model)
		_apply_paint(model)
		_variants[file_id] = model
	model.visible = true
	skeleton = _find_skeleton(model)
	_bone_ids.clear()
	if skeleton:
		for bone in ["head", "spine_a", "spine_b", "spine_c", "tail", "jaw", "pectoral_l", "pectoral_r"]:
			_bone_ids[bone] = skeleton.find_bone(bone)

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found: return found
	return null

func _apply_paint(root: Node) -> void:
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = _material
		(root as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children(): _apply_paint(child)

func set_stage(new_stage: int) -> void:
	var wanted := clampi(new_stage, 0, 5)
	if wanted == stage: return
	var old_id := _model_id(stage)
	stage = wanted
	if _model_id(stage) != old_id: _load_model(_model_id(stage))

func set_motion(speed: float, turn: float, mouth: float, hit: float, dash: Variant) -> void:
	_speed = clampf(speed, 0.0, 20.0)
	_turn = clampf(turn, -1.5, 1.5)
	_mouth = clampf(mouth, 0.0, 1.0)
	_hit = clampf(hit, 0.0, 1.0)
	_dash = 1.0 if bool(dash) else 0.0

func _pose(bone: String, axis: Vector3, angle: float, lift: float = 0.0) -> void:
	var idx: int = _bone_ids.get(bone, -1)
	if idx >= 0:
		var rest_rotation := skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(idx, rest_rotation * Quaternion(axis, angle) * Quaternion(Vector3.RIGHT, lift))

func tick_pose(delta: float, time: float) -> void:
	if skeleton == null: return
	# Local Z of each Blender bone is the fish's up axis after glTF conversion.
	# Increasing amplitudes and traveling phase yield a smooth caudal wave.
	var activity := clampf(_speed / 5.0, 0.0, 1.0)
	var freq := 3.0 + activity * 5.1 + _dash * 3.2
	_phase += delta * freq
	var amp := 0.055 + activity * 0.085 + _dash * 0.055
	_pose("head", Vector3.BACK, sin(_phase) * amp * .13 + _turn * .04)
	_pose("spine_a", Vector3.BACK, sin(_phase - .48) * amp * .40 - _turn * .055, sin(_phase - .48) * amp * .09)
	_pose("spine_b", Vector3.BACK, sin(_phase - 1.0) * amp * .90 - _turn * .09, sin(_phase - 1.0) * amp * .16)
	_pose("spine_c", Vector3.BACK, sin(_phase - 1.58) * amp * 1.30 - _turn * .10, sin(_phase - 1.58) * amp * .23)
	_pose("tail", Vector3.BACK, sin(_phase - 2.12) * amp * 1.75 - _turn * .13, sin(_phase - 2.12) * amp * .32)
	_pose("jaw", Vector3.RIGHT, -_mouth * .72 - .035 * (.5 + .5 * sin(time * 2.1)))
	_pose("pectoral_l", Vector3.UP, sin(_phase * .72) * .23 + .13 + _dash * .18)
	_pose("pectoral_r", Vector3.UP, -sin(_phase * .72 + .7) * .23 - .13 - _dash * .18)
	# Brief squash belongs to the mesh, never runtime's authoritative length.
	model.scale = Vector3(1.0 + _mouth * .015, 1.0 - _dash * .035 + _mouth * .055, 1.0 + _mouth * .055)
	model.position.y = sin(time * 4.0) * _hit * .028
	var wash := .10 + _hit * .32
	if not is_equal_approx(wash, _last_wash):
		_material.set_shader_parameter("wash_strength", wash)
		_last_wash = wash
