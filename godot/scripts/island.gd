extends Node3D
## All visible 3D art is authored Blender geometry imported from GLB.
const MODEL_DIR := "res://resources/models/"
var camera: Camera3D
var yaw := 0.38
var pitch := 0.80
var distance := 30.0
var target := Vector3(0, 1.8, 2.4)
var dragging := false
var elapsed := 0.0
var animated := true
var muted := false
var actors: Array[Node3D] = []
var motion_nodes: Array[Dictionary] = []
var water_nodes: Array[Dictionary] = []
var wildlife: Node
var living_water: Node
var fish_school: Node
var audio_players: Array[AudioStreamPlayer] = []
var hud: CanvasLayer
var initialized := false
var shots := false

func _ready() -> void:
	shots = "--shots" in OS.get_cmdline_user_args()
	_build_world()
	_build_camera()
	_build_hud()
	_build_audio()
	initialized = true
	if shots:
		_capture_sequence.call_deferred()
	elif "--gif" in OS.get_cmdline_user_args():
		_capture_gif_frames.call_deferred()

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#4b9eaa")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d2e9ed")
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "WarmSun"
	sun.light_color = Color("#fff0d6")
	sun.light_energy = 0.35
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	sun.shadow_bias = 0.04
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#c1e8ef")
	fill.light_energy = 0.06
	fill.rotation_degrees = Vector3(-28, 140, 0)
	add_child(fill)
	var landscape := _model("environment", Vector3.ZERO, 1.0, 0.0)
	# Source Blender (x,y,z) becomes Godot (x,z,-y).
	actors.append(_model("turtle", Vector3(-4.3, 0.495, 3.0), 1.15, -0.40))
	actors.append(_model("crab", Vector3(-1.6, 0.395, 3.0), 1.20, 0.15))
	actors.append(_model("seagull", Vector3(4.8, 0.435, 2.7), 0.78, -0.65))
	actors.append(_model("tern", Vector3(-5, 7, 2), 0.67, 0.0))
	actors.append(_model("dolphin", Vector3(7, -0.55, 9), 1.0, 0.0))
	wildlife = load("res://scripts/wildlife_motion.gd").new()
	wildlife.name = "WildlifeMotion"
	add_child(wildlife)
	wildlife.setup(actors)
	living_water = load("res://scripts/living_water.gd").new()
	living_water.name = "LivingWater"
	add_child(living_water)
	living_water.setup(landscape)
	fish_school = load("res://scripts/fish_school.gd").new()
	fish_school.name = "FishSchool"
	add_child(fish_school)
	fish_school.setup(self)
	_apply_motion()

func _model(kind: String, pos: Vector3, size: float, angle: float) -> Node3D:
	var path := MODEL_DIR + kind + ".glb"
	if not ResourceLoader.exists(path):
		push_error("Missing authored model: " + path)
		return null
	var scene := load(path) as PackedScene
	var instance := scene.instantiate() as Node3D
	instance.name = kind.capitalize()
	add_child(instance)
	instance.position = pos
	instance.scale = Vector3.ONE * size
	instance.rotation.y = angle
	# glTF COLOR_0 stores scene-linear values. Compatibility consumes vertex
	# colors in its sRGB pipeline; its vertex_color_is_srgb flag is ineffective.
	# Encode an in-memory copy only; never alter approved source arrays/GLB.
	for mesh in instance.find_children("*","MeshInstance3D",true,false):
		if "terrain" not in String(mesh.name).to_lower(): continue
		var corrected := ArrayMesh.new()
		for surface in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(surface)
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			if not colors.is_empty():
				for index in colors.size():
					colors[index] = colors[index].linear_to_srgb()
				arrays[Mesh.ARRAY_COLOR] = colors
			corrected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var original = mesh.get_active_material(surface)
			if original is StandardMaterial3D:
				var material = original.duplicate()
				material.albedo_color = Color.WHITE
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
				corrected.surface_set_material(surface,material)
		mesh.mesh = corrected
		mesh.set_meta("gltf_linear_color_encoded_for_compatibility",true)
	return instance

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "OrbitCamera"
	camera.fov = 42.0
	camera.near = 0.1
	camera.far = 150.0
	add_child(camera)
	camera.current = true
	_update_camera()

func _update_camera() -> void:
	pitch = clampf(pitch, 0.20, 1.22)
	distance = clampf(distance, 9.0, 49.0)
	camera.position = target + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func reset_view() -> void:
	yaw = 0.38
	pitch = 0.80
	distance = 30.0
	target = Vector3(0, 1.8, 2.4)
	_update_camera()

func beach_view() -> void:
	yaw = 0.10
	pitch = 0.64
	distance = 23.0
	target = Vector3(-0.5, 1.0, 5.0)
	_update_camera()

func swimmer_view() -> void:
	yaw = 0.10
	pitch = 0.68
	distance = 15.5
	target = Vector3(-3.0,0.4,7.5)
	_update_camera()

func flight_view() -> void:
	yaw = actors[2].rotation.y+0.8
	pitch = 0.25
	distance = 8.5
	target = actors[2].global_position+Vector3(0,0.3,0)
	_update_camera()

func _set_capture_camera(t: float) -> void:
	if t < 2.0 or t >= 8.0:
		reset_view()
		yaw = 0.28+0.035*sin(t*0.7)
		_update_camera()
	elif t < 6.0:
		swimmer_view()
		yaw += 0.025*sin(t)
		_update_camera()
	else:
		flight_view()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance *= 0.91
			_update_camera()
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance *= 1.10
			_update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.006
		pitch += event.relative.y * 0.005
		_update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R: reset_view()
		if event.keycode == KEY_M: _toggle_mute()
		if event.keycode == KEY_SPACE: animated = not animated
		if event.keycode == KEY_H: hud.visible = not hud.visible
		if event.keycode == KEY_2: beach_view()
		if event.keycode == KEY_3: swimmer_view()
		if event.keycode == KEY_4: flight_view()
		if event.keycode == KEY_ESCAPE: dragging = false

func _process(delta: float) -> void:
	if not animated: return
	elapsed += delta
	_apply_motion()

func _apply_motion() -> void:
	if wildlife: wildlife.apply_motion(elapsed)
	if living_water: living_water.apply_motion(elapsed)
	if fish_school: fish_school.apply_motion(elapsed)

func _build_hud() -> void:
	hud = preload("res://hub/ui/island_hud.gd").new()
	hud.name = "IslandHUD"
	add_child(hud)
	hud.reset_requested.connect(reset_view)
	hud.beach_requested.connect(beach_view)
	hud.mute_requested.connect(_toggle_mute)
	hud.volume_changed.connect(func(v: float): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.001))))
	hud.set_muted(muted)
	AudioServer.set_bus_volume_db(0, linear_to_db(0.65))

func _build_audio() -> void:
	# Imported resources may be listed as .import in exported PCKs.
	var files := ["sunny_shell_island_loop.wav", "ocean_ambience_loop.wav"]
	for file in files:
		if not file.ends_with("_loop.wav"): continue
		var stream := load("res://resources/audio/"+file) as AudioStreamWAV
		if not stream: continue
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length()*stream.mix_rate)
		var player := AudioStreamPlayer.new()
		player.name = file.get_basename().validate_node_name()
		player.stream = stream
		player.volume_db = -12.0 if "ocean" in file or "ambience" in file else -3.0
		add_child(player)
		player.play()
		audio_players.append(player)

func _toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	hud.set_muted(muted)

func _capture_sequence() -> void:
	# Only use on a graphical instance; headless has no rendered viewport.
	if DisplayServer.get_name() == "headless":
		push_error("--shots needs a graphical display. Use --headless --script tests/check_scene.gd for checks.")
		get_tree().quit(2)
		return
	var out := ProjectSettings.globalize_path("res://../art/previews/runtime")
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out+"/v4_01_island_overview.png")
	beach_view()
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out+"/v4_02_shore_friends.png")
	reset_view()
	hud.visible = false
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out+"/v4_03_island_clean.png")
	swimmer_view()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out+"/v4_04_swim_bones_close.png")
	flight_view()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out+"/v4_05_flight_bones_close.png")
	reset_view()
	hud.visible = true
	print("SHOTS_COMPLETE "+out)


func _capture_gif_frames() -> void:
	# Deterministic simulation time, real graphical viewport rendering.
	# Software-render speed does not change the final animation playback speed.
	if DisplayServer.get_name() == "headless":
		push_error("--gif requires the actual graphical renderer.")
		get_tree().quit(2)
		return
	var out := ProjectSettings.globalize_path("res://../art/previews/runtime/gif_frames_v4")
	DirAccess.make_dir_recursive_absolute(out)
	if FileAccess.file_exists(out+"/capture.json"):
		DirAccess.remove_absolute(out+"/capture.json")
	await get_tree().create_timer(1.0).timeout
	animated = false
	hud.visible = false
	beach_view()
	var fps := 12.0
	var frame_count := 120
	for i in range(frame_count):
		elapsed = float(i) / fps
		_apply_motion()
		_set_capture_camera(elapsed)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame := get_viewport().get_texture().get_image()
		var error := frame.save_png(out + "/frame_%03d.png" % i)
		if error != OK:
			push_error("GIF frame capture failed: " + str(error))
			return
	var info := {"frames":frame_count, "fps":fps, "duration_seconds":10.0,
		"source":"actual graphical Godot viewport", "simulation":"existing motion at fixed 1/12 second steps",
		"camera":"2s overview,4s swimmer/fish close view,2s tracked gull close view,2s overview", "hud":false}
	var f := FileAccess.open(out+"/capture.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "\t"))
	print("GIF_FRAMES_COMPLETE " + out)
	hud.visible = true
	animated = true
	beach_view()
