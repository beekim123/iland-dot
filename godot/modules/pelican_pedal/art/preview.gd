extends Node3D
const Rig = preload("res://modules/pelican_pedal/art/pelican_bicycle.gd")
var actor: Node3D
var time := 0.0
func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("e8f1e8")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("fff5e5")
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = 1.25
	light.shadow_enabled = true
	add_child(light)
	var ground := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.5; mesh.bottom_radius = 1.5; mesh.height = 0.1
	ground.mesh = mesh
	ground.position.y = -0.08
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d6dfc9")
	ground.material_override = mat
	add_child(ground)
	actor = Rig.new(); actor.first_person = false
	add_child(actor)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.7
	camera.position = Vector3(2.7,2.05,-3.4)
	add_child(camera)
	camera.look_at(Vector3(0,0.95,-0.05))
	camera.current = true
func _process(delta: float) -> void:
	time += delta
	actor.set_motion(2.5,0.0,false,delta)
