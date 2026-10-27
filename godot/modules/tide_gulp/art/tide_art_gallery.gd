extends Node3D
## A real rendered contact sheet for silhouettes, growth and reverse-side QA.
const Factory = preload("res://modules/tide_gulp/art/tide_art_factory.gd")
var fish_nodes: Array[Node3D] = []
var _frames := 0
var _time := 0.0
var _shot := false
var _output := "/tmp/tide-art-gallery.png"
var _growth := false
var _reverse := false
var _mouth := false
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--tide-art-shot": _shot = true
		if arg == "--tide-art-growth": _growth = true
		if arg == "--tide-art-reverse": _reverse = true
		if arg == "--tide-art-mouth": _mouth = true
		if arg.begins_with("--tide-art-output="): _output = arg.trim_prefix("--tide-art-output=")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("dce4d7")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff2dc")
	env.environment.ambient_light_energy = .70
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28,-28,-15)
	light.light_color = Color("fff0d1")
	light.light_energy = .62
	add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.5
	camera.position = Vector3(0,.5,18)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var factory := Factory.new()
	var ids: Array[String] = ["moonfish", "silver", "fan", "leaf", "ribbon", "lantern", "parrot", "sailjaw", "whalejaw"]
	var count := 6 if _growth else 9
	for i in range(count):
		var fish: Node3D = factory.make_fish("moonfish" if _growth else ids[i], i if _growth else 0)
		var row := i / 3
		var col := i % 3
		fish.position = Vector3((col - 1) * 4.3 + .3, 2.4 - row * 2.5, 0)
		fish.scale = Vector3.ONE * (1.85 if not _growth else 1.45 + i * .12)
		if _reverse: fish.rotation_degrees.y = 180
		add_child(fish)
		fish_nodes.append(fish)
		var label := Label3D.new()
		label.text = ("MOONFIN — STAGE %d" % (i+1)) if _growth else ids[i].to_upper()
		label.font_size = 26
		label.pixel_size = .008
		label.modulate = Color("4b666c")
		label.no_depth_test = true
		label.position = Vector3((col-1)*4.3, 1.4-row*2.5, .5)
		add_child(label)
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "TIDE GULP  /  " + ("SIX GROWTH STAGES" if _growth else "NINE ORIGINAL SILHOUETTES") + (" / REVERSE SIDE" if _reverse else "")
	title.position = Vector2(34,24)
	title.add_theme_color_override("font_color", Color("385963"))
	title.add_theme_font_size_override("font_size", 18)
	layer.add_child(title)
func _process(delta: float) -> void:
	_frames += 1
	_time += delta
	for fish in fish_nodes:
		fish.set_motion(3.0, .0, .9 if _mouth else 0.0, .0, false)
		fish.tick_pose(delta, _time)
	if _shot and _frames == 30:
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png(_output)
		print("TIDE_ART_GALLERY ", _output, " status=", result)
		get_tree().quit()
