extends SceneTree
const Scene=preload("../main.tscn")
var checks:=0
var failures:=0
func ck(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var g=Scene.instantiate();root.add_child(g);g.start({"seed":42});g.set_process(false);await process_frame
	g.sim.set_controls(1,1,0)
	for i in 240:
		g.sim.tick(1.0/60);g._update_view()
		ck(g._camera_clear(g.camera.position,false),"camera outside body during steep turn")
		ck(g.camera.position.y>=1 and g.camera.position.y<=27.3,"camera water height clamp")
	ck(g.hud.theme.get_color("font_focus_color","Button").get_luminance()<.4,"focused button dark font")
	# Explicit visual-warning fixture, not a gameplay-win proof.
	g.sim.head=Vector3(23,12,0);g._update_boundary();ck(g.boundary_grid.visible,"near wall grid visible")
	g.sim.head=Vector3(0,12,0);g._update_boundary();ck(not g.boundary_grid.visible,"no center grid clutter")
	g.preview=true;g.leave_game();g.queue_free();await process_frame;await create_timer(.6).timeout
	print("XYZ CAMERA ",checks," checks failures=",failures);quit(1 if failures else 0)
