extends Node3D
const World=preload("world.gd")
const Sim=preload("../../sim.gd")
var world
var sim
var capture_path:=""
func _ready() -> void:
	var view:="overview"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): view=arg.trim_prefix("--view=")
		if arg.begins_with("--output="): capture_path=arg.trim_prefix("--output=")
	sim=Sim.new(); sim.start(); world=World.new(); add_child(world); world.build(sim.map_data)
	var env:=WorldEnvironment.new(); var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR; settings.background_color=Color("81c0c6")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("fff9ef"); settings.ambient_light_energy=0.45
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=settings; add_child(env)
	var sun:=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-55,-30,0)
	sun.light_color=Color("fff9ef"); sun.light_energy=0.7; sun.shadow_enabled=true
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance=100; add_child(sun)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.1; camera.far=150 if view=="overview" else 100
	if view!="overview": sun.directional_shadow_max_distance=85
	var target:=Vector3(0,0,-5); camera.size=96
	match view:
		"road": target=Vector3(-18,0,0); camera.size=18; sim.time=100
		"refuge": target=Vector3(-18,0,-8); camera.size=18; sim.pos=Vector2(-18,-8); sim.shelter_id="shelter_D"
		"exit", "boat": target=Vector3(0,0,26); camera.size=18; sim.time=125
		"balloon": target=Vector3(18,2,-24); camera.size=20; sim.time=140
		"airship": target=Vector3(-21,1,24); camera.size=20; sim.called_at=130; sim.arrives_at=142; sim.time=150
	camera.position=target+Vector3(0,48,38); add_child(camera); camera.look_at(target); camera.current=true
	sim._schedule(); world.update_state(sim.snapshot())
	if capture_path!="":
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image()
		var error:=image.save_png(capture_path)
		print("ENVIRONMENT_CAPTURE ",capture_path," result=",error)
		get_tree().quit(error)
