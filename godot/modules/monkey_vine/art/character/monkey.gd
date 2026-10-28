extends Node3D
## Visual-only rig adapter. Rules retain sole ownership of motion.
@onready var model: Node3D = $Model
@onready var grip_marker: Marker3D = $GripMarker
var skeleton: Skeleton3D
var player: AnimationPlayer
var current_clip := ""
var attached := false
var desired_grip := Vector3(0, 0.45, 0)
var hand_near := -1
var hand_far := -1

func _ready() -> void:
	skeleton = _find_type(model, "Skeleton3D") as Skeleton3D
	player = _find_type(model, "AnimationPlayer") as AnimationPlayer
	if skeleton:
		hand_near = skeleton.find_bone("handNear")
		hand_far = skeleton.find_bone("handFar")
		skeleton.skeleton_updated.connect(_sync_grip)
	if player:
		for clip in ["idle", "run", "swing", "air", "fall"]:
			var key := _key(clip)
			if not key.is_empty(): player.get_animation(key).loop_mode = Animation.LOOP_LINEAR
		play_pose("idle")

func _find_type(node: Node, type: String) -> Node:
	if node.is_class(type): return node
	for child in node.get_children():
		var found := _find_type(child, type)
		if found: return found
	return null

func _key(clip: String) -> String:
	if not player: return ""
	for key in player.get_animation_list():
		if key == clip or key.get_slice("/", key.get_slice_count("/") - 1) == clip: return key
	return ""

func play_pose(clip: String) -> void:
	if clip == current_clip: return
	var key := _key(clip)
	if key.is_empty(): return
	current_clip = clip
	attached = clip == "grab" or clip == "swing"
	model.position = Vector3.ZERO
	player.play(key, 0.0 if attached else 0.10)

func set_pose(snapshot: Dictionary) -> void:
	if not is_node_ready(): return
	var face := int(snapshot.get("facing", 1))
	model.scale.x = -1.0 if face < 0 else 1.0
	var velocity: Vector2 = snapshot.get("player_vel", Vector2.ZERO)
	var pos: Vector2 = snapshot.get("player_pos", Vector2.ZERO)
	var grip: Vector2 = snapshot.get("grip_pos", pos + Vector2(0, 0.45))
	desired_grip = Vector3(grip.x - pos.x, grip.y - pos.y, 0)
	if not str(snapshot.get("vine_id", "")).is_empty():
		if current_clip != "grab" or not player.is_playing(): play_pose("swing")
	elif bool(snapshot.get("grounded", false)):
		if current_clip != "land" or not player.is_playing(): play_pose("run" if absf(velocity.x) > 0.1 else "idle")
	else: play_pose("fall" if velocity.y < -2.0 else "air")
	for event in snapshot.get("events", []):
		if event.get("type", "") == "land": play_pose("land")
		elif event.get("type", "") == "grab": play_pose("grab")

func _sync_grip() -> void:
	if not is_inside_tree() or not is_instance_valid(skeleton) or not skeleton.is_inside_tree(): return
	if hand_near < 0 or hand_far < 0: return
	var center := (skeleton.get_bone_global_pose(hand_near).origin + skeleton.get_bone_global_pose(hand_far).origin) * 0.5
	var actual := to_local(skeleton.to_global(center))
	if attached:
		model.position += desired_grip - actual
		actual = to_local(skeleton.to_global(center))
	grip_marker.position = actual

func get_grip_error() -> float:
	_sync_grip()
	return grip_marker.position.distance_to(desired_grip)
