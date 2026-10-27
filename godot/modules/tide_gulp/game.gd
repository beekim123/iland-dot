extends Node3D
## Independent 2.5D ocean. All gameplay decisions belong to sim.gd.
## World axes: +X fish forward, +Y up, +Z toward the camera.
signal exit_requested

const Simulation = preload("sim.gd")
const FishArt = preload("art/tide_art_factory.gd")
const OceanArt = preload("art/tide_environment.gd")
const TideHUD = preload("ui/tide_hud.gd")
const TideAudio = preload("audio/tide_audio.gd")
const GAME_ID := "tide_gulp"
const SAVE_DIR := "user://games/tide_gulp"
const SAVE_PATH := SAVE_DIR + "/profile.json"
const FIXED_DT := 1.0 / 60.0
const MAX_FISH_NODES := 80
const DEFAULT_RECORD_FPS := 12
const FACE_ROLL_SECONDS := 0.15
const STAGE_NAMES := ["小小浪花", "珊瑚伙伴", "追潮少年", "海流旅人", "深蓝勇士", "大海朋友"]
const BIOME_NAMES := {"shallow":"晴光浅礁", "kelp":"蓝色流潮带", "ruins":"深蓝裂谷"}

var sim = Simulation.new()
var art = FishArt.new()
var camera: Camera3D
var fish_root: Node3D
var environment_root: Node3D
var bubble_root: Node3D
var bubble_pool: Array[Dictionary] = []
var bubble_cursor := 0
var hud
var audio
var player_visual: Node3D
var fish_cache: Dictionary = {}
var fish_pool: Dictionary = {}
var chunk_cache: Dictionary = {}
var last_directions: Dictionary = {}
var mouth_left := 0.0
var growth_left := 0.0
var running := false
var paused := false
var has_started := false
var match_recorded := false
var elapsed := 0.0
var presentation_time := 0.0
var fixed_accumulator := 0.0
var seed_value := 1
var input_mode := "mouse"
var pointer_intent := false
var mouse_target := Vector2.ZERO
var keys: Dictionary = {}
var dash_queued := false
var input_guard := 0.0
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var camera_focus := Vector2.ZERO
var audio_enabled := true
var save_service: Object
var save_write_allowed := true
var save_status := ""
var best_score := 0
var max_stage := 1
var best_time := 0.0
var pending_start_context: Dictionary = {}
var quit_handler: Callable
var previous_auto_accept_quit := true
var owns_quit_policy := false
var window_shutdown_pending := false
var demo_mode := false
var command_seed: Variant = null
var capture_path := ""
var capture_after := 2.0
var captured := false
var record_dir := ""
var record_fps := DEFAULT_RECORD_FPS
var record_frames := 120
var recorded_frames := 0
var record_after := 0.0
var next_record_time := 0.0
var capture_pending := false
var record_fixed := false
var tutorial_eaten := false
var tutorial_dashed := false
var tutorial_threat := false
var latest_snapshot: Dictionary = {}

func _ready() -> void:
	_build_scene()
	_parse_arguments()
	call_deferred("autostart")

func autostart() -> void:
	if not has_started: start(pending_start_context)

func start(context: Dictionary = {}) -> void:
	if not is_node_ready():
		pending_start_context = context.duplicate()
		return
	if running and not match_recorded: _record_run("return")
	if not has_started: previous_mouse_mode = Input.mouse_mode
	has_started = true
	window_shutdown_pending = false
	quit_handler = context.get("quit_handler", Callable())
	if not owns_quit_policy:
		previous_auto_accept_quit = get_tree().auto_accept_quit
		owns_quit_policy = true
		get_tree().auto_accept_quit = false
	save_service = context.get("save_service", null)
	load_data()
	seed_value = int(context.get("seed", command_seed if command_seed != null else Time.get_ticks_msec()))
	running = true
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show()
	hud.set_process(true)
	camera.make_current()
	_begin_run()

func _build_scene() -> void:
	environment_root = Node3D.new()
	environment_root.name = "BoundedOceanChunks"
	add_child(environment_root)
	fish_root = Node3D.new()
	fish_root.name = "PooledLivingFish"
	add_child(fish_root)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b5dcd6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d7e9e5")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	camera = Camera3D.new()
	camera.name = "StorybookSideView"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 12.5
	camera.near = 0.1
	camera.far = 100.0
	camera.environment = environment
	add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.name = "WarmWatercolorSun"
	sun.rotation_degrees = Vector3(-28, -30, -20)
	sun.light_color = Color("fff1d5")
	sun.light_energy = 0.78
	sun.shadow_enabled = false
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30, 130, 0)
	fill.light_color = Color("c2e6ec")
	fill.light_energy = 0.24
	add_child(fill)
	hud = TideHUD.new()
	add_child(hud)
	hud.pause_requested.connect(func(): set_paused(true))
	hud.resume_requested.connect(func(): set_paused(false))
	hud.restart_requested.connect(restart)
	hud.exit_requested.connect(leave_game)
	hud.audio_requested.connect(toggle_audio)
	audio = TideAudio.new()
	add_child(audio)
	player_visual = art.make_fish("moonfish", 0)
	player_visual.name = "MoonfishPlayer"
	fish_root.add_child(player_visual)
	_build_bubble_pool()

func _build_bubble_pool() -> void:
	bubble_root = Node3D.new()
	bubble_root.name = "TwentyFourQuietBubbles"
	add_child(bubble_root)
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	for index in 24:
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color("bedbd2") if index % 2 == 0 else Color("eee7d1")
		material.albedo_color.a = 0.3
		material.roughness = 1.0
		material.metallic_specular = 0.0
		node.material_override = material
		node.hide()
		bubble_root.add_child(node)
		bubble_pool.append({"node":node,"material":material,"left":0.0,"life":0.6,"velocity":Vector3.ZERO,"radius":0.06})

func _bubble_burst(point: Vector2, count: int, spread: float = 1.0) -> void:
	for index in mini(count,8):
		var bubble: Dictionary = bubble_pool[bubble_cursor]
		bubble_cursor = (bubble_cursor + 1) % bubble_pool.size()
		var angle := float(index) / float(maxi(count,1)) * TAU + presentation_time * 1.3
		var direction := Vector2(cos(angle),sin(angle))
		bubble.life = 0.44 + float(index % 3) * 0.09
		bubble.left = bubble.life
		bubble.radius = (0.045 + float(index % 3) * 0.015) * spread
		bubble.velocity = Vector3(direction.x * 0.58, direction.y * 0.42 + 0.5, 0.0)
		bubble.node.position = Vector3(point.x + direction.x * 0.08, point.y + direction.y * 0.08, 0.42)
		bubble.node.scale = Vector3.ONE * float(bubble.radius)
		bubble.node.show()

func _update_bubbles(delta: float) -> void:
	for bubble in bubble_pool:
		if float(bubble.left) <= 0.0: continue
		bubble.left = maxf(0.0,float(bubble.left)-delta)
		var progress := 1.0 - float(bubble.left)/float(bubble.life)
		bubble.node.position += Vector3(bubble.velocity) * delta
		bubble.node.scale = Vector3.ONE * float(bubble.radius) * (1.0 + progress * 0.35)
		var color: Color = bubble.material.albedo_color
		color.a = (1.0-progress) * 0.3
		bubble.material.albedo_color = color
		if float(bubble.left) <= 0.0: bubble.node.hide()

func _clear_bubbles() -> void:
	for bubble in bubble_pool:
		bubble.left = 0.0
		bubble.node.hide()

func _begin_run() -> void:
	paused = false
	match_recorded = false
	elapsed = 0.0
	presentation_time = 0.0
	fixed_accumulator = 0.0
	mouth_left = 0.0
	growth_left = 0.0
	input_guard = 0.18
	tutorial_eaten = false
	tutorial_dashed = false
	tutorial_threat = false
	clear_input()
	input_mode = "mouse"
	pointer_intent = false
	last_directions.clear()
	player_visual.set_meta("pose_initialized",false)
	_clear_bubbles()
	sim.start(seed_value)
	latest_snapshot = sim.snapshot()
	camera_focus = latest_snapshot.player.pos
	_release_all_fish()
	hud.hide_modal()
	_update_camera(0.0, true)
	_sync_world(0.0)
	_handle_events()
	_sync_audio_pause()
	_update_hud()

func restart() -> void:
	if not running: return
	_record_run("restart")
	seed_value += 1
	_begin_run()
	audio.play("button")

func _process(delta: float) -> void:
	if not running: return
	input_guard = maxf(0.0, input_guard - delta)
	var frame_dt := 1.0 / float(record_fps) if record_fixed else minf(delta, 0.15)
	if not paused and bool(latest_snapshot.get("alive", true)):
		fixed_accumulator += frame_dt
		while fixed_accumulator >= FIXED_DT:
			var command := _demo_command() if demo_mode else _player_command()
			sim.command(command)
			dash_queued = false
			sim.tick(FIXED_DT)
			fixed_accumulator -= FIXED_DT
			_handle_events()
			if not sim.alive:
				fixed_accumulator = 0.0
				break
	latest_snapshot = sim.snapshot()
	elapsed = float(latest_snapshot.get("elapsed", elapsed))
	if not paused:
		presentation_time += frame_dt
		mouth_left = maxf(0.0, mouth_left - frame_dt)
		growth_left = maxf(0.0, growth_left - frame_dt)
	_update_camera(delta)
	_sync_world(0.0 if paused else frame_dt)
	_update_bubbles(0.0 if paused else frame_dt)
	_update_hud()
	_capture_if_due()

func _player_command() -> Dictionary:
	var movement := _keyboard_vector()
	return {"move":movement if input_mode == "keyboard" else Vector2.ZERO,
		"target":mouse_target, "use_target":input_mode == "mouse" and pointer_intent,
		"dash":dash_queued and input_guard <= 0.0}

func _keyboard_vector() -> Vector2:
	return Vector2(float(_held(KEY_D) or _held(KEY_RIGHT)) - float(_held(KEY_A) or _held(KEY_LEFT)),
		float(_held(KEY_W) or _held(KEY_UP)) - float(_held(KEY_S) or _held(KEY_DOWN))).normalized()

func _held(code: int) -> bool:
	return bool(keys.get(code, false))

func _input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
			keys[key] = event.pressed
			if event.pressed and not event.echo and not paused:
				input_mode = "keyboard"
				pointer_intent = false
	elif event is InputEventMouseMotion and not paused and _keyboard_vector() == Vector2.ZERO:
		# A held movement key wins over incidental mouse jitter. A deliberate
		# later mouse movement explicitly opts back into pointer swimming.
		if event.relative.length_squared() >= 9.0:
			input_mode = "mouse"
			pointer_intent = true
			_update_pointer_target(event.position)
		elif input_mode == "mouse" and pointer_intent:
			_update_pointer_target(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_ESCAPE:
			if hud.has_method("handle_escape") and hud.handle_escape():
				get_viewport().set_input_as_handled()
				return
			if bool(latest_snapshot.get("alive", true)): set_paused(not paused)
			get_viewport().set_input_as_handled()
		elif key == KEY_SPACE and not paused and bool(latest_snapshot.get("alive", true)):
			input_mode = "keyboard"
			pointer_intent = false
			dash_queued = true
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not paused and bool(latest_snapshot.get("alive", true)) and input_guard <= 0.0:
			input_mode = "mouse"
			pointer_intent = true
			_update_pointer_target(event.position)
			dash_queued = true
			get_viewport().set_input_as_handled()

func _update_pointer_target(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var ray := camera.project_ray_normal(screen_position)
	if absf(ray.z) > 0.00001:
		var point := origin + ray * (-origin.z / ray.z)
		mouse_target = Vector2(point.x, point.y)

func clear_input() -> void:
	keys.clear()
	dash_queued = false
	pointer_intent = false

func set_paused(value: bool) -> void:
	if not running or not bool(latest_snapshot.get("alive", true)): return
	paused = value
	sim.set_paused(value)
	fixed_accumulator = 0.0
	clear_input()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if paused: hud.show_pause()
	else:
		input_guard = 0.15
		hud.hide_modal()
	_sync_audio_pause()
	if not paused: audio.play("button")
	_update_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and running and not paused: set_paused(true)
	if what == NOTIFICATION_WM_CLOSE_REQUEST and has_started: request_application_quit()

func _update_camera(delta: float, snap := false) -> void:
	if latest_snapshot.is_empty(): return
	var player: Dictionary = latest_snapshot.player
	var lookahead: Vector2 = player.dir * 1.25
	var target: Vector2 = player.pos + lookahead
	target.y = clampf(target.y, -1.8, 1.8)
	var wanted_size := 12.5 + (float(player.length) - 1.0) * 2.1
	var smooth := 1.0 if snap else 1.0 - exp(-delta * 3.8)
	camera_focus = camera_focus.lerp(target, smooth)
	camera.size = lerpf(camera.size, wanted_size, smooth)
	camera.position = Vector3(camera_focus.x, camera_focus.y + 2.4, 22.0)
	camera.look_at(Vector3(camera_focus.x, camera_focus.y, 0.0), Vector3.UP)
	# A fixed screen pointer remains a point in the current camera, not a stale
	# world coordinate left behind when the camera follows the fish.
	if input_mode == "mouse" and pointer_intent and not demo_mode:
		_update_pointer_target(get_viewport().get_mouse_position())

func _sync_world(delta: float) -> void:
	if latest_snapshot.is_empty(): return
	var player: Dictionary = latest_snapshot.player
	_sync_fish_visual(player_visual, player, -1, delta)
	if player_visual.has_method("set_stage"): player_visual.set_stage(int(player.stage) - 1)
	player_visual.visible = bool(latest_snapshot.get("alive", true)) or mouth_left > 0.0
	var live_ids: Dictionary = {}
	for fish in latest_snapshot.fish: live_ids[int(fish.id)] = true
	# Retire unloaded fish before allocating incoming ones; pool bounds must
	# hold even on a frame crossing multiple chunk boundaries.
	for id in fish_cache.keys():
		if not live_ids.has(id):
			_release_fish(fish_cache[id])
			fish_cache.erase(id)
			last_directions.erase(id)
	for fish in latest_snapshot.fish:
		var id := int(fish.id)
		if not fish_cache.has(id) or not is_instance_valid(fish_cache[id]):
			fish_cache[id] = _acquire_fish(str(fish.species))
		var visual: Node3D = fish_cache[id]
		if visual: _sync_fish_visual(visual, fish, id, delta)
	var live_chunks: Dictionary = latest_snapshot.chunks
	for index in live_chunks:
		if not chunk_cache.has(index):
			var chunk: Dictionary = live_chunks[index]
			var biome := ["shallow", "kelp", "ruins"].find(str(chunk.biome))
			var environment: Node3D = art.make_environment(maxi(0, biome), chunk.rect, chunk.obstacles)
			environment.name = "OceanChunk_%s" % index
			environment_root.add_child(environment)
			chunk_cache[index] = environment
		var environment: Node3D = chunk_cache[index]
		var tide: Dictionary = latest_snapshot.get("tide", {})
		var tide_strength := 0.08 if str(tide.get("phase","calm")) == "warning" else float(tide.get("strength",0.0))
		var current := tide_strength * Vector2(tide.get("direction",Vector2.RIGHT)).x
		OceanArt.animate_environment(environment, presentation_time, current)
	for index in chunk_cache.keys():
		if not live_chunks.has(index):
			chunk_cache[index].free()
			chunk_cache.erase(index)

func _sync_fish_visual(visual: Node3D, body: Dictionary, id: int, delta: float) -> void:
	visual.position = Vector3(body.pos.x, body.pos.y, 0.0)
	if id != -1:
		var view_size := get_viewport().get_visible_rect().size
		var half_width := camera.size * view_size.x / maxf(1.0,view_size.y) * 0.5
		var margin := float(body.length) * 1.8
		visual.visible = absf(float(body.pos.x)-camera_focus.x) < half_width + margin and absf(float(body.pos.y)-camera_focus.y) < camera.size * 0.5 + margin
		if not visual.visible: return
	else: visual.show()
	var direction: Vector2 = body.get("dir", Vector2.RIGHT)
	var old_direction: Vector2 = last_directions.get(id, direction)
	var turn := old_direction.angle_to(direction)
	last_directions[id] = direction
	_set_fish_orientation(visual,direction,delta)
	visual.scale = Vector3.ONE * float(body.length)
	var speed: float = Vector2(body.get("velocity", Vector2.ZERO)).length()
	var mouth := clampf(mouth_left * 5.0, 0.0, 1.0) if id == -1 else (0.85 if str(body.get("state", "")) == "lunge" else 0.0)
	var dash: bool = float(body.get("dash_left", 0.0)) > 0.0 or str(body.get("state", "")) == "lunge"
	visual.set_motion(speed, turn, mouth, 0.0, dash)
	visual.tick_pose(delta, presentation_time)

func _set_fish_orientation(visual: Node3D, direction: Vector2, delta: float, snap: bool = false) -> void:
	# Heading and side reveal are separate rotations. A full-quaternion slerp
	# would point the head into Z while sim's mouth is already facing in XY.
	# Instead +X follows the authoritative heading exactly on EVERY frame;
	# a 150ms roll around that same +X reveals the other genuine 3D side.
	# This also avoids Godot's YXZ Euler trap: left-up must never render down.
	var heading := direction.normalized() if direction.length_squared() > 0.00001 else Vector2.RIGHT
	var initialized := bool(visual.get_meta("pose_initialized",false))
	var previous_roll := float(visual.get_meta("face_roll",0.0))
	var target_roll := PI if heading.x < 0.0 else 0.0
	# Exactly vertical swimming has no left/right preference. Keep the last
	# side so tiny horizontal changes do not repeatedly roll the fish.
	if absf(heading.x) < 0.08 and initialized:
		target_roll = float(visual.get_meta("face_roll_target",0.0))
	var roll := target_roll if snap or not initialized else move_toward(previous_roll,target_roll,maxf(0.0,delta)*PI/FACE_ROLL_SECONDS)
	visual.quaternion = Quaternion(Vector3.BACK,heading.angle()) * Quaternion(Vector3.RIGHT,roll)
	visual.set_meta("face_roll",roll)
	visual.set_meta("face_roll_target",target_roll)
	visual.set_meta("pose_initialized",true)

func _acquire_fish(species: String) -> Node3D:
	var pool: Array = fish_pool.get(species, [])
	var visual: Node3D
	if not pool.is_empty():
		visual = pool.pop_back()
		fish_pool[species] = pool
	elif fish_root.get_child_count() < MAX_FISH_NODES + 1:
		visual = art.make_fish(species, 0)
		visual.set_meta("species", species)
		fish_root.add_child(visual)
	else:
		# Recycle one inactive species slot rather than growing the pool without
		# bound when visiting biomes repeatedly. Active fish are never evicted.
		for key in fish_pool:
			var other: Array = fish_pool[key]
			if not other.is_empty():
				var stale: Node3D = other.pop_back()
				fish_pool[key] = other
				stale.free()
				visual = art.make_fish(species, 0)
				visual.set_meta("species", species)
				fish_root.add_child(visual)
				break
	if visual:
		visual.set_meta("pose_initialized",false)
		visual.show()
	return visual

func _release_fish(visual: Node3D) -> void:
	if not is_instance_valid(visual): return
	visual.hide()
	var species := str(visual.get_meta("species"))
	var pool: Array = fish_pool.get(species, [])
	pool.append(visual)
	fish_pool[species] = pool

func _release_all_fish() -> void:
	for visual in fish_cache.values(): _release_fish(visual)
	fish_cache.clear()
	for environment in chunk_cache.values(): environment.free()
	chunk_cache.clear()

func _handle_events() -> void:
	for event in sim.drain_events():
		var type := str(event.get("type", ""))
		match type:
			"eat":
				_bubble_burst(event.get("pos",sim.player.pos),2 if bool(event.get("tiny",false)) else 6)
				mouth_left = 0.22
				tutorial_eaten = true
				audio.play("swallow")
			"grow":
				_bubble_burst(event.get("pos",sim.player.pos),8,1.2)
				growth_left = 1.4
				var stage := clampi(int(event.get("stage", sim.player.stage)), 1, 6)
				hud.show_growth(stage, STAGE_NAMES[stage - 1])
				audio.play("growth")
			"dash":
				tutorial_dashed = true
				audio.play("dash")
			"threat":
				tutorial_threat = true
				audio.play("warning")
			"tide":
				if str(event.get("phase", "")) == "warning": hud.show_current_warning("潮水要换班啦，顺着水纹游得更快")
				audio.play("tide")
			"death":
				_bubble_burst(event.get("pos",sim.player.pos),8,1.4)
				latest_snapshot = sim.snapshot()
				_record_run("death")
				clear_input()
				audio.play("death")
				hud.show_result(_result_data("death"))

func _tutorial_text() -> String:
	if elapsed > 45.0: return ""
	if not tutorial_eaten: return "鼠标指向哪里，就游向哪里 · 寻找比你小的鱼"
	if not tutorial_dashed and tutorial_threat: return "大鱼来了！左键冲刺，横着躲开它的嘴"
	if elapsed < 14.0: return "张嘴标记是食物 · 相近体型吃不了 · 大鱼的嘴很危险"
	if not tutorial_dashed: return "左键冲刺 · 也可用 WASD / 方向键 + 空格"
	return "跟着水纹顺潮游；长大后去寻找更有分量的鱼"

func _update_hud() -> void:
	if latest_snapshot.is_empty(): return
	var p: Dictionary = latest_snapshot.player
	var tide: Dictionary = latest_snapshot.get("tide", sim.tide_state())
	var tags: Array = []
	var warnings: Array = []
	var viewport_size := get_viewport().get_visible_rect().size
	for fish in latest_snapshot.fish:
		var distance: float = p.pos.distance_to(fish.pos)
		if distance > 14.0: continue
		var screen := camera.unproject_position(Vector3(fish.pos.x, fish.pos.y + float(fish.length) * 0.34, 0.0))
		var relation: String = sim.relation(float(fish.length))
		var warning := relation == "danger" and (float(fish.get("warning_left", 0.0)) > 0.0 or str(fish.get("state", "")) in ["alert", "windup", "lunge"])
		if distance < 7.0 or warning:
			tags.append({"pos":screen, "relation":relation, "length":fish.length, "warning":warning})
		if warning:
			warnings.append({"pos":screen.clamp(Vector2(48,105),viewport_size-Vector2(48,95)), "direction":Vector2(fish.pos-p.pos).normalized(), "text":"大鱼的嘴！", "distance":distance})
	warnings.sort_custom(func(a,b): return float(a.distance) < float(b.distance))
	if warnings.size() > 2: warnings.resize(2)
	var hint := _tutorial_text()
	hud.update_state({"score":int(latest_snapshot.get("score", 0)), "survival_time":elapsed,
		"stage":int(p.stage), "stage_name":STAGE_NAMES[clampi(int(p.stage)-1,0,5)],
		"stage_progress":float(p.growth), "dash_ready":float(p.dash_cooldown)<=0.0,
		"dash_cooldown_ratio":clampf(float(p.dash_cooldown)/3.0,0.0,1.0),
		"best_score":best_score,"max_stage":max_stage,"best_time":best_time,
		"current_warning":"大鱼靠近，绕开鱼嘴" if not warnings.is_empty() else "",
		"controls_hint_visible":not hint.is_empty(),"controls_hint":hint,"input_mode":input_mode,
		"audio":audio_enabled,"paused":paused,"finished":not bool(latest_snapshot.get("alive",true)),
		"biome":BIOME_NAMES.get(str(latest_snapshot.get("biome","shallow")),"晴光浅礁"),
		"tide_phase":str(tide.get("phase","calm")),"tide_remaining":float(tide.get("remaining",0.0)),
		"tide_direction":tide.get("direction",Vector2.RIGHT),"screen_tags":tags,"warnings":warnings,"save_status":save_status})

func _result_data(reason: String) -> Dictionary:
	return {"score":int(latest_snapshot.get("score",0)),"survival_time":elapsed,
		"stage":int(latest_snapshot.player.stage),"best_score":best_score,"max_stage":max_stage,
		"best_time":best_time,"reason":"大鱼的嘴追上了你，下次试试横向冲刺。" if reason == "death" else "这一程的收获，已经记下啦。","save_status":save_status}

func _record_run(reason: String) -> void:
	if match_recorded or not has_started: return
	if latest_snapshot.is_empty(): return
	# sim.finish closes an active run without calling it a death; score comes
	# only from real edible fish. Time alone never becomes score.
	if bool(latest_snapshot.get("alive",true)): sim.finish(reason)
	latest_snapshot = sim.snapshot()
	elapsed = float(latest_snapshot.get("elapsed",elapsed))
	best_score = maxi(best_score,int(latest_snapshot.get("score",0)))
	max_stage = maxi(max_stage,int(latest_snapshot.player.stage))
	best_time = maxf(best_time,elapsed)
	match_recorded = true
	save_data()

func toggle_audio() -> void:
	audio_enabled = not audio_enabled
	_sync_audio_pause()
	if audio_enabled and not paused: audio.play("button")
	_update_hud()

func _sync_audio_pause() -> void:
	audio.set_enabled(audio_enabled)
	audio.set_paused(paused or not running)

func leave_game() -> void:
	if not running: return
	_record_run("return")
	_deactivate()
	if get_tree().current_scene == self and exit_requested.get_connections().is_empty():
		request_application_quit()
	else: exit_requested.emit()

func _deactivate() -> void:
	running = false
	paused = false
	clear_input()
	_clear_bubbles()
	fixed_accumulator = 0.0
	Input.mouse_mode = previous_mouse_mode
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	audio.stop_all()
	hud.hide()
	hud.set_process(false)

func request_application_quit() -> void:
	if window_shutdown_pending: return
	window_shutdown_pending = true
	if running: _record_run("return")
	_deactivate()
	if quit_handler.is_valid():
		quit_handler.call()
		return
	var tree := get_tree()
	tree.create_timer(0.5).timeout.connect(tree.quit)
	queue_free()

func _exit_tree() -> void:
	if running: _record_run("return")
	if is_instance_valid(audio): audio.stop_all()
	clear_input()
	Input.mouse_mode = previous_mouse_mode
	if owns_quit_policy and get_tree(): get_tree().auto_accept_quit = previous_auto_accept_quit
	running = false

func load_data() -> void:
	save_write_allowed = true
	save_status = ""
	best_score = 0
	max_stage = 1
	best_time = 0.0
	if save_service and save_service.has_method("load_game"):
		var injected = save_service.call("load_game", GAME_ID)
		if injected != null: apply_saved_data(injected)
		return
	if not FileAccess.file_exists(SAVE_PATH): return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK:
		_disable_save("原有记录无法读取，已保留原文件")
		return
	apply_saved_data(parser.data)

func apply_saved_data(data: Variant) -> void:
	if not data is Dictionary:
		_disable_save("原有记录格式不明，已保留原文件")
		return
	var schema: Variant = data.get("schema_version", null)
	if not _valid_number(schema,1,1,true):
		_disable_save("记录来自未知版本，已保留原文件")
		return
	if not _valid_number(data.get("best_score",null),0,1000000000,true) or not _valid_number(data.get("max_stage",null),1,6,true) or not _valid_number(data.get("best_time",null),0,1000000000,false):
		_disable_save("原有记录数值不合法，已保留原文件")
		return
	best_score = int(data.best_score)
	max_stage = int(data.max_stage)
	best_time = float(data.best_time)

static func _valid_number(value: Variant, minimum: float, maximum: float, integer: bool) -> bool:
	if not (value is float or value is int): return false
	var number := float(value)
	return is_finite(number) and number >= minimum and number <= maximum and (not integer or floorf(number)==number)

func _disable_save(reason: String) -> void:
	save_write_allowed = false
	save_status = reason

func save_data() -> bool:
	if not save_write_allowed: return false
	var data := {"schema_version":1,"best_score":best_score,"max_stage":max_stage,"best_time":best_time}
	if save_service and save_service.has_method("save_game"):
		save_service.call("save_game", GAME_ID, data)
		return true
	if DirAccess.make_dir_recursive_absolute(SAVE_DIR) != OK:
		save_status = "本地记录暂时无法写入"
		return false
	var temporary := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		save_status = "本地记录暂时无法写入"
		return false
	var wrote := file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not wrote or write_error != OK:
		save_status = "本地记录暂时无法写入"
		return false
	var error := DirAccess.rename_absolute(temporary, SAVE_PATH)
	if error != OK:
		save_status = "本地记录暂时无法写入"
		return false
	return true

func _demo_command() -> Dictionary:
	# Explicit opt-in capture aid: ordinary legal input only, never teleports,
	# grows fish, grants points, disables predators, or changes simulation data.
	var p: Dictionary = sim.player
	var target: Vector2 = p.pos + Vector2(6.0, sin(elapsed*0.35)*2.5)
	var closest := INF
	for fish in sim.fish:
		var distance: float = p.pos.distance_to(fish.pos)
		if sim.relation(float(fish.length)) == "danger" and distance < 4.5:
			var escape: Vector2 = (p.pos-fish.pos).normalized()
			return {"move":Vector2(escape.x,signf(escape.y+0.1)).normalized(),"use_target":false,"dash":true}
		if sim.relation(float(fish.length)) == "food" and float(fish.length) >= float(p.length)*0.35 and distance < closest:
			closest = distance
			target = fish.pos
	return {"move":Vector2.ZERO,"target":target,"use_target":true,"dash":closest > 3.0 and closest < 7.0}

func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--tide-demo": demo_mode = true
		elif argument.begins_with("--tide-seed="):
			var value := argument.trim_prefix("--tide-seed=")
			if value.is_valid_int(): command_seed = int(value)
		elif argument.begins_with("--tide-capture="): capture_path = argument.trim_prefix("--tide-capture=")
		elif argument.begins_with("--tide-capture-after="): capture_after = maxf(0.0,float(argument.trim_prefix("--tide-capture-after=")))
		elif argument.begins_with("--tide-record-dir="):
			record_dir = argument.trim_prefix("--tide-record-dir=")
			record_fixed = true
		elif argument.begins_with("--tide-record-fps="): record_fps = _record_fps_from_arg(argument.trim_prefix("--tide-record-fps="))
		elif argument.begins_with("--tide-record-frames="): record_frames = clampi(int(argument.trim_prefix("--tide-record-frames=")),1,3600)
		elif argument.begins_with("--tide-record-after="): record_after = maxf(0.0,float(argument.trim_prefix("--tide-record-after=")))
	next_record_time = record_after

static func _record_fps_from_arg(value: String) -> int:
	if not value.is_valid_int(): return DEFAULT_RECORD_FPS
	var requested := int(value)
	return requested if requested >= 1 and requested <= 60 else DEFAULT_RECORD_FPS

func _capture_if_due() -> void:
	if DisplayServer.get_name() == "headless" or capture_pending: return
	if not captured and not capture_path.is_empty() and presentation_time >= capture_after:
		captured = true
		_capture_frame(capture_path, false)
	elif not record_dir.is_empty() and recorded_frames < record_frames and presentation_time >= next_record_time:
		DirAccess.make_dir_recursive_absolute(record_dir)
		_capture_frame(record_dir.path_join("frame_%04d.png" % recorded_frames), true)

func _capture_frame(path: String, movie: bool) -> void:
	capture_pending = true
	await RenderingServer.frame_post_draw
	if not is_inside_tree(): return
	var result := get_viewport().get_texture().get_image().save_png(path)
	if movie:
		recorded_frames += 1
		next_record_time = record_after + float(recorded_frames) / float(record_fps)
		if recorded_frames >= record_frames:
			print("TIDE RECORD frames=",recorded_frames," fps=",record_fps," path=",record_dir)
			request_application_quit()
	else: print("TIDE CAPTURE path=",path," result=",result)
	capture_pending = false
