extends Node3D
## Real Godot art review scene; no gameplay mocks or publicity image.
const Factory = preload("res://modules/tide_gulp/art/tide_art_factory.gd")
var fish_nodes: Array[Node3D] = []
var _time := 0.0
var _shot := false
var _output := "/tmp/tide-art-preview.png"
var _frames := 0
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--tide-art-shot": _shot = true
		if arg.begins_with("--tide-art-output="): _output = arg.trim_prefix("--tide-art-output=")
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("c3ddd8")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff3dc")
	env.environment.ambient_light_energy = .70
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28,-28,-15)
	light.light_color = Color("fff0d1")
	light.light_energy = .62
	light.shadow_enabled = false
	add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.3
	camera.position = Vector3(0,.55,13)
	add_child(camera)
	camera.look_at(Vector3(0,-.1,0))
	camera.current = true
	var factory := Factory.new()
	add_child(factory.make_environment(0, Rect2(-6,-3,12,6), []))
	var hero: Node3D = factory.make_fish("moonfish", 2)
	hero.position = Vector3(-1.4,.05,0)
	hero.scale = Vector3.ONE * 2.9
	hero.rotation_degrees.y = 0
	add_child(hero)
	fish_nodes.append(hero)
	var ids := ["silver", "fan", "leaf"]
	for i in range(3):
		var f: Node3D = factory.make_fish(ids[i], 0)
		f.position = Vector3(2.0 + i * .4, 1.1 - i * .95, -.3)
		f.scale = Vector3.ONE * (.65 + i*.14)
		f.rotation_degrees.y = 180
		add_child(f)
		fish_nodes.append(f)
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "TIDE GULP  /  WATERCOLOR STUDY"
	title.position = Vector2(42,28)
	title.add_theme_color_override("font_color", Color("385963"))
	title.add_theme_font_size_override("font_size", 20)
	layer.add_child(title)
	var sub := Label.new()
	sub.text = "Moonfin • original 3D skin • eight-bone swim • soft pigment & paper"
	sub.position = Vector2(42,58)
	sub.add_theme_color_override("font_color", Color("557577"))
	sub.add_theme_font_size_override("font_size", 14)
	layer.add_child(sub)
func _process(delta: float) -> void:
	_time += delta
	_frames += 1
	for i in fish_nodes.size():
		fish_nodes[i].set_motion(2.5, .0, .0, .0, false)
		fish_nodes[i].tick_pose(delta, _time)
	if _shot and _frames == 30:
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png(_output)
		print("TIDE_ART_SHOT ", _output, " status=", result)
		get_tree().quit()
