extends Node3D
@export var segment_index: int = 0
func _ready():
	var env:=WorldEnvironment.new(); var e:=Environment.new(); e.background_mode=Environment.BG_COLOR; e.background_color=Color("beded3"); e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color.WHITE; e.ambient_light_energy=.3; e.tonemap_mode=Environment.TONE_MAPPER_LINEAR; env.environment=e; add_child(env)
	var sun:=DirectionalLight3D.new(); sun.light_energy=.35; sun.rotation_degrees=Vector3(-25,-30,0); add_child(sun)
	var camera:=Camera3D.new(); camera.position=Vector3(5,3,28); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=13; camera.current=true; add_child(camera)
	var stage=load("res://modules/monkey_vine/art/environment/jungle_environment.gd").new(); add_child(stage)
	var rules=load("res://modules/monkey_vine/rules/rules.gd").new()
	rules.configure(4242,segment_index)
	stage.build(rules.snapshot())

	var hud=load("res://modules/monkey_vine/ui/jungle_hud.gd").new(); add_child(hud); hud.update_snapshot(rules.snapshot())
