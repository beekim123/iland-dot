extends Node3D
## Portable minigame entry point; no hub dependencies.
signal exit_requested
const Simulation = preload("sim.gd")
const Art = preload("art/candy_factory.gd")
const CandyHUD = preload("ui/candy_hud.gd")
var sim = Simulation.new()
var board: Node3D
var actors: Node3D
var hero: Node3D
var hud
var paused := false
var running := false
var has_started := false
var elapsed := 0.0
var death_time := 0.0
var highscore := 0
var signature := ""
var save_service: Object
var sounds: Dictionary = {}
var music: AudioStreamPlayer
var seed_value := 12345
var actor_cache: Dictionary = {}
var profile_elapsed := 0.0
var fixed_accumulator := 0.0
var previous_ticks := 0
var viewport_settings: Dictionary = {}
var save_write_allowed := true

func _ready() -> void:
	build_scene()
	call_deferred("autostart")

func autostart() -> void:
	if not has_started: start()

func start(context: Dictionary = {}) -> void:
	has_started = true
	if context.has("save_service"): save_service = context.save_service
	load_score()
	seed_value = int(context.get("seed", Time.get_ticks_msec()))
	sim.start(seed_value)
	running = true; paused = false; death_time = 0; elapsed = 0; fixed_accumulator = 0
	previous_ticks = Time.get_ticks_usec()
	set_process(true); set_process_unhandled_input(true)
	if hud:
		hud.show(); hud.set_process(true)
	if board:
		hero.position = Vector3(sim.player.x, 0, sim.player.y)
		refresh_board(true)

func build_scene() -> void:
	configure_render_quality()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("b6dfef")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1de")
	env.ambient_light_energy = 0.24
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -28, 0)
	light.light_color = Color("fff3d4"); light.light_energy = 0.48
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 40
	add_child(light)
	var camera := Camera3D.new()
	camera.environment = env
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.4
	# 70-degree true 3D top-down view, aligned with the grid (no diagonal yaw).
	camera.position = Vector3(6, 18, 11.55)
	add_child(camera)
	camera.look_at(Vector3(6, 0, 5))
	camera.current = true
	board = Node3D.new(); add_child(board)
	actors = Node3D.new(); add_child(actors)
	hero = Art.make_player(); merge_actor_meshes(hero); hero.rotation.y = PI; add_child(hero)
	hud = CandyHUD.new()
	add_child(hud)
	hud.pause_requested.connect(func(): paused = not paused; play_sound("ui"))
	hud.exit_requested.connect(leave_game)
	hud.restart_requested.connect(restart)
	for name in ["place", "pop", "chain", "hit", "pickup", "wave", "ui"]:
		var path: String = "res://modules/gummy_bomber/audio/" + name + ".wav"
		if ResourceLoader.exists(path):
			var voice := AudioStreamPlayer.new(); voice.stream = load(path); voice.volume_db = -5
			add_child(voice); sounds[name] = voice
	var music_path := "res://modules/gummy_bomber/audio/music_loop.wav"
	if ResourceLoader.exists(music_path):
		music = AudioStreamPlayer.new(); music.stream = load(music_path); music.volume_db = -3
		if music.stream is AudioStreamWAV:
			music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		add_child(music); music.play()

func play_sound(name: String) -> void:
	if sounds.has(name): sounds[name].play()

func leave_game() -> void:
	if not running: return
	save_score(); running = false
	restore_render_quality()
	if music: music.stop()
	for voice in sounds.values(): voice.stop()
	if hud:
		hud.hide(); hud.set_process(false)
	set_process(false); set_process_unhandled_input(false)
	exit_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			paused = not paused; get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_SPACE and not paused:
			sim.place_bomb(); get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_R and not sim.alive:
			restart()

func restart() -> void:
	paused = false
	save_score(); sim.start(seed_value + 1); seed_value += 1; death_time = 0
	hero.position = Vector3(sim.player.x, 0, sim.player.y)
	refresh_board(true)

func _process(_engine_delta: float) -> void:
	if not running: return
	var now := Time.get_ticks_usec()
	var delta := float(now - previous_ticks) / 1000000.0
	previous_ticks = now
	# An actual suspended application should pause, not fast-forward a death.
	if delta > 5.0:
		paused = true
		delta = 0.0
	elapsed += delta
	profile_elapsed += delta
	if profile_elapsed >= 5.0 and "--gummy-profile" in OS.get_cmdline_user_args():
		profile_elapsed = 0
		print("GUMMY PERF fps=", Engine.get_frames_per_second(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " objects=", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	if not paused:
		# Fixed steps consume ALL elapsed time. Never clamp the whole frame: that
		# stretched a 2.4s fuse into many seconds on software-rendered machines.
		fixed_accumulator += delta
		while fixed_accumulator >= 1.0 / 60.0:
			fixed_accumulator -= 1.0 / 60.0
			step_simulation(1.0 / 60.0)
		if not sim.alive:
			death_time += delta
			if death_time > 3.0: restart()
	for event in sim.events:
		play_sound(event.type)
		if event.type == "wave": refresh_board(true)
	sim.events.clear()
	highscore = maxi(highscore, sim.score)
	hud.update_state({"wave": sim.wave, "score": sim.score, "highscore": highscore,
		"capacity": sim.capacity, "bombs_active": sim.bombs.size(), "range": sim.blast_range,
		"speed": sim.speed, "paused": paused, "alive": sim.alive,
		"next_wave": maxf(0, sim.wave_wait), "enemies_left": sim.enemies.size()})
	hero.visible = sim.alive
	var target := Vector3(sim.player.x, 0.06, sim.player.y)
	hero.position = hero.position.lerp(target, minf(1, delta * 16))
	hero.position.y = 0.04 + absf(sin(elapsed * 8)) * 0.055
	hero.scale = Vector3(1 + sin(elapsed * 4) * 0.025, 1 - sin(elapsed * 4) * 0.035, 1)
	if sim.invulnerable > 0: hero.visible = int(elapsed * 10) % 2 == 0
	refresh_board()

func step_simulation(dt: float) -> void:
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): sim.move(Vector2i.LEFT)
	elif Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): sim.move(Vector2i.RIGHT)
	elif Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): sim.move(Vector2i.UP)
	elif Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): sim.move(Vector2i.DOWN)
	sim.tick(dt)

func refresh_board(force: bool = false) -> void:
	var next_signature: String = str(sim.grid) + str(sim.pickups)
	if force:
		for node in actor_cache.values(): node.free()
		actor_cache.clear()
	if force or next_signature != signature:
		signature = next_signature
		for child in board.get_children(): child.free()
		for p in sim.grid:
			var floor_tile: Node3D = Art.make_floor((p.x + p.y) % 2)
			floor_tile.position = Vector3(p.x, -0.12, p.y); board.add_child(floor_tile)
			var prop: Node3D
			if sim.grid[p] == sim.WALL: prop = Art.make_wall()
			elif sim.grid[p] == sim.CRATE: prop = Art.make_crate()
			if prop: prop.position = Vector3(p.x, 0, p.y); board.add_child(prop)
		for p in sim.pickups:
			var pickup: Node3D = Art.make_pickup(sim.pickups[p]); pickup.position = Vector3(p.x, 0.1, p.y); board.add_child(pickup)
		batch_static_board()
	var active: Dictionary = {}
	for enemy in sim.enemies:
		var key: String = "enemy_%s" % enemy.id
		var node: Node3D = cached_actor(key, "enemy", enemy.kind)
		var target := Vector3(enemy.pos.x, absf(sin(elapsed * 6 + enemy.kind)) * 0.06, enemy.pos.y)
		node.position = node.position.lerp(target, minf(1.0, get_process_delta_time() * 14.0))
		active[key] = true
	for p in sim.bombs:
		var key: String = "bomb_%s" % p
		var node: Node3D = cached_actor(key, "bomb")
		node.position = Vector3(p.x, 0, p.y)
		var pulse := 1.0 + 0.08 * sin(elapsed * (12 if sim.bombs[p].timer < 0.8 else 5))
		node.scale = Vector3.ONE * pulse
		active[key] = true
	for p in sim.flames:
		var key: String = "flame_%s" % p
		var node: Node3D = cached_actor(key, "flame")
		node.position = Vector3(p.x, 0.06, p.y)
		node.scale = Vector3.ONE * (0.7 + sim.flames[p] * 0.5)
		active[key] = true
	for key in actor_cache.keys():
		if not active.has(key):
			actor_cache[key].free()
			actor_cache.erase(key)

func batch_static_board() -> void:
	var groups: Dictionary = {}
	for child in board.get_children(): collect_static_meshes(child, Transform3D.IDENTITY, groups)
	for child in board.get_children(): child.free()
	for group in groups.values():
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = group.mesh
		multi.instance_count = group.transforms.size()
		for i in group.transforms.size(): multi.set_instance_transform(i, group.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi; node.material_override = group.material
		board.add_child(node)

func collect_static_meshes(node: Node3D, parent_transform: Transform3D, groups: Dictionary) -> void:
	var transform := parent_transform * node.transform
	if node is MeshInstance3D:
		var key := "%s_%s" % [node.mesh.get_instance_id(), node.material_override.get_instance_id()]
		if not groups.has(key): groups[key] = {"mesh": node.mesh, "material": node.material_override, "transforms": []}
		groups[key].transforms.append(transform)
	for child in node.get_children():
		if child is Node3D: collect_static_meshes(child, transform, groups)

func cached_actor(key: String, kind: String, variant: int = 0) -> Node3D:
	if actor_cache.has(key): return actor_cache[key]
	var node: Node3D
	if kind == "enemy": node = Art.make_enemy(variant)
	elif kind == "bomb": node = Art.make_bomb()
	else: node = Art.make_blast()
	merge_actor_meshes(node)
	actors.add_child(node)
	actor_cache[key] = node
	if kind == "enemy":
		node.rotation.y = PI
		for enemy in sim.enemies:
			if key == "enemy_%s" % enemy.id: node.position = Vector3(enemy.pos.x, 0, enemy.pos.y)
	return node

func configure_render_quality() -> void:
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	if "llvmpipe" in adapter or "softpipe" in adapter or "swiftshader" in adapter or "software" in adapter:
		var viewport := get_viewport()
		viewport_settings = {"msaa": viewport.msaa_3d, "scale": viewport.scaling_3d_scale}
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.scaling_3d_scale = 0.75
		print("GUMMY SOFTWARE RENDER: MSAA off, 3D scale .75; restored on exit. Adapter=", adapter)

func restore_render_quality() -> void:
	if viewport_settings.is_empty(): return
	var viewport := get_viewport()
	if viewport:
		viewport.msaa_3d = viewport_settings.msaa
		viewport.scaling_3d_scale = viewport_settings.scale
	viewport_settings.clear()

func merge_actor_meshes(root_node: Node3D) -> void:
	# Actor parts animate as a single gummy body; merge equal-material surfaces.
	var groups: Dictionary = {}
	collect_actor_surfaces(root_node, Transform3D.IDENTITY, groups)
	for child in root_node.get_children(): child.free()
	for group in groups.values():
		var node := MeshInstance3D.new()
		group.tool.index()
		node.mesh = group.tool.commit()
		node.material_override = group.material
		root_node.add_child(node)

func collect_actor_surfaces(node: Node3D, parent_transform: Transform3D, groups: Dictionary) -> void:
	var transform := parent_transform * node.transform
	if node is MeshInstance3D:
		var key: int = node.material_override.get_instance_id()
		if not groups.has(key):
			var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"tool": st, "material": node.material_override}
		for surface in node.mesh.get_surface_count(): groups[key].tool.append_from(node.mesh, surface, transform)
	for child in node.get_children():
		if child is Node3D: collect_actor_surfaces(child, transform, groups)

func load_score() -> void:
	save_write_allowed = true
	if save_service and save_service.has_method("load_game"):
		var injected = save_service.call("load_game", "gummy_bomber")
		if injected != null: apply_saved_score(injected)
		return
	var path := "user://games/gummy_bomber/score.json"
	if FileAccess.file_exists(path):
		apply_saved_score(JSON.parse_string(FileAccess.get_file_as_string(path)))

func apply_saved_score(data: Variant) -> void:
	if not data is Dictionary:
		save_write_allowed = false
		push_warning("Gummy Garden: unreadable save preserved; automatic writes disabled.")
		return
	var version := int(data.get("schema_version", 1))
	if version > 1 or version < 1:
		save_write_allowed = false
		push_warning("Gummy Garden: unknown save schema %d preserved; automatic writes disabled." % version)
		return
	# Versionless legacy scores are version 1 and migrate on the next save.
	highscore = maxi(highscore, int(data.get("highscore", 0)))

func save_score() -> void:
	highscore = maxi(highscore, sim.score)
	if not save_write_allowed: return
	var data := {"schema_version": 1, "highscore": highscore}
	if save_service and save_service.has_method("save_game"):
		save_service.call("save_game", "gummy_bomber", data)
		return
	DirAccess.make_dir_recursive_absolute("user://games/gummy_bomber")
	var file := FileAccess.open("user://games/gummy_bomber/score.json", FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(data))

func _exit_tree() -> void:
	restore_render_quality()
	if running: save_score()
