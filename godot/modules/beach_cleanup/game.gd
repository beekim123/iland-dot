extends Node3D
## Independent presentation/storage boundary; sim.gd owns all gameplay mutations.
signal exit_requested
const Simulation = preload("sim.gd")
const Maps = preload("data/maps.gd")
const GAME_ID := "beach_cleanup"
const SCHEMA_VERSION := 1
const SAVE_DIR := "user://games/beach_cleanup"
const SAVE_PATH := SAVE_DIR + "/profile.json"
const FIXED_DT := 1.0 / 60.0
var sim = Simulation.new()
var world: Node3D
var cart: Node3D
var trash_root: Node3D
var trash_nodes: Dictionary = {}
var camera: Camera3D
var postcard_camera: Camera3D
var camera_focus := Vector3.ZERO
var camera_zoom := 16.0
var hud
var audio
var retired_audio: WeakRef
var running := false
var has_started := false
var paused := false
var pending_context: Dictionary = {}
var keys: Dictionary = {}
var grabbing := false
var unload_pending := false
var accumulator := 0.0
var autosave_left := 2.0
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var previous_auto_accept_quit := true
var owns_quit_policy := false
var window_shutdown_pending := false
var quit_handler: Callable
var save_service: Object
var profile: Dictionary = {}
var save_write_allowed := true
var save_status := ""
var context_valid := true
var loaded_disk_bytes := ""
var loaded_disk_existed := false
var latest_snapshot: Dictionary = {}
var before_texture: Texture2D
var after_texture: Texture2D
var postcard_pending := false
var result_shown := false
var demo_mode := false
var demo_route := PackedVector2Array()
var demo_stage := "plan"
var demo_target := ""
var hint_marker: MeshInstance3D
var hint_left := 0.0
var message_left := 0.0
var capacity_message := ""
var demo_map := 0
var demo_variant := 0
var demo_ticks := 0
var demo_speed := 1.0
var capture_phase := ""
var pickup_left := 0.0
var pickup_target := Vector3.ZERO
var pickup_visual: Node3D
var pickup_id := ""
var elapsed := 0.0
var capture_path := ""
var capture_after := 2.0
var capture_done := false
var record_dir := ""
var record_frames := 120
var record_fps := 12.0
var recorded_frames := 0
var record_after := 0.0
var next_record_time := 0.0
var trace_path := ""

func _ready() -> void:
	_parse_arguments()
	_build_presentation()
	call_deferred("autostart")

func autostart() -> void:
	if not has_started: start(pending_context)

func _build_presentation() -> void:
	camera = Camera3D.new()
	camera.name = "MiniatureCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 160
	add_child(camera)
	camera.position = Vector3(30,40,30)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	postcard_camera = Camera3D.new()
	postcard_camera.name = "FixedPostcardCamera"
	postcard_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	postcard_camera.near = 0.1
	postcard_camera.far = 160
	add_child(postcard_camera)
	postcard_camera.position = Vector3(30,40,30)
	postcard_camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52,-28,0)
	light.light_color = Color("fff2d6")
	light.light_energy = 0.6
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 85
	add_child(light)
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("a9bfba")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d5e7ed")
	settings.ambient_light_energy = 0.25
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	camera.environment = settings
	postcard_camera.environment = settings
	var hud_script = load("res://modules/beach_cleanup/ui/beach_hud.gd")
	if hud_script:
		hud = hud_script.new()
		var layer := CanvasLayer.new()
		add_child(layer)
		layer.add_child(hud)
		hud.pause_requested.connect(func(): set_paused(true))
		hud.resume_requested.connect(func(): set_paused(false))
		hud.return_requested.connect(leave_game)
		hud.replay_requested.connect(replay)
		hud.next_requested.connect(next_beach)
		hud.hint_requested.connect(show_hint)
		hud.ui_clicked.connect(func():
			if is_instance_valid(audio): audio.cue("click")
		)
	var audio_script = load("res://modules/beach_cleanup/audio/beach_audio.gd")
	if audio_script:
		audio = audio_script.new()
		add_child(audio)

func start(context: Dictionary = {}) -> void:
	if not is_node_ready():
		pending_context = context.duplicate()
		return
	if running: save_data()
	if not running: previous_mouse_mode = Input.mouse_mode
	has_started = true
	window_shutdown_pending = false
	quit_handler = context.get("quit_handler",Callable())
	if not owns_quit_policy:
		previous_auto_accept_quit = get_tree().auto_accept_quit
		owns_quit_policy = true
	get_tree().auto_accept_quit = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	context_valid = str(context.get("game_id",GAME_ID)) == GAME_ID and _number(context.get("schema_version",SCHEMA_VERSION),SCHEMA_VERSION,SCHEMA_VERSION) and (not context.has("save_root") or (context["save_root"] is String and context["save_root"] == SAVE_DIR + "/"))
	save_service = context.get("save_service",null)
	load_data()
	if demo_mode:
		sim.start(demo_map,demo_variant)
		profile = _fresh_profile()
	elif not profile.snapshot.is_empty():
		if not sim.restore(profile.snapshot): _disable_save("记录内容不完整，原文件已保留"); sim.start()
	else: sim.start()
	running = true
	paused = false
	result_shown = false
	clear_input()
	accumulator = 0
	elapsed = 0
	set_process(true)
	set_process_unhandled_input(true)
	set_process_input(true)
	_build_map()
	if hud:
		if hud.has_method("reset_session"): hud.reset_session()
		hud.show()
	if not is_instance_valid(audio):
		audio = load("res://modules/beach_cleanup/audio/beach_audio.gd").new()
		add_child(audio)
	if audio: audio.set_paused(false)
	demo_stage = "plan"
	demo_route.clear()
	_update_presentation(0)
	_prepare_postcards()

func _build_map() -> void:
	hint_left = 0.0
	pickup_left = 0.0
	pickup_id = ""
	pickup_visual = null
	if is_instance_valid(world): remove_child(world); world.queue_free()
	if is_instance_valid(cart): remove_child(cart); cart.queue_free()
	if is_instance_valid(trash_root): remove_child(trash_root); trash_root.queue_free()
	world = load("res://modules/beach_cleanup/art/environment/beach_environment.gd").new()
	add_child(world)
	world.build(sim.map_data)
	cart = load("res://modules/beach_cleanup/art/vehicle/cleanup_cart.tscn").instantiate()
	add_child(cart)
	trash_root = Node3D.new()
	trash_root.name = "CollectibleTrash"
	add_child(trash_root)
	trash_nodes.clear()
	for item: Dictionary in sim.map_data.trash:
		var asset = load("res://modules/beach_cleanup/art/trash/" + str(item.type) + ".tscn")
		if asset == null: continue
		var node: Node3D = asset.instantiate()
		node.name = item.id
		node.position = Vector3(item.pos.x,0.08,item.pos.y)
		trash_root.add_child(node)
		trash_nodes[item.id] = node
	postcard_camera.size = [32.0,35.0,41.0][sim.map_id]
	camera.size = camera_zoom
	camera_focus = Vector3(sim.pos.x,0,sim.pos.y)
	_follow_camera(0,true)
	if is_instance_valid(hint_marker): hint_marker.queue_free()
	hint_marker = MeshInstance3D.new()
	var marker_mesh := CylinderMesh.new()
	marker_mesh.top_radius = 0
	marker_mesh.bottom_radius = 0.38
	marker_mesh.height = 0.8
	hint_marker.mesh = marker_mesh
	var marker_material := StandardMaterial3D.new()
	marker_material.albedo_color = Color("f4e5a4")
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hint_marker.material_override = marker_material
	hint_marker.rotation.z = PI
	hint_marker.hide()
	add_child(hint_marker)

func clear_input() -> void:
	keys.clear()
	grabbing = false
	unload_pending = false
	sim.command({"move":Vector2.ZERO,"grab":false,"unload":false})

func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey:
		if event.echo: return
		if event.keycode == KEY_ESCAPE and event.pressed:
			if hud: hud.handle_escape()
			else: set_paused(not paused)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_W,KEY_A,KEY_S,KEY_D]: keys[event.physical_keycode] = event.pressed
		elif event.physical_keycode == KEY_E and event.pressed: unload_pending = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: grabbing = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			camera_zoom = clampf(camera_zoom + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1),12,24)
			camera.size = camera_zoom

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and has_started: request_application_quit()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and running: set_paused(true)

func set_paused(value: bool) -> void:
	if not running: return
	if sim.phase == "complete" and result_shown:
		clear_input()
		return
	paused = value
	clear_input()
	sim.command({"pause":value})
	if hud:
		if value: hud.show_pause()
		else: hud.hide_modal()
	if audio and audio.has_method("set_paused"): audio.set_paused(value)
	if value: save_data()

func _process(dt: float) -> void:
	if not running: return
	elapsed += dt
	if not paused and not postcard_pending:
		accumulator = minf(accumulator + dt * (demo_speed if demo_mode else 1.0),2.0 if demo_mode else 0.25)
		while accumulator >= FIXED_DT:
			var move := Vector2(float(keys.get(KEY_D,false))-float(keys.get(KEY_A,false)),float(keys.get(KEY_S,false))-float(keys.get(KEY_W,false)))
			# Screen right=(+X,-Z), screen down=(+X,+Z).
			move = Vector2(move.x + move.y,move.y - move.x).normalized() if move.length_squared() > 0 else Vector2.ZERO
			var command := {"move":move,"grab":grabbing,"unload":unload_pending}
			if demo_mode: command = _demo_command()
			sim.command(command)
			sim.tick(FIXED_DT)
			demo_ticks += 1
			unload_pending = false
			accumulator -= FIXED_DT
			for event: Dictionary in sim.drain_events():
				if audio: audio.cue("ecology" if event.type == "zone_restored" else event.type)
				if event.type == "pickup": _begin_pickup_visual(event.id)
				if event.type == "capacity": capacity_message = "车厢不足 · 回站按 E 卸货"; message_left = 3.0
				if hud and hud.has_method("show_event"): hud.show_event(event)
				if event.type == "complete": _record_result()
				if event.type in ["pickup","unload","zone_restored","complete"]: save_data()
		_update_presentation(dt)
		autosave_left -= dt
		if autosave_left <= 0: save_data(); autosave_left = 2.0
	if sim.phase == "complete" and not result_shown and not postcard_pending: _finish_postcard()
	_capture_cli()

func _update_presentation(dt: float) -> void:
	latest_snapshot = sim.snapshot()
	latest_snapshot["speed"] = sim.speed
	latest_snapshot["capacity_used"] = sim.capacity_used()
	latest_snapshot["grab_progress"] = sim.grab_progress / sim.GRAB_TIME
	latest_snapshot["grab_target"] = sim.grab_target
	latest_snapshot["nearest_hint"] = _hint_target()
	latest_snapshot["title"] = sim.map_data.title
	latest_snapshot["subtitle"] = sim.map_data.subtitle
	latest_snapshot["total"] = sim.map_data.trash.size()
	latest_snapshot["save_status"] = save_status
	latest_snapshot["map_data"] = sim.map_data
	_follow_camera(dt)
	cart.position = Vector3(sim.pos.x,0.04,sim.pos.y)
	cart.rotation.y = sim.heading
	if cart.has_method("set_motion"): cart.set_motion(sim.speed,0.0,dt)
	var target := Vector3(0,0,-1.6)
	if not sim.grab_target.is_empty():
		var p: Vector2 = sim.item_by_id(sim.grab_target).pos
		target = cart.to_local(Vector3(p.x,0.15,p.y))
	pickup_left = maxf(0,pickup_left-dt)
	var grab_pose: float = sim.grab_progress / sim.GRAB_TIME * 0.5
	if pickup_left > 0:
		var phase := 1.0-pickup_left/0.45
		grab_pose = 0.5+phase*0.5
		target = pickup_target
		if is_instance_valid(pickup_visual):
			pickup_visual.position = Vector3(0,1.0,0.24) if phase > 0.7 else pickup_target
	elif is_instance_valid(pickup_visual): pickup_visual.queue_free(); pickup_visual = null; pickup_id = ""
	if cart.has_method("set_grab"): cart.set_grab(grab_pose,target)
	if pickup_left > 0.135 and is_instance_valid(pickup_visual) and cart.has_method("get_grip_world_position"):
		pickup_visual.global_position = cart.get_grip_world_position()
	var cargo: Array = []
	for id in sim.cargo:
		if id != pickup_id: cargo.append(sim.item_by_id(id).type)
	if cart.has_method("set_cargo"): cart.set_cargo(cargo)
	for id in trash_nodes: trash_nodes[id].visible = sim.remaining.has(id)
	world.update_state(latest_snapshot)
	hint_left = maxf(0,hint_left-dt)
	message_left = maxf(0,message_left-dt)
	if message_left <= 0: capacity_message = ""
	var hint: Dictionary = _hint_target()
	hint_marker.visible = hint_left > 0 and not hint.is_empty()
	if hint_marker.visible: hint_marker.position = Vector3(hint.pos.x,2.3+sin(elapsed*4)*0.2,hint.pos.y)
	var near := false
	for depot: Dictionary in sim.map_data.depots:
		if sim.pos.distance_to(depot.pos) <= float(depot.radius): near = true
	if hud: hud.update_state({"beach_name":sim.map_data.title,"cargo_used":sim.capacity_used(),"ground_remaining":sim.remaining.size(),"delivered":sim.delivered.size(),"zones_restored":sim.restored_zones.size(),"zones_total":sim.map_data.zones.size(),"depot_near":near,"save_status":save_status,"hint_text":("回卸货站按 E，卸下最后一车" if sim.remaining.is_empty() and not sim.cargo.is_empty() else ("跟随浅黄色箭头，绕过沙岩找残留" if hint_left > 0 else "")),"capacity_message":capacity_message})
	if audio and audio.has_method("tick"): audio.tick(dt,latest_snapshot)

func next_beach() -> void:
	if sim.phase != "complete": return
	_new_run((sim.map_id + 1) % 3,0)

func replay() -> void:
	_new_run(sim.map_id,(sim.variant + 1) % Maps.VARIANT_COUNT)

func _new_run(map_id: int, variant: int) -> void:
	profile.run_serial = int(profile.run_serial) + 1
	sim.start(map_id,variant)
	demo_stage = "plan"
	demo_route.clear()
	paused = false
	result_shown = false
	before_texture = null
	after_texture = null
	clear_input()
	if hud:
		if hud.has_method("reset_session"): hud.reset_session()
		else: hud.hide_modal()
	if audio and audio.has_method("set_paused"): audio.set_paused(false)
	_build_map()
	_update_presentation(0)
	save_data()
	_prepare_postcards()

func _record_result() -> void:
	if sim.phase != "complete": return
	var key := str(int(profile.run_serial))
	if profile.results.has(key): return
	profile.results[key] = {"map_id":sim.map_id,"variant":sim.variant,"distance":sim.distance,"unloads":sim.unloads,"items":sim.delivered.size()}
	save_data()

func _prepare_postcards() -> void:
	before_texture = null
	after_texture = null
	if DisplayServer.get_name() == "headless": return
	var file := SAVE_DIR + "/before_%d.png" % int(profile.run_serial)
	if save_write_allowed and not demo_mode and FileAccess.file_exists(file):
		var image := Image.load_from_file(file)
		if image and not image.is_empty(): before_texture = ImageTexture.create_from_image(image)
	if before_texture: return
	postcard_pending = true
	postcard_camera.make_current()
	if hud: hud.hide()
	cart.hide()
	# Reconstruct only the exact authored initial presentation if a resumed run
	# predates its screenshot. Never changes simulation state or item ownership.
	var baseline = Simulation.new()
	baseline.start(sim.map_id,sim.variant)
	world.update_state(baseline.snapshot())
	for node in trash_nodes.values(): node.show()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or not running: return
	var image := get_viewport().get_texture().get_image()
	if image and not image.is_empty():
		before_texture = ImageTexture.create_from_image(image)
		if save_write_allowed and not demo_mode:
			DirAccess.make_dir_recursive_absolute(SAVE_DIR)
			image.save_png(file)
	camera.make_current()
	cart.show()
	if hud: hud.show()
	_update_presentation(0)
	postcard_pending = false

func _finish_postcard() -> void:
	_record_result()
	result_shown = true
	if DisplayServer.get_name() != "headless":
		postcard_pending = true
		postcard_camera.make_current()
		hint_marker.hide()
		if hud: hud.hide()
		cart.hide()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		if not is_inside_tree() or not running: return
		var image := get_viewport().get_texture().get_image()
		if image and not image.is_empty(): after_texture = ImageTexture.create_from_image(image)
		camera.make_current()
		cart.show()
		if hud: hud.show()
		postcard_pending = false
	if hud:
		hud.show_completion(_completion_data(),before_texture,after_texture)

func leave_game() -> void:
	if not running: return
	save_data()
	_deactivate()
	if get_tree().current_scene == self and exit_requested.get_connections().is_empty(): request_application_quit()
	else: exit_requested.emit()

func _deactivate() -> void:
	running = false
	clear_input()
	sim.command({"pause":true})
	set_process(false)
	set_process_unhandled_input(false)
	set_process_input(false)
	Input.mouse_mode = previous_mouse_mode
	_retire_audio()
	if hud: hud.hide()
	if owns_quit_policy and get_tree() and not window_shutdown_pending:
		get_tree().auto_accept_quit = previous_auto_accept_quit
		owns_quit_policy = false

func request_application_quit() -> void:
	if window_shutdown_pending: return
	window_shutdown_pending = true
	get_tree().auto_accept_quit = false
	if running: save_data()
	_deactivate()
	if quit_handler.is_valid(): quit_handler.call(); return
	var tree := get_tree()
	# Keep native close suppressed through node removal and audio-server retirement.
	tree.create_timer(0.5).timeout.connect(tree.quit)
	queue_free()

func _exit_tree() -> void:
	if running: save_data()
	if is_instance_valid(audio): audio.shutdown()
	clear_input()
	if has_started: Input.mouse_mode = previous_mouse_mode
	if owns_quit_policy and get_tree() and not window_shutdown_pending: get_tree().auto_accept_quit = previous_auto_accept_quit
	running = false

static func _fresh_profile() -> Dictionary:
	return {"schema_version":SCHEMA_VERSION,"game_id":GAME_ID,"run_serial":0,"snapshot":{},"results":{}}

func _disable_save(reason: String) -> void:
	save_write_allowed = false
	save_status = reason
	if is_instance_valid(hud): hud.set_save_status(save_status)

func load_data() -> void:
	profile = _fresh_profile()
	save_write_allowed = true
	save_status = ""
	loaded_disk_existed = false
	loaded_disk_bytes = ""
	if not context_valid: _disable_save("存档上下文不匹配，原记录已保留"); return
	if demo_mode: return
	if save_service and save_service.has_method("load_game"):
		var value: Variant = save_service.call("load_game",GAME_ID)
		if value != null: apply_saved_data(value)
		return
	if not FileAccess.file_exists(SAVE_PATH): return
	loaded_disk_existed = true
	loaded_disk_bytes = FileAccess.get_file_as_string(SAVE_PATH)
	var parser := JSON.new()
	if parser.parse(loaded_disk_bytes) != OK: _disable_save("原文件无法读取，已保留；本次为临时游玩"); return
	apply_saved_data(parser.data)

func apply_saved_data(data: Variant) -> void:
	if not _valid_profile(data): _disable_save("记录版本或内容不兼容，已保留；本次为临时游玩"); return
	profile = data.duplicate(true)

static func _number(value: Variant, low: float, high: float, integer := true) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and float(value) >= low and float(value) <= high and (not integer or floorf(float(value)) == float(value))

func _valid_profile(data: Variant) -> bool:
	if not data is Dictionary: return false
	if data.get("game_id") != GAME_ID or not _number(data.get("schema_version"),1,1): return false
	if not _number(data.get("run_serial"),0,1000000000): return false
	if not data.get("snapshot") is Dictionary or not data.get("results") is Dictionary: return false
	if not data.snapshot.is_empty():
		var probe = Simulation.new()
		if not probe.restore(data.snapshot): return false
	for key in data.results:
		if not key is String or not str(key).is_valid_int() or str(int(key)) != key or int(key) < 0 or int(key) > int(data.run_serial): return false
		var result: Variant = data.results[key]
		if not result is Dictionary: return false
		if not _number(result.get("map_id"),0,2) or not _number(result.get("variant"),0,2): return false
		if not _number(result.get("distance"),0,1e9,false) or not _number(result.get("unloads"),1,1000000): return false
		if not _number(result.get("items"),[24,30,36][int(result.map_id)],[24,30,36][int(result.map_id)]): return false
	var current_key := str(int(data.run_serial))
	if data.results.has(current_key):
		if data.snapshot.is_empty() or data.snapshot.get("phase") != "complete": return false
		var result: Dictionary = data.results[current_key]
		for field in ["map_id","variant","distance","unloads"]:
			if result[field] != data.snapshot.get(field): return false
	return true

func save_data() -> bool:
	if not save_write_allowed or not context_valid or demo_mode: return false
	profile.snapshot = sim.snapshot()
	if save_service and save_service.has_method("save_game"):
		save_service.call("save_game",GAME_ID,profile.duplicate(true))
		return true
	if FileAccess.file_exists(SAVE_PATH) != loaded_disk_existed or (loaded_disk_existed and FileAccess.get_file_as_string(SAVE_PATH) != loaded_disk_bytes):
		_disable_save("记录已在别处改变，停止覆盖并保留原文件")
		return false
	if DirAccess.make_dir_recursive_absolute(SAVE_DIR) != OK: return _save_failed()
	var bytes := JSON.stringify(profile)
	if not _write_file(SAVE_PATH + ".tmp",bytes): return _save_failed()
	if loaded_disk_existed:
		if not _write_file(SAVE_PATH + ".bak.tmp",loaded_disk_bytes): return _save_failed()
		if DirAccess.rename_absolute(SAVE_PATH + ".bak.tmp",SAVE_PATH + ".bak") != OK: return _save_failed()
	if DirAccess.rename_absolute(SAVE_PATH + ".tmp",SAVE_PATH) != OK: return _save_failed()
	loaded_disk_bytes = bytes
	loaded_disk_existed = true
	return true

func _write_file(path: String, bytes: String) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	var wrote := file.store_string(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	return wrote and error == OK

func _save_failed() -> bool:
	save_status = "进度暂时无法写入，请保持游戏开启后重试"
	if is_instance_valid(hud): hud.set_save_status(save_status)
	return false

func debug_state() -> Dictionary:
	return {"running":running,"paused":paused,"demo":demo_mode,"sim":sim.snapshot(),"save_allowed":save_write_allowed,"save_status":save_status,"result_count":profile.get("results",{}).size(),"postcard_before":before_texture != null,"postcard_after":after_texture != null,"shutdown_pending":window_shutdown_pending,"camera_zoom":camera.size,"camera_focus":[camera_focus.x,camera_focus.y,camera_focus.z],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"fps_sample":Performance.get_monitor(Performance.TIME_FPS),"audio":audio.debug_state() if audio and audio.has_method("debug_state") else {}}

func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--demo": demo_mode = true
		elif argument.begins_with("--demo-speed="): demo_speed = clampf(float(argument.get_slice("=",1)),1,60)
		elif argument.begins_with("--capture-phase="): capture_phase = argument.get_slice("=",1)
		elif argument.begins_with("--demo-map="): demo_map = clampi(int(argument.get_slice("=",1)),0,2)
		elif argument.begins_with("--demo-variant="): demo_variant = posmod(int(argument.get_slice("=",1)),3)
		elif argument.begins_with("--capture="): capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-after="): capture_after = float(argument.get_slice("=",1))
		elif argument.begins_with("--record-dir="): record_dir = argument.trim_prefix("--record-dir=")
		elif argument.begins_with("--record-frames="): record_frames = clampi(int(argument.get_slice("=",1)),1,10000)
		elif argument.begins_with("--record-fps="): record_fps = clampf(float(argument.get_slice("=",1)),1,60)
		elif argument.begins_with("--record-after="): record_after = maxf(float(argument.get_slice("=",1)),0)
		elif argument.begins_with("--trace="): trace_path = argument.trim_prefix("--trace=")

func _capture_cli() -> void:
	if postcard_pending: return
	if capture_phase == "complete" and not result_shown: return
	if not capture_path.is_empty() and not capture_done and elapsed >= capture_after:
		capture_done = true
		_write_trace()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(capture_path)
		request_application_quit()
	if not record_dir.is_empty() and elapsed >= record_after and elapsed >= next_record_time:
		next_record_time = elapsed + 1.0 / record_fps
		DirAccess.make_dir_recursive_absolute(record_dir)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(record_dir.path_join("frame_%05d.png" % recorded_frames))
		recorded_frames += 1
		if recorded_frames >= record_frames: _write_trace(); request_application_quit()

func _write_trace() -> void:
	if trace_path.is_empty(): return
	var file := FileAccess.open(trace_path,FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(debug_state(),"\t")); file.close()

func show_hint() -> void:
	hint_left = 8.0
	_update_presentation(0)

func _demo_command() -> Dictionary:
	var idle := {"move":Vector2.ZERO,"grab":false,"unload":false}
	if sim.phase != "cleaning": return idle
	if demo_stage == "plan":
		var hint: Dictionary = sim.nearest_hint()
		var unloading: bool = hint.is_empty() or sim.capacity_used() + int(hint.get("cost",1)) > sim.CAPACITY
		if unloading:
			demo_target = ""
			var depots: Array = sim.map_data.depots.duplicate()
			depots.sort_custom(func(a: Dictionary,b: Dictionary): return sim.pos.distance_squared_to(a.pos) < sim.pos.distance_squared_to(b.pos))
			for depot: Dictionary in depots:
				demo_route = preload("data/witness.gd").route(sim,depot.pos)
				if not demo_route.is_empty(): break
		else:
			demo_target = hint.id
			demo_route = preload("data/witness.gd").route(sim,hint.pos,demo_target)
		if demo_route.is_empty(): push_error("Beach demo could not find an ordinary route"); set_paused(true); return idle
		demo_stage = "drive"
	if demo_stage == "drive":
		while not demo_route.is_empty() and sim.pos.distance_to(demo_route[0]) < 0.015: demo_route.remove_at(0)
		if not demo_route.is_empty():
			idle.move = ((demo_route[0]-sim.pos)/(4.0*FIXED_DT)).limit_length()
			return idle
		demo_stage = "unload" if demo_target.is_empty() else "aim"
	if demo_stage == "unload":
		idle.unload = true
		demo_stage = "plan"
		return idle
	if demo_stage == "aim":
		idle.move = (sim.item_by_id(demo_target).pos - sim.pos).normalized() * 0.06
		demo_stage = "grab"
		return idle
	if demo_stage == "grab":
		idle.grab = true
		if not sim.remaining.has(demo_target): demo_stage = "plan"; idle.grab = false
	return idle

func _retire_audio() -> void:
	if not is_instance_valid(audio): return
	retired_audio = weakref(audio)
	# Let its bounded fade finish after the host removes this game immediately.
	audio.reparent(get_tree().root)
	audio.shutdown()
	audio = null

func _begin_pickup_visual(id: String) -> void:
	if is_instance_valid(pickup_visual): pickup_visual.queue_free()
	pickup_id = id
	pickup_left = 0.45
	var item: Dictionary = sim.item_by_id(id)
	cart.position = Vector3(sim.pos.x,0.04,sim.pos.y)
	cart.rotation.y = sim.heading
	pickup_target = cart.to_local(Vector3(item.pos.x,0.15,item.pos.y))
	pickup_visual = load("res://modules/beach_cleanup/art/trash/"+str(item.type)+".tscn").instantiate()
	cart.add_child(pickup_visual)
	pickup_visual.position = pickup_target

func _input(event: InputEvent) -> void:
	# Releases are global: releasing over a HUD button must never latch a tool.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: grabbing = false
	if event is InputEventKey and not event.pressed: keys.erase(event.physical_keycode)

func _follow_camera(dt: float, instant := false) -> void:
	var half: Vector2 = sim.map_data.size * 0.5
	var margin := 4.0
	var target := Vector3(clampf(sim.pos.x,-half.x+margin,half.x-margin),0,clampf(sim.pos.y,-half.y+margin,half.y-margin))
	camera_focus = target if instant else camera_focus.lerp(target,1.0-exp(-dt*6.0))
	camera.position = camera_focus + Vector3(18,24,18)
	camera.look_at(camera_focus)

func _completion_data() -> Dictionary:
	var best_distance := 0.0
	var best_unloads := 0
	for key in profile.results:
		if str(key) == str(int(profile.run_serial)): continue
		var result: Dictionary = profile.results[key]
		if int(result.map_id) != sim.map_id: continue
		if best_distance == 0 or float(result.distance) < best_distance: best_distance = float(result.distance)
		if best_unloads == 0 or int(result.unloads) < best_unloads: best_unloads = int(result.unloads)
	return {"distance":sim.distance,"unloads":sim.unloads,"has_next":sim.map_id < 2,"best_distance":best_distance,"best_unloads":best_unloads}

func _hint_target() -> Dictionary:
	if not sim.remaining.is_empty(): return sim.nearest_hint()
	if sim.cargo.is_empty(): return {}
	# The final load is still unfinished work: point at an actual depot,
	# never at a removed trash ID, and choose the nearer of the dual-bay stops.
	var nearest: Dictionary = {}
	var distance_squared := INF
	for depot: Dictionary in sim.map_data.depots:
		var candidate_distance: float = sim.pos.distance_squared_to(depot.pos)
		if candidate_distance < distance_squared:
			distance_squared = candidate_distance
			nearest = depot
	return nearest.duplicate(true)
