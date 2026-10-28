extends Node3D
## Original clay otter. Imported Skeleton3D/Skin and six bone-animation clips.
var _player: AnimationPlayer
var _speed := 0.0
var _state := "idle"
var _clip := ""
func _ready() -> void:
	_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player:
		for key in _player.get_animation_list():
			_player.get_animation(key).loop_mode = Animation.LOOP_LINEAR
		_select("idle")
func set_motion(speed: float, _dt: float) -> void:
	_speed = speed
	if _state in ["idle", "walk"]:
		_select("walk" if speed > 0.08 else "idle")
func set_state(state: String, _progress: float = 0.0) -> void:
	if state == "bracing" or state == "sheltered": state = "shelter"
	if state == "success": state = "victory"
	_state = state if state in ["idle", "walk", "shelter", "interact", "hurt", "victory"] else "idle"
	_select("walk" if _state == "idle" and _speed > 0.08 else _state)
func _select(wanted: String) -> void:
	if not _player: return
	_player.speed_scale = clampf(_speed / 2.8, 0.5, 1.65) if wanted == "walk" else 1.0
	if _clip == wanted: return
	for key in _player.get_animation_list():
		if String(key).get_slice("/", String(key).get_slice_count("/")-1) == wanted:
			_player.play(key, 0.15)
			_clip = wanted
			return
