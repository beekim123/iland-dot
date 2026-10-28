extends Node3D
var _out := ""
var _preset := "hero"
var _elapsed := 0.0
var _done := false
var _hero: Node3D
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): _out = arg.trim_prefix("--output=")
		if arg.begins_with("--preset="): _preset = arg.trim_prefix("--preset=")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("b8c7c5")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("d5e4e7")
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -145, 0)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 10.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var ground := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.05
	mesh.height = 0.08
	mesh.radial_segments = 64
	ground.mesh = mesh
	ground.position.y = -0.04
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("8ba6a3")
	m.roughness = 1.0
	ground.material_override = m
	add_child(ground)
	_hero = preload("res://modules/volcano_escape/art/character/otter.tscn").instantiate()
	add_child(_hero)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.95
	cam.near = 0.1
	cam.far = 12.0
	cam.position = Vector3(2.4, 1.8, -3.8) if _preset != "side" else Vector3(4, 1.35, 0.2)
	add_child(cam)
	cam.look_at(Vector3(0, 0.64, 0))
	cam.current = true
	if _preset == "walk": _hero.set_motion(2.8, 0.0)
	elif _preset in ["interact", "shelter", "victory", "hurt"]: _hero.set_state(_preset)
func _process(dt: float) -> void:
	_elapsed += dt
	if _elapsed >= 0.85 and not _done and not _out.is_empty():
		_done = true
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png(_out)
		print("OTTER_CAPTURE ", _out, " result=", result)
		get_tree().quit(result)
