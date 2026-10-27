extends SceneTree
## Same test executes inside the host project and a real module-only extraction.
var checks := 0
var failures: Array[String] = []
var exits := 0
class Store extends RefCounted:
	var value: Variant = null
	var writes := 0
	func load_game(_id: String) -> Variant: return value
	func save_game(id: String, data: Dictionary) -> void:
		assert(id=="tide_gulp"); value=data.duplicate(true); writes+=1
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var orphan_baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var store := Store.new()
	for cycle in 6:
		var game=load("res://modules/tide_gulp/main.tscn").instantiate()
		root.add_child(game)
		game.start({"seed":42,"save_service":store})
		game.set_process(false)
		game.exit_requested.connect(func(): exits+=1)
		check(game.running and game.sim.alive and not game.paused,"fresh entry begins a live run immediately")
		check(game.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and game.camera.position.z>0,"side-view orthographic camera observes XY")
		check(game.find_children("*","WorldEnvironment",true,false).is_empty(),"camera-local environment cannot replace island lighting")
		for visual in game.fish_cache.values(): check(is_zero_approx(visual.position.z),"rendered fish body matches collision depth plane")
		check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"no unwanted FPS capture")
		# Genuine simulated feeding drives the runtime event/result path.
		game.demo_mode=true
		for frame in 120: game._process(1.0/30.0)
		check(game.sim.elapsed>3.9 and game.sim.score>0,"runtime can earn points from legal ordinary input")
		if cycle==0:
			# Project a warning beyond the viewport edge; only presentation input
			# is replaced here. Simulation warning timing is tested separately.
			var original: Dictionary=game.latest_snapshot
			game.latest_snapshot=game.sim.snapshot()
			game.latest_snapshot.fish=[]
			var viewport_size: Vector2=game.get_viewport().get_visible_rect().size
			var beyond: Vector2=game.sim.player.pos+Vector2(13.8,0)
			var raw: Vector2=game.camera.unproject_position(Vector3(beyond.x,beyond.y,0))
			check(raw.x>viewport_size.x,"warning fixture really starts off-screen")
			for distance in [13.8,13.6,13.4]:
				game.latest_snapshot.fish.append({"pos":game.sim.player.pos+Vector2(distance,0),"length":4.8,"warning_left":1.2,"state":"alert"})
			game._update_hud()
			check(game.hud.state.warnings.size()==2,"HUD bounds simultaneous danger cues to the nearest two")
			for cue in game.hud.state.warnings:
				check(cue.pos.x>=48 and cue.pos.x<=viewport_size.x-48 and cue.pos.y>=105 and cue.pos.y<=viewport_size.y-95,"off-screen alert clamps inside the responsive viewport")
			game.latest_snapshot=original

		var paused: Dictionary=game.sim.snapshot()
		game.set_paused(true); paused=game.sim.snapshot()
		for frame in 6: game._process(.1)
		check(game.sim.snapshot()==paused,"pause stops all authoritative runtime changes")
		game.set_paused(false)
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(game.paused and game.keys.is_empty() and not game.dash_queued,"focus loss pauses and releases held controls")
		game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
		check(game.paused,"focus regain never silently resumes")
		game.set_paused(false)
		var earned: int=game.sim.score
		var writes: int=store.writes
		game.restart(); game.set_process(false)
		check(game.sim.score==0 and game.sim.player.stage==1 and game.sim.alive and not game.paused,"restart resets score, growth, life and pause")
		check(game.best_score>=earned and store.writes==writes+1,"restart saves earned result exactly once")
		# Controlled terminal fixture tests UI lifecycle, not legal-play progress.
		game.sim.fish.clear()
		game.sim.player.pos=Vector2(24,0)
		game.sim._update_world(); game.sim.fish.clear()
		var enemy := {"id":9999,"species":"ribbon","pos":Vector2(23.04,0),"dir":Vector2.RIGHT,"length":2.0,"armed":true}
		game.sim.fish.append(enemy)
		game.sim._check_contacts(); game._handle_events()
		check(not game.sim.alive and game.match_recorded,"predator mouth triggers death and records result")
		var dead: Dictionary=game.sim.snapshot()
		writes=store.writes
		for frame in 6: game._process(.1)
		check(game.sim.snapshot()==dead and store.writes==writes,"dead result cannot continue score/time or save repeatedly")
		game.restart(); game.set_process(false)
		check(game.sim.alive and game.running and not game.match_recorded,"result restart starts a genuinely new round")
		check(game.fish_root.get_child_count()<=81 and game.chunk_cache.size()==5,"renderer pool bounded across death/restart")
		game.leave_game(); game.leave_game()
		check(exits==cycle+1 and not game.running and not game.is_processing(),"one return request; repeated leave idempotent")
		check(not game.audio.get_debug_state().music_playing and not game.hud.is_processing(),"return retires music and HUD processing")
		game.queue_free()
		await process_frame
		await process_frame
		check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==orphan_baseline,"repeat entry/exit does not leak orphan nodes")
	await create_timer(.6).timeout
	print("TIDE INDEPENDENT LIFECYCLE: %d checks; %s" % [checks,"PASS" if failures.is_empty() else JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
