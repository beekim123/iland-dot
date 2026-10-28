extends Node3D
## Real model inspection scene; not gameplay and no score/save writes.
var art=preload("res://modules/fruit_gummy_snake/art/underwater_art.gd").new()
var creature:Node3D
var elapsed:=0.0
func _ready()->void:
	add_child(art.ocean());creature=art.snake();add_child(creature)
	var env:=WorldEnvironment.new();var e:=Environment.new();e.background_mode=Environment.BG_COLOR;e.background_color=Color("3b7f91");e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;e.ambient_light_color=Color("b6e8ed");e.ambient_light_energy=.28;e.tonemap_mode=Environment.TONE_MAPPER_LINEAR;e.tonemap_exposure=.85;env.environment=e;add_child(env)
	var light:=DirectionalLight3D.new();light.light_energy=.55;light.rotation_degrees=Vector3(-45,-35,0);add_child(light)
	var camera:=Camera3D.new();camera.position=Vector3(7,15,10);camera.fov=48;add_child(camera);camera.look_at(Vector3(0,10,2));camera.current=true
	for i in 5:
		var food:Node3D=art.fruit(i);food.position=Vector3(-3+i*1.6,8+i*.8,-3);add_child(food)
func _process(dt:float)->void:
	elapsed+=dt
	var points:Array[Vector3]=[]
	for i in 36:
		var t:=i*.55
		points.append(Vector3(sin(t*.42+elapsed*.5)*1.5,10+sin(t*.30)*1.4,t-5))
	art.update_snake(creature,points,(points[0]-points[1]).normalized(),elapsed)
