extends SceneTree
## Real wall-clock, interrupted input, replay and teardown regression.
var failures: Array[String] = []
class Store extends RefCounted:
	var data:Dictionary={}
	func load_game(_id:String)->Dictionary: return data
	func save_game(_id:String,value:Dictionary)->void: data=value.duplicate(true)
func _initialize()->void: call_deferred("run")
func check(condition:bool,message:String)->void:
	if not condition: failures.append(message); push_error(message)
func key(code:int,pressed:bool)->InputEventKey:
	var event:=InputEventKey.new(); event.physical_keycode=code; event.pressed=pressed; return event
func run()->void:
	var game=load("res://modules/bloom_skirmish/main.tscn").instantiate()
	root.add_child(game); game.start({"seed":42,"save_service":Store.new()}); game.set_process(false)
	check(game.running and game.countdown_left==3.0,"standalone contract starts countdown")
	check(game.floor_mesh.mesh is PlaneMesh and game.turf_image.get_size()==Vector2i(game.sim.GRID_W,game.sim.GRID_H),"coverage is one texture-backed surface, not per-cell nodes")
	check(game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"real perspective chase camera, not tilted orthographic")
	game.previous_ticks=Time.get_ticks_usec()-100000; game._process(.1)
	check(game.countdown_left==3.0 and not game.pointer_active,"initial countdown waits for explicit Web-safe capture")
	var acquire:=InputEventMouseButton.new(); acquire.button_index=MOUSE_BUTTON_LEFT; acquire.pressed=true; game._unhandled_input(acquire)
	check(game.pointer_active and not game.shoot_held,"capture click never fires a shot")
	game.sim.bots_enabled=false; game.countdown_left=0.0; game.input_guard=0.0
	var original:Vector2=game.sim.actors[0].pos
	game._unhandled_input(key(KEY_W,true))
	for i in 4:
		OS.delay_msec(300); game._process(.001)
	check(game.sim.time_left<178.9 and game.sim.time_left>178.5,"wall clock consumes elapsed time, ignoring misleading engine delta")
	check(game.sim.actors[0].pos.x>original.x+4.0,"camera-forward W is world +X at initial chase yaw, independent of FPS")
	game.set_paused(true); var frozen:float=game.sim.time_left
	OS.delay_msec(150); game._process(1.0)
	check(game.sim.time_left==frozen and game.keys.is_empty() and not game.shoot_held,"pause freezes rules and neutralizes held input")
	game.set_paused(false); game.input_guard=0.0; var resumed:Vector2=game.sim.actors[0].pos
	game.previous_ticks=Time.get_ticks_usec()-100000; game._process(.1)
	check(game.sim.actors[0].pos.distance_to(resumed)<.001,"resume does not restore stale movement")
	game._unhandled_input(key(KEY_A,true)); game._input(key(KEY_A,false))
	check(game.keys.is_empty(),"release outside unhandled input clears movement")
	var mouse:=InputEventMouseButton.new(); mouse.button_index=MOUSE_BUTTON_LEFT; mouse.pressed=true; game._unhandled_input(mouse)
	check(game.shoot_held,"left mouse begins shooting")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused and not game.shoot_held and not game.pointer_active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"focus loss pauses and releases fire + cursor")
	var safe:Vector3=game.camera_safe_position(Vector3(13,1,12),Vector3(16,1,12))
	check(safe.x<14.0,"camera boom retracts before central cover")
	game.camera_yaw=0; game.set_paused(false); game.input_guard=0; game._unhandled_input(key(KEY_W,true))
	check(game._command().move.distance_to(Vector2.UP)<.001,"movement follows changed camera yaw")
	game.clear_input()
	var motion:=InputEventMouseMotion.new(); motion.relative=Vector2(100,99999); game._unhandled_input(motion)
	check(game.camera_yaw<0 and game.camera_pitch>=-.75,"relative mouse look updates yaw and clamps pitch")
	game.restart()
	check(not game.paused and game.countdown_left==3.0 and game.sim.projectiles.is_empty() and game.sim.pods.is_empty(),"replay resets countdown/entities and pause")
	check(game.actor_cache.size()==4,"replay reuses one actor per participant")
	check(game.arena.get_meta("static_draw_batches",99)<=2,"static nursery uses shared material batches")
	if game.music: check(game.music.stream.loop_end>0 and game.music.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"music has explicit whole-track loop bounds")
	var exit_count:=[0]; game.exit_requested.connect(func():exit_count[0]+=1)
	game.leave_game(); game.leave_game()
	check(exit_count[0]==1 and not game.running and not game.is_processing() and not game.is_processing_unhandled_input() and not game.pointer_active and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"exit is idempotent and disables input/process")
	for voice in game.sounds.values(): check(not voice.playing,"exit stops effects")
	if game.music: check(not game.music.playing,"exit stops music")
	game.queue_free(); await create_timer(.5).timeout
	print("BLOOM RUNTIME ","PASS" if failures.is_empty() else "FAIL", " checks: wall clock, pause, focus, release, replay, surface, exit")
	quit(0 if failures.is_empty() else 1)
