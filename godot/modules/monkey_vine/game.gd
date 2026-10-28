extends Node3D
## Host-compatible side-view runtime. Rules own all simulation, visuals only read it.
signal exit_requested
const RULES_PATH := "res://modules/monkey_vine/rules/rules.gd"
const Storage := preload("res://modules/monkey_vine/storage.gd")
const FIXED_DT := 1.0 / 120.0
var rules: RefCounted
var storage := Storage.new()
var camera: Camera3D
var presentation: Node
var character: Node3D
var hud: Node
var sound: Node
var started := false
var paused := false
var exiting := false
var volume := 0.65
var context: Dictionary = {}
var _standalone := false
var _old_auto_quit := true
var _accumulator := 0.0
var _latest: Dictionary = {}
var _pending_keys: Array[Dictionary] = []
var _held := {"left":false,"right":false,"grab":false}
var _camera_ready := false
var _zoom := 10.0
var _visual_events: Array = []

func _ready() -> void:
	call_deferred("_standalone_autostart")

func _standalone_autostart() -> void:
	if not started and get_tree().current_scene == self:
		start({})

func start(start_context: Dictionary) -> void:
	if started or exiting: return
	started = true
	context = start_context.duplicate()
	_standalone = get_tree().current_scene == self
	if _standalone:
		_old_auto_quit = get_tree().auto_accept_quit
		get_tree().auto_accept_quit = false
	if not ResourceLoader.exists(RULES_PATH):
		push_error("Monkey rules unavailable; cannot start simulation")
		return
	rules = load(RULES_PATH).new()
	rules.configure(271828, 0)
	var saved := storage.load_profile(context)
	if not saved.is_empty():
		volume = float(saved.get("volume", 0.65))
		if not rules.import_progress(saved.get("progress", {})):
			storage.invalidate("进度数据无效；原存档保留，本次不会覆盖")
	_latest = rules.snapshot()
	_build_camera()
	_build_lighting()
	_build_presentation()
	_build_character()
	_build_hud()
	_build_audio()
	_render(0.0)
	_status(storage.warning if not storage.warning.is_empty() else "空格起跳，按住抓藤；松手飞出，再按抓下一根")

func snapshot() -> Dictionary:
	return _latest.duplicate(true)

func _process(delta: float) -> void:
	if not started or exiting or rules == null: return
	if not paused:
		_accumulator += maxf(0.0, delta)
		var count := 0
		while _accumulator + 0.0000001 >= FIXED_DT and count < 32:
			_latest = rules.step(FIXED_DT, _consume_input())
			_accumulator -= FIXED_DT
			count += 1
			_process_events(_latest.get("events", []))
	_render(0.0 if paused else delta)

func _consume_input() -> Dictionary:
	var pressed := false
	var released := false
	while not _pending_keys.is_empty():
		var event: Dictionary = _pending_keys.pop_front()
		var key: String = event.key
		var down: bool = event.down
		if key == "grab":
			if down and not _held.grab: pressed = true
			if not down and _held.grab: released = true
			_held.grab = down
			# Preserve a press and release arriving within one display frame.
			if pressed or released: break
		else:
			_held[key] = down
	return {"left":_held.left,"right":_held.right,"grab_held":_held.grab,"grab_pressed":pressed,"grab_released":released}

func _key_name(key: int) -> String:
	if key == KEY_LEFT or key == KEY_A: return "left"
	if key == KEY_RIGHT or key == KEY_D: return "right"
	if key == KEY_SPACE: return "grab"
	return ""

func _input(event: InputEvent) -> void:
	# Releases cannot get trapped by a newly-focused UI button.
	if not started or exiting: return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		# Consume module-level menu commands in _input, before any host/root
		# _unhandled_input observer can see them. Mark handled before UI mutation.
		if code in [KEY_ESCAPE, KEY_P, KEY_R]:
			var viewport := get_viewport()
			viewport.set_input_as_handled()
			if event.pressed and not event.echo:
				if code == KEY_R: request_retry()
				else: request_pause(not paused)
			return
		if code in [KEY_ENTER, KEY_KP_ENTER] and str(_latest.get("phase", "")) == "segment_clear":
			get_viewport().set_input_as_handled()
			if event.pressed and not event.echo: request_continue()
			return
	if event is InputEventKey and not event.pressed and not event.echo:
		var key := _key_name(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		if not key.is_empty():
			if not paused: _pending_keys.append({"key":key,"down":false})
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not started or exiting or rules == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		var viewport := get_viewport()
		if code == KEY_ESCAPE or code == KEY_P:
			viewport.set_input_as_handled()
			request_pause(not paused)
			return
		if code == KEY_R:
			viewport.set_input_as_handled()
			request_retry()
			return
		if code == KEY_ENTER and str(_latest.get("phase", "")) == "segment_clear":
			viewport.set_input_as_handled()
			request_continue()
			return
		var key := _key_name(code)
		if not key.is_empty() and not paused:
			viewport.set_input_as_handled()
			_pending_keys.append({"key":key,"down":true})
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + (-0.5 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.5), 8.0, 14.0)
			get_viewport().set_input_as_handled()

func request_pause(value: bool) -> void:
	if exiting or not started: return
	paused = value
	if character != null: character.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	_clear_input()
	_accumulator = 0.0
	if hud != null and hud.has_method("set_paused"): hud.set_paused(paused)
	if sound != null and sound.has_method("set_paused"): sound.set_paused(paused)
	if paused: _save()

func request_retry() -> void:
	if rules == null or exiting: return
	rules.restart_checkpoint()
	_latest = rules.snapshot()
	request_pause(false)
	_camera_ready = false
	_status("已回到最近树屋；空格起跳")
	_render(0.0)

func request_continue() -> void:
	if rules == null or exiting: return
	if paused:
		request_pause(false)
		return
	if str(_latest.get("phase", "")) != "segment_clear": return
	if rules.has_method("advance_segment"): rules.advance_segment()
	_latest = rules.snapshot()
	request_pause(false)
	_save()
	_render(0.0)

func request_exit() -> void:
	if exiting: return
	exiting = true
	_clear_input()
	_save()
	if sound != null and sound.has_method("stop_all"): sound.stop_all()
	if _standalone:
		call_deferred("_quit_standalone")
	else:
		exit_requested.emit()

func _quit_standalone() -> void:
	if not is_inside_tree(): return
	await get_tree().create_timer(0.4).timeout
	if is_inside_tree(): get_tree().quit()

func _save() -> void:
	if rules == null: return
	storage.save_profile(rules.export_progress(), volume)
	if not storage.warning.is_empty(): _status(storage.warning)

func _clear_input() -> void:
	_pending_keys.clear()
	_held = {"left":false,"right":false,"grab":false}

func _notification(what: int) -> void:
	if not started or exiting: return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		request_pause(true)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _standalone: request_exit()
		elif context.get("quit_handler") is Callable and context.quit_handler.is_valid():
			_save()
			context.quit_handler.call()

func _exit_tree() -> void:
	if started and not exiting: _save()
	if sound != null and is_instance_valid(sound) and sound.has_method("stop_all"): sound.stop_all()
	if _standalone: get_tree().auto_accept_quit = _old_auto_quit

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "SideCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _zoom
	camera.near = 0.1
	camera.far = 100.0
	add_child(camera)
	camera.current = true

func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("9ac4b4")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("cce4cf")
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	if _standalone:
		var world := WorldEnvironment.new()
		world.name = "JungleWorld"
		world.environment = environment
		add_child(world)
	# Explicit camera environment also makes host World's settings irrelevant.
	camera.environment = environment
	var sun := DirectionalLight3D.new()
	sun.name = "CanopySun"
	sun.rotation_degrees = Vector3(-32.0, -28.0, 0.0)
	sun.light_color = Color("fff0ce")
	sun.light_energy = 0.35
	sun.shadow_enabled = true
	add_child(sun)

func _instantiate_optional(path: String) -> Node:
	if not ResourceLoader.exists(path): return null
	var resource = load(path)
	if resource is PackedScene: return resource.instantiate()
	if resource is Script: return resource.new()
	return null

func _build_presentation() -> void:
	presentation = _instantiate_optional("res://modules/monkey_vine/art/environment/jungle_environment.gd")
	if presentation == null: return
	add_child(presentation)
	if presentation.has_method("build"): presentation.build(_latest)

func _build_character() -> void:
	character = _instantiate_optional("res://modules/monkey_vine/art/character/monkey.tscn") as Node3D
	if character == null: return
	add_child(character)

func _build_hud() -> void:
	hud = _instantiate_optional("res://modules/monkey_vine/ui/jungle_hud.gd")
	if hud == null: return
	add_child(hud)
	if hud.has_method("set_hosted"): hud.set_hosted(not _standalone)
	if hud.has_method("set_volume"): hud.set_volume(volume)
	for pair in [["pause_requested", "_toggle_pause"], ["retry_requested", "request_retry"], ["exit_requested", "request_exit"], ["continue_requested", "request_continue"], ["volume_changed", "_set_volume"]]:
		if hud.has_signal(pair[0]): hud.connect(pair[0], Callable(self, pair[1]))

func _build_audio() -> void:
	sound = _instantiate_optional("res://modules/monkey_vine/audio/jungle_audio.gd")
	if sound == null: return
	add_child(sound)
	if sound.has_method("set_volume"): sound.set_volume(volume)
	if sound.has_method("music_start"): sound.music_start()

func _toggle_pause() -> void:
	request_pause(not paused)

func _set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	if hud != null and hud.has_method("set_volume"): hud.set_volume(volume)
	if sound != null and sound.has_method("set_volume"): sound.set_volume(volume)

func _status(message: String) -> void:
	if hud != null and hud.has_method("show_status"): hud.show_status(message)

func _process_events(events: Array) -> void:
	_visual_events.append_array(events)
	for event in events:
		if sound != null and sound.has_method("play_event"): sound.play_event(str(event.get("type", "")))
		if str(event.get("type", "")) in ["checkpoint", "segment_clear"]: _save()

func _render(delta: float) -> void:
	if camera == null or _latest.is_empty(): return
	var pos: Vector2 = _latest.get("player_pos", Vector2.ZERO)
	var vel: Vector2 = _latest.get("player_vel", Vector2.ZERO)
	var target := Vector3(pos.x + clampf(vel.x * 0.15 + 2.4, 0.5, 4.0), maxf(2.8, pos.y + 0.7), 20.0)
	if not _camera_ready:
		camera.position = target
		_camera_ready = true
	else:
		camera.position = camera.position.lerp(target, 1.0-exp(-delta*4.0))
	camera.size = lerpf(camera.size, _zoom, 1.0-exp(-delta*5.0))
	if presentation != null and presentation.has_method("update_snapshot"): presentation.update_snapshot(_latest, delta)
	if character != null:
		character.position = Vector3(pos.x,pos.y,0)
		if character.has_method("set_pose"):
			var visual_snapshot := _latest.duplicate()
			visual_snapshot.events = _visual_events
			character.set_pose(visual_snapshot)
	if hud != null and hud.has_method("update_snapshot"): hud.update_snapshot(_latest)
	_visual_events.clear()
