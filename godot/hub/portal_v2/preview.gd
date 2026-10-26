extends Node3D
const Rift = preload("res://hub/portal_v2/magic_rift.gd")
var portals: Array[Node3D]=[]
func _ready() -> void:
	var world:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("22273d");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("cbc4ed");env.ambient_light_energy=.8;world.environment=env;add_child(world)
	var floor_node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(200,200);floor_node.mesh=plane;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("9ca0b5");mat.roughness=1.0;floor_node.material_override=mat;add_child(floor_node)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-30,0);light.light_energy=.8;add_child(light)
	var camera:=Camera3D.new();camera.position=Vector3(0,4.2,12.2);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=10.1;add_child(camera);camera.look_at(Vector3(0,1.7,0));camera.current=true
	var colors:=["ff439c","23dcca","9864ff"]
	for i in range(3):
		var r:=Rift.new();r.configure({"color":colors[i],"enabled":true});r.position.x=(i-1)*3.0;add_child(r);portals.append(r)
	var args:=OS.get_cmdline_user_args()
	if "--portal-shots" in args or "--portal-gif" in args:
		if DisplayServer.get_name()=="headless":push_error("Actual graphical renderer required for viewport capture");get_tree().quit(2);return
		for p in portals:p.controlled_time=true
		await get_tree().process_frame
		await get_tree().process_frame
		await _capture("--portal-gif" in args)
func _capture(animation:bool)->void:
	var output:=ProjectSettings.globalize_path("res://../art/previews/v5")
	DirAccess.make_dir_recursive_absolute(output)
	var frames:=96 if animation else 1
	if animation:DirAccess.make_dir_recursive_absolute(output+"/portal_v2_frames")
	for i in range(frames):
		for j in range(portals.size()):portals[j].set_time(2.4+i/12.0+j*.63)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path:=output+("/portal_v2_frames/frame_%04d.png"%i if animation else "/portal_v2_three_colors.png")
		var error:=get_viewport().get_texture().get_image().save_png(path)
		if error!=OK:push_error("Capture failed: "+str(error));get_tree().quit(3);return
	print("PORTAL_V2_CAPTURE_COMPLETE ",output)
	get_tree().quit()
