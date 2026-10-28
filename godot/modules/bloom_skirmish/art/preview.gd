extends Node3D
## Native rendered athlete turntable. This is art QA, not a gameplay screenshot.
const Art = preload("res://modules/bloom_skirmish/art/bloom_art.gd")
var actors: Array[Node3D] = []
var elapsed := 0.0
var captured := false
var species := "rabbit"
var action := "idle"
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bloom-animal="): species=arg.trim_prefix("--bloom-animal=")
		# Legacy --bloom-skinned is accepted implicitly; previews always use current rigs.
		if arg.begins_with("--bloom-action="): action=arg.trim_prefix("--bloom-action=")
	var env:=WorldEnvironment.new();var world:=Environment.new()
	world.background_mode=Environment.BG_COLOR;world.background_color=Color("aebfcd")
	world.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	world.ambient_light_color=Color("e5edf2");world.ambient_light_energy=.34
	world.tonemap_mode=Environment.TONE_MAPPER_LINEAR;env.environment=world;add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-28,0)
	sun.light_color=Color("fff6ea");sun.light_energy=.70;sun.shadow_enabled=true;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;sun.directional_shadow_max_distance=12;sun.shadow_bias=.025;sun.shadow_normal_bias=.20;add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-25,135,0)
	fill.light_color=Color("c8dff5");fill.light_energy=.14;add_child(fill)
	for tier in 2:
		var n:=MeshInstance3D.new();var m:=BoxMesh.new();m.size=Vector3(5.1,.12,2.5) if tier==0 else Vector3(5.25,.14,2.65)
		n.mesh=m;n.position=Vector3(0,-.06 if tier==0 else -.19,.12)
		var material:=StandardMaterial3D.new();material.albedo_color=Color("dce1e1") if tier==0 else Color("252e38")
		material.roughness=.85;n.material_override=material;add_child(n)
	for i in 3:
		var actor:=Art.make_animal(species,0 if i<2 else 1,i%2)
		if actor==null:
			push_error("Requested animal unavailable; no human fallback")
			get_tree().quit(2)
			return
		actor.position=Vector3((i-1)*1.35,0,.25 if i==1 else 0)
		actor.rotation_degrees.y=155 if i==1 else (15 if i==0 else -18)
		actors.append(actor);add_child(actor)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=3.45;camera.position=Vector3(2.8,2.5,-7.2);add_child(camera)
	camera.look_at(Vector3(0,.81,.12));camera.current=true
func _process(delta:float) -> void:
	elapsed+=delta
	for i in actors.size():
		Art.animate_gardener(actors[i],elapsed+i*.7,1.0 if action in ["run","dash"] else 0.0,action == "spray",action == "dash")
		Art.apply_gardener_aim_pitch(actors[i],sin(elapsed)*.25 if action == "spray" else 0.0)
	if elapsed>1.5 and not captured and "--bloom-art-shot" in OS.get_cmdline_user_args():
		captured=true
		await RenderingServer.frame_post_draw
		var path:="/tmp/bloom-art-preview.png"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--bloom-art-output="): path=arg.trim_prefix("--bloom-art-output=")
		get_viewport().get_texture().get_image().save_png(path)
		print("BLOOM ANIMAL ART PREVIEW ",species,": ",path)
		get_tree().quit()
