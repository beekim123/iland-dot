extends Node3D
## Presentation and completed-record boundary. Only sim owns disaster state.
signal exit_requested
const Simulation = preload("sim.gd")
const GAME_ID := "volcano_escape"
const SCHEMA_VERSION := 1
const SAVE_DIR := "user://games/volcano_escape"
const SAVE_PATH := SAVE_DIR + "/profile.json"
const FIXED_DT := 1.0 / 60.0
var sim = Simulation.new()
var camera: Camera3D
var world: Node3D
var hero: Node3D
var hud
var audio
var retired_audio: WeakRef
var profile := _fresh_profile()
var save_service: Object
var service_baseline: Variant
var loaded_disk_bytes := ""
var loaded_disk_existed := false
var save_write_allowed := true
var save_status := ""
var context_valid := true
var pending_context := {}
var has_started := false
var running := false
var paused := false
var keys := {}
# One pending rising edge, never a synthetic hold; bounded even under key bursts.
var interact_edge_pending := false
var run_id := ""
var result_shown := false
var boarding_elapsed := 0.0
var accumulator := 0.0
var elapsed := 0.0
var camera_focus := Vector3.ZERO
var camera_zoom := 18.0
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var previous_auto_accept_quit := true
var owns_quit_policy := false
var window_shutdown_pending := false
var quit_handler: Callable
var latest_snapshot := {}
var demo_mode := false
var demo_script := 0
var demo_exit := "boat"
var demo_speed := 1.0
var demo_route: Array[Vector2] = []
var capture_path := ""
var capture_after := 2.0
var capture_phase := ""
var capture_done := false
var record_dir := ""
var record_frames := 120
var record_fps := 12.0
var record_after := 0.0
var recorded_frames := 0
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
	camera.name = "LocalFollowCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18
	camera.near = 0.1
	camera.far = 160
	add_child(camera)
	camera.current = true
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("a9d9e1")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e1e4e2")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	camera.environment = environment
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-28,0)
	sun.light_color = Color("fff9ef")
	sun.light_energy = 0.7
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 85
	add_child(sun)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = load("res://modules/volcano_escape/ui/rescue_hud.gd").new()
	layer.add_child(hud)
	hud.pause_requested.connect(set_paused)
	hud.retry_requested.connect(replay)
	hud.home_requested.connect(leave_game)
	hud.ui_sound.connect(func(cue: String):
		if is_instance_valid(audio): audio.play_cue(cue)
	)

func start(context: Dictionary = {}) -> void:
	if not is_node_ready(): pending_context = context.duplicate(); return
	if running: save_data()
	if not running: previous_mouse_mode = Input.mouse_mode
	has_started = true
	quit_handler = context.get("quit_handler",Callable())
	if not owns_quit_policy:
		previous_auto_accept_quit = get_tree().auto_accept_quit
		owns_quit_policy = true
	get_tree().auto_accept_quit = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	context_valid = context.get("game_id",GAME_ID) == GAME_ID and _number(context.get("schema_version",1),1,1) and context.get("save_root",SAVE_DIR+"/") == SAVE_DIR+"/"
	save_service = context.get("save_service",null)
	load_data()
	camera_zoom = float(profile.settings.zoom)
	_new_run(demo_script if demo_mode else randi_range(0,2))

func _new_run(script_id: int) -> void:
	run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	sim.start(script_id,0)
	running = true
	paused = false
	result_shown = false
	boarding_elapsed = 0
	clear_input()
	accumulator = 0
	elapsed = 0
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	_build_map()
	if hud: hud.reset(); hud.show()
	if not is_instance_valid(audio):
		audio = load("res://modules/volcano_escape/audio/rescue_audio.gd").new()
		add_child(audio)
		audio.start_music()
	audio.set_muted(bool(profile.settings.muted))
	audio.set_paused(false)
	_plan_demo()
	_update_presentation(0)

func _build_map() -> void:
	for node in [world,hero]:
		if is_instance_valid(node): remove_child(node); node.queue_free()
	world = load("res://modules/volcano_escape/art/environment/world.gd").new()
	add_child(world)
	world.build(sim.map_data)
	hero = load("res://modules/volcano_escape/art/character/otter.tscn").instantiate()
	add_child(hero)
	camera_focus = Vector3(sim.pos.x,0,sim.pos.y)
	_follow_camera(0,true)

func _process(dt: float) -> void:
	if not running: return
	elapsed += dt
	accumulator += maxf(dt,0.0) * (demo_speed if demo_mode else 1.0)
	var steps := 0
	# Preserve elapsed time at low frame rates; bound work, not elapsed time.
	while accumulator >= FIXED_DT and steps < 240:
		steps += 1
		var command: Dictionary = _demo_command() if demo_mode else input_command()
		command.pause = paused
		if not paused:
			var short_tap := not demo_mode and interact_edge_pending and not bool(command.interact)
			if not demo_mode and interact_edge_pending:
				var edge: Dictionary = command.duplicate()
				# A release/repress may also happen between two ticks while sim
				# still remembers the previous hold; deliver that release first.
				edge.interact = false
				sim.command(edge)
				edge.interact = true
				sim.command(edge)
			interact_edge_pending = false
			# Released taps reach sim's edge handler with held=false: instantaneous
			# actions work but balloon/call receive zero held-time credit.
			sim.command(command)
			sim.tick(FIXED_DT)
			if short_tap: sim.command(command)
		accumulator -= FIXED_DT
	var events: Array = sim.drain_events()
	if audio and audio.has_method("handle_events"): audio.handle_events(events)
	if sim.status != "running" and not result_shown:
		_record_result()
		result_shown = true
	_update_presentation(dt)
	_capture_cli()

func input_command() -> Dictionary:
	var local := Vector2(float(keys.has(KEY_D))-float(keys.has(KEY_A)),float(keys.has(KEY_S))-float(keys.has(KEY_W))).limit_length()
	var right := Vector2(camera.global_basis.x.x,camera.global_basis.x.z).normalized()
	var back := Vector2(camera.global_basis.z.x,camera.global_basis.z.z).normalized()
	# Always forward intent: sim alone owns E stop/lock/change-cancel semantics.
	return {"move":(right*local.x+back*local.y).limit_length(),"interact":keys.has(KEY_E)}

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed: keys.erase(event.physical_keycode)

func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE: set_paused(not paused)
		elif not paused:
			if event.physical_keycode == KEY_E and not keys.has(KEY_E): interact_edge_pending = true
			keys[event.physical_keycode] = true
	if event is InputEventMouseButton and event.pressed and not paused:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: camera_zoom = clampf(camera_zoom-1,14,26)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera_zoom = clampf(camera_zoom+1,14,26)
		profile.settings.zoom = camera_zoom

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and running: set_paused(true)
	if what == NOTIFICATION_WM_CLOSE_REQUEST and has_started: request_application_quit()

func clear_input() -> void:
	interact_edge_pending = false
	keys.clear()
	sim.command({"move":Vector2.ZERO,"interact":false})

func set_paused(value: bool) -> void:
	paused = value
	interact_edge_pending = false
	accumulator = 0.0
	# Keep the in-progress interaction unchanged while paused. Resume clears
	# stale held keys, requiring an explicit new hold rather than a latched input.
	if value: keys.clear()
	else: clear_input()
	sim.command({"pause":value})
	if audio and audio.has_method("set_paused"): audio.set_paused(value)
	_update_presentation(0)

func replay() -> void:
	_new_run((sim.script_id+1)%3)

func _update_presentation(dt: float) -> void:
	latest_snapshot = sim.snapshot()
	latest_snapshot.save_status = save_status
	var old: Vector3 = hero.position
	hero.position = Vector3(sim.pos.x,0,sim.pos.y)
	if sim.status == "success" and world.has_method("boarding_position"):
		if not paused: boarding_elapsed += dt
		hero.position = hero.position.lerp(world.boarding_position(str(sim.result.exit)),smoothstep(0,1,boarding_elapsed))
	hero.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	hero.rotation.y = sim.heading
	var state := "idle"
	if sim.status == "success": state = "victory"
	elif sim.shelter_id != "": state = "shelter"
	elif sim.time < sim.invulnerable_until: state = "hurt"
	elif sim.interaction.kind != "": state = "interact"
	elif hero.position.distance_to(old)>0.001: state = "walk"
	if hero.has_method("set_state"): hero.set_state(state,float(sim.interaction.progress)/maxf(1,float(sim.interaction.required)))
	if hero.has_method("set_motion"): hero.set_motion(0.0 if paused else (2.8 if state == "walk" else 0.0),0.0 if paused else dt)
	world.update_state(latest_snapshot)
	_follow_camera(dt)
	if hud: hud.update_snapshot(latest_snapshot)
	if audio and audio.has_method("tick"): audio.tick(dt,latest_snapshot)

func _follow_camera(dt: float, instant := false) -> void:
	var target := Vector3(sim.pos.x,0,sim.pos.y)
	camera_focus = target if instant else camera_focus.lerp(target,1.0-exp(-dt*6))
	camera.position = camera_focus+Vector3(18,24,18)
	camera.look_at(camera_focus)
	camera.size = camera_zoom

func _record_result() -> void:
	if sim.status == "running" or profile.results.has(run_id): return
	profile.results[run_id] = sim.result.duplicate(true)
	save_data()

static func _fresh_profile() -> Dictionary:
	return {"schema_version":1,"game_id":GAME_ID,"settings":{"zoom":18.0,"muted":false},"results":{}}

static func _number(v: Variant, low: float, high: float, integer := true) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)>=low and float(v)<=high and (not integer or floorf(float(v))==float(v))

func _valid_profile(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=4: return false
	if value.get("game_id") != GAME_ID or not _number(value.get("schema_version"),1,1): return false
	if not value.get("results") is Dictionary or not value.get("settings") is Dictionary: return false
	if value.settings.size()!=2: return false
	if not _number(value.settings.get("zoom"),14,26,false) or not value.settings.get("muted") is bool: return false
	for key in value.results:
		if not key is String or key.length()!=32 or not key.is_valid_hex_number(): return false
		var r: Variant = value.results[key]
		if not r is Dictionary or r.size()!=8 or not r.get("status") in ["success","rescued"]: return false
		if not _number(r.get("script_id"),0,2) or not _number(r.get("health"),0,3): return false
		if not _number(r.get("time"),0,331,false) or not _number(r.get("beacons"),0,3) or not _number(r.get("score"),0,100000): return false
		if r.status == "success" and (not r.get("exit") in ["boat","balloon","airship"] or r.get("reason")!=r.exit): return false
		if r.status == "rescued" and (r.get("exit")!="" or not r.get("reason") in ["timeout","health"]): return false
	return true

func _disable_save(reason: String) -> void:
	save_write_allowed = false
	save_status = reason

func load_data() -> void:
	profile = _fresh_profile()
	save_write_allowed = true
	save_status = ""
	loaded_disk_bytes = ""
	loaded_disk_existed = false
	service_baseline = null
	if not context_valid: _disable_save("存档上下文不匹配，原记录已保留"); return
	if demo_mode: return
	if save_service:
		if not save_service.has_method("load_game") or not save_service.has_method("save_game"): _disable_save("存档服务不可用"); return
		service_baseline = save_service.call("load_game",GAME_ID)
		if service_baseline is Dictionary or service_baseline is Array: service_baseline = service_baseline.duplicate(true)
		if service_baseline != null: apply_saved_data(service_baseline)
		return
	loaded_disk_existed = FileAccess.file_exists(SAVE_PATH)
	if not loaded_disk_existed: return
	loaded_disk_bytes = FileAccess.get_file_as_string(SAVE_PATH)
	var parser := JSON.new()
	if parser.parse(loaded_disk_bytes)!=OK: _disable_save("原记录无法读取，已保留；本次临时游玩"); return
	apply_saved_data(parser.data)

func apply_saved_data(data: Variant) -> void:
	if not _valid_profile(data): _disable_save("记录版本或内容不兼容，已保留；本次临时游玩"); return
	profile = data.duplicate(true)

func save_data() -> bool:
	if demo_mode or not context_valid or not save_write_allowed: return false
	if not _valid_profile(profile): _disable_save("记录校验失败，未写入"); return false
	if save_service:
		if save_service.call("load_game",GAME_ID) != service_baseline: _disable_save("记录已在别处改变，停止覆盖"); return false
		save_service.call("save_game",GAME_ID,profile.duplicate(true))
		service_baseline = profile.duplicate(true)
		return true
	if DirAccess.make_dir_recursive_absolute(SAVE_DIR)!=OK: return false
	# Atomic mkdir serializes cooperating writers; an abandoned lock is preserved.
	if DirAccess.make_dir_absolute(SAVE_PATH+".lock")!=OK: save_status = "记录正被另一窗口使用；未覆盖"; return false
	var ok := _save_locked()
	DirAccess.remove_absolute(SAVE_PATH+".lock")
	return ok

func _save_locked() -> bool:
	if FileAccess.file_exists(SAVE_PATH)!=loaded_disk_existed or (loaded_disk_existed and FileAccess.get_file_as_string(SAVE_PATH)!=loaded_disk_bytes):
		_disable_save("记录已在别处改变，停止覆盖并保留原文件")
		return false
	var bytes := JSON.stringify(profile)
	if not _write_file(SAVE_PATH+".tmp",bytes): return false
	if loaded_disk_existed:
		if not _write_file(SAVE_PATH+".bak.tmp",loaded_disk_bytes): return false
		if DirAccess.rename_absolute(SAVE_PATH+".bak.tmp",SAVE_PATH+".bak")!=OK: return false
	if DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)!=OK: return false
	loaded_disk_bytes = bytes
	loaded_disk_existed = true
	return true

func _write_file(path: String, bytes: String) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not file: return false
	var ok := file.store_string(bytes)
	file.flush()
	var err := file.get_error()
	file.close()
	return ok and err == OK

func leave_game() -> void:
	if not running: return
	if get_tree().current_scene == self and exit_requested.get_connections().is_empty(): request_application_quit(); return
	save_data()
	_deactivate()
	exit_requested.emit()

func _retire_audio() -> void:
	if not is_instance_valid(audio): return
	retired_audio = weakref(audio)
	audio.reparent(get_tree().root)
	audio.shutdown()
	audio = null

func _deactivate() -> void:
	running = false
	clear_input()
	sim.command({"pause":true})
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	_retire_audio()
	if hud: hud.hide()
	Input.mouse_mode = previous_mouse_mode
	if owns_quit_policy and not window_shutdown_pending:
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
	tree.create_timer(0.5).timeout.connect(tree.quit)
	queue_free()

func _exit_tree() -> void:
	if running: save_data()
	if is_instance_valid(audio): audio.shutdown()
	if has_started: Input.mouse_mode = previous_mouse_mode
	if owns_quit_policy and not window_shutdown_pending: get_tree().auto_accept_quit = previous_auto_accept_quit
	running = false

func debug_state() -> Dictionary:
	return {"sim":sim.snapshot(),"running":running,"paused":paused,"save_allowed":save_write_allowed and context_valid and not demo_mode,"save_status":save_status,"result_count":profile.results.size(),"demo":demo_mode,"shutdown_pending":window_shutdown_pending,"camera_zoom":camera.size,"fps_sample":Performance.get_monitor(Performance.TIME_FPS),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}

func _plan_demo() -> void:
	demo_route.clear()
	var route: Array = {"boat":["H","K"],"balloon":["B","C"],"airship":["H","G","J"]}.get(demo_exit,["H","K"])
	for id: String in route: demo_route.append(sim.map_data.nodes[id])

func _demo_command() -> Dictionary:
	while not demo_route.is_empty() and sim.pos.distance_to(demo_route[0])<0.01: demo_route.pop_front()
	if not demo_route.is_empty(): return {"move":((demo_route[0]-sim.pos)/(2.8*FIXED_DT)).limit_length(),"interact":false}
	# Real held commands, no state teleporting or clock shortcuts. Release once/sec
	# to allow a new edge after an unavailable window; balloon gets an unbroken hold.
	var held := true
	if demo_exit=="boat": held = int(sim.time*60)%60 != 0
	elif demo_exit=="airship": held = int(sim.time*60)%180 != 0
	elif sim.interaction.kind=="": held = int(sim.time*60)%60 != 0
	return {"move":Vector2.ZERO,"interact":held}

func _parse_arguments() -> void:
	for arg in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=",1)
		if arg=="--demo": demo_mode = true
		elif arg.begins_with("--demo-script="): demo_script = clampi(int(value),0,2)
		elif arg.begins_with("--demo-exit=") and value in ["boat","balloon","airship"]: demo_exit = value
		elif arg.begins_with("--demo-speed="): demo_speed = clampf(float(value),1,60)
		elif arg.begins_with("--capture="): capture_path = value
		elif arg.begins_with("--capture-after="): capture_after = maxf(0,float(value))
		elif arg.begins_with("--capture-phase="): capture_phase = value
		elif arg.begins_with("--record-dir="): record_dir = value
		elif arg.begins_with("--record-frames="): record_frames = clampi(int(value),1,10000)
		elif arg.begins_with("--record-fps="): record_fps = clampf(float(value),1,60)
		elif arg.begins_with("--record-after="): record_after = maxf(0,float(value))
		elif arg.begins_with("--trace="): trace_path = value

func _write_trace() -> void:
	if not trace_path.is_empty(): _write_file(trace_path,JSON.stringify(debug_state(),"\t"))

func _capture_cli() -> void:
	if capture_phase in ["complete","success"] and sim.status=="running": return
	if not capture_path.is_empty() and not capture_done and elapsed>=capture_after:
		capture_done = true
		_write_trace()
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(capture_path)
		request_application_quit()
	if not record_dir.is_empty() and elapsed>=record_after and elapsed>=next_record_time:
		next_record_time = elapsed+1.0/record_fps
		DirAccess.make_dir_recursive_absolute(record_dir)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(record_dir.path_join("frame_%05d.png"%recorded_frames))
		recorded_frames += 1
		if recorded_frames>=record_frames: _write_trace(); request_application_quit()
