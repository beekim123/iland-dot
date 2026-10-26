extends Node3D
const Art = preload("res://modules/gummy_bomber/art/candy_factory.gd")
func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("d5e9e6")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("fff3e8")
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(6,8,10)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.6
	add_child(camera)
	camera.look_at(Vector3(0,0.15,0))
	camera.current = true
	for z in range(-2,3):
		for x in range(-3,4):
			put(Art.make_floor(x+z), Vector3(x,0,z))
	for x in [-3,-2,-1,0,1,2,3]:
		put(Art.make_wall(),Vector3(x,0,-2))
	put(Art.make_wall(),Vector3(-3,0,0))
	put(Art.make_crate(),Vector3(2,0,-1))
	put(Art.make_crate(),Vector3(2,0,0))
	put(Art.make_crate(),Vector3(-2,0,-1))
	put(Art.make_player(),Vector3(-1,0,1))
	put(Art.make_enemy(0),Vector3(1,0,-1))
	put(Art.make_enemy(1),Vector3(3,0,1))
	put(Art.make_bomb(),Vector3(0,0,1))
	put(Art.make_pickup("range"),Vector3(-2,0,1))
	put(Art.make_pickup("capacity"),Vector3(1,0,2))
	put(Art.make_pickup("speed"),Vector3(2,0,2))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var title := Label.new()
	title.text = "GUMMY GARDEN  /  ORIGINAL CANDY CAST"
	title.position = Vector2(48,38)
	title.add_theme_color_override("font_color",Color("593e60"))
	title.add_theme_font_size_override("font_size",26)
	canvas.add_child(title)
	var caption := Label.new()
	caption.text = "PEACH GUMDROP  ·  BERRY + MINT JELLIES  ·  WAFER + CHOCOLATE"
	caption.position = Vector2(48,730)
	caption.add_theme_color_override("font_color",Color("593e60"))
	caption.add_theme_font_size_override("font_size",19)
	canvas.add_child(caption)
func put(node: Node3D, at: Vector3) -> void:
	add_child(node)
	node.position = at
