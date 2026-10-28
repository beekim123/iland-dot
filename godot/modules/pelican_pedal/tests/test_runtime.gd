extends SceneTree
const Driver=preload("legal_driver.gd")
var checks:=0
var failed:=false
var exits:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failed=true;printerr("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var baseline:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for cycle in 3:
		var game=load("res://modules/pelican_pedal/main.tscn").instantiate();root.add_child(game);game.start({"save_root":"user://games/pelican_pedal/"});game.set_process(false)
		check(game.running and game.has_started,"start ABI")
		check(game.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and is_equal_approx(game.camera.position.y,1.68),"first person perspective")
		game.retry();game.set_process(false)
		var before=game.sim.snapshot();game.set_paused(true)
		game._process(.8);check(game.sim.snapshot()==before,"paused clock/physics frozen")
		game.set_paused(false)
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);check(game.paused and game.keys.is_empty(),"focus loss pauses/releases")
		game.set_paused(false)
		var driver=Driver.new()
		for frame in 12000:
			game.sim.command(driver.command(game.sim));game.sim.tick(1.0/60);game._handle_events()
			if game.sim.phase=="complete":break
		check(game.sim.phase=="complete" and game.result_shown,"normal-command delivery reaches result")
		game._present(0)
		var visible_parcels:=0
		for parcel in game.cargo_items:
			if parcel.visible:visible_parcels+=1
		check(visible_parcels==0,"delivered packages leave basket")
		var completed:int=game.profile.completed;var score:int=game.profile.total_score
		game._handle_events();game._process(.5)
		check(game.profile.completed==completed and game.profile.total_score==score,"result accounting idempotent")
		game.next_job();check(game.sim.phase=="pickup" and game.sim.job_index>=1 and not game.paused,"next job starts")
		game.exit_requested.connect(func():exits+=1)
		game.leave_game();game.leave_game();check(exits==cycle+1,"exit exactly once")
		check(not game.music.playing and not game.cue.playing and not game.is_processing(),"exit stops audio/processing")
		var weak: WeakRef=weakref(game.music);game.queue_free();await process_frame;await process_frame
		check(weak.get_ref()==null,"audio freed")
		check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline,"no orphan leak")
	await create_timer(.3).timeout
	print("PELICAN RUNTIME ",checks," checks; ","FAIL" if failed else "PASS");quit(1 if failed else 0)
