extends SceneTree
var failures: Array[String] = []
var exit_count := 0
var quit_count := 0
class Store extends RefCounted:
	var value: Variant = null
	var writes := 0
	func load_game(_id: String) -> Variant: return value
	func save_game(_id: String, data: Dictionary) -> void:
		value = data.duplicate(true)
		writes += 1
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func key_event(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event
func check_head_alignment(game, body: Dictionary, label: String) -> void:
	var head_axis: Vector3 = game.player_visual.global_basis.x.normalized()
	var expected := Vector3(body.dir.x,body.dir.y,0.0)
	check(head_axis.dot(expected) > 0.99999 and absf(head_axis.z) < 0.00001,label + ": model +X equals authoritative XY mouth direction")
	var center: Vector3 = game.player_visual.global_position
	var model_mouth: Vector2 = game.camera.unproject_position(center + head_axis * float(body.length) * 0.48)
	var sim_mouth: Vector2 = game.camera.unproject_position(center + expected * float(body.length) * 0.48)
	check(model_mouth.distance_to(sim_mouth) < 0.01,label + ": projected visible mouth equals simulation mouth")

func run() -> void:
	var game = load("res://modules/tide_gulp/main.tscn").instantiate()
	root.add_child(game)
	var store := Store.new()
	game.start({"seed":42,"save_service":store})
	game.set_process(false)
	game.exit_requested.connect(func(): exit_count += 1)
	check(game.running and not game.paused,"starts immediately without a blocking tutorial")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"pointer is visible, never captured")
	check(game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL,"independent near-orthographic side view")
	check(game.camera.position.z > 10.0 and absf(game.camera.rotation.z) < 0.0001,"camera observes XY without roll")
	check(game.fish_cache.size() == game.sim.fish.size(),"every authoritative fish has a real model")
	check(game.chunk_cache.size() == game.sim.chunks.size(),"only authoritative active chunks are rendered")
	check(game.bubble_pool.size() == 24,"swallow and death effects use a fixed bounded pool")
	game._bubble_burst(Vector2.ZERO,6)
	game._update_bubbles(1.0)
	var clear_bubbles := true
	for bubble in game.bubble_pool: clear_bubbles = clear_bubbles and not bubble.node.visible
	check(clear_bubbles,"short-lived feedback retires without allocating nodes")
	# All eight planar headings must agree with the visible model's +X head,
	# including both left diagonals (the former YXZ Euler sign regression).
	var pose_body: Dictionary = game.sim.player.duplicate(true)
	pose_body.pos = Vector2.ZERO
	pose_body.velocity = Vector2.ZERO
	var headings := [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1),Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]
	for heading in headings:
		pose_body.dir = heading.normalized()
		game._sync_fish_visual(game.player_visual,pose_body,-1,0.2)
		check_head_alignment(game,pose_body,"eight-way heading " + str(heading))
	# The genuine 3D side reveal takes time, but the mouth never rotates out
	# of the authoritative gameplay plane, even during a fast reversal.
	for heading in [Vector2(-1,1).normalized(),Vector2(1,-1).normalized()]:
		game._set_fish_orientation(game.player_visual,-heading,0.0,true)
		pose_body.dir = heading
		for frame in 12:
			game._sync_fish_visual(game.player_visual,pose_body,-1,1.0/60.0)
			check_head_alignment(game,pose_body,"turn frame %d" % frame)
			if frame == 0:
				var roll: float = game.player_visual.get_meta("face_roll")
				check(roll > 0.01 and roll < PI-0.01,"side reveal is a real intermediate 3D pose, not an instantaneous flip")
	pose_body.dir = Vector2(-1,0)
	game.player_visual.set_meta("pose_initialized",false)
	game._sync_fish_visual(game.player_visual,pose_body,-1,0.0)
	check(is_equal_approx(float(game.player_visual.get_meta("face_roll")),PI),"fresh or pooled actor starts on the correct side without stale interpolation")
	pose_body.dir = Vector2(0.04,1).normalized()
	game._sync_fish_visual(game.player_visual,pose_body,-1,0.3)
	check(is_equal_approx(float(game.player_visual.get_meta("face_roll")),PI),"nearly vertical headings keep their side instead of flip-flopping")
	check_head_alignment(game,pose_body,"near-vertical hysteresis")
	game.player_visual.set_meta("pose_initialized",false)
	game._sync_world(0.0)
	var nodes: int = game.fish_root.get_child_count()
	for index in 15: game._process(1.0/60.0)
	check(game.fish_root.get_child_count() == nodes,"ordinary frames never recreate models")
	game._input(key_event(KEY_W,true))
	check(game.input_mode == "keyboard" and game._player_command().move == Vector2(0,1),"W selects equivalent keyboard swimming")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(900,300)
	motion.relative = Vector2(40,0)
	game._input(motion)
	check(game.input_mode == "keyboard","mouse motion cannot steal a held movement key")
	game._input(key_event(KEY_W,false))
	motion.relative = Vector2(1,1)
	game._input(motion)
	check(game.input_mode == "keyboard","minor pointer jitter cannot steal keyboard mode")
	motion.relative = Vector2(20,0)
	game._input(motion)
	check(game.input_mode == "mouse" and game.pointer_intent,"deliberate pointer movement switches input explicitly")
	game._unhandled_input(key_event(KEY_SPACE,true))
	check(game.input_mode == "keyboard" and game.dash_queued,"Space is the keyboard dash equivalent")
	game.set_paused(true)
	var paused_time: float = game.sim.elapsed
	game._process(1.0)
	check(game.sim.elapsed == paused_time and game.keys.is_empty() and not game.dash_queued,"pause freezes simulation and clears held input")
	game.set_paused(false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused,"focus loss pauses instead of killing an absent player")
	game.set_paused(false)
	var initial_ratio: float = float(game.sim.player.length)/game.camera.size
	game.sim.player.length = 3.05
	game.sim.player.stage = 6
	game.latest_snapshot = game.sim.snapshot()
	game._update_camera(1.0,true)
	var grown_ratio: float = float(game.sim.player.length)/game.camera.size
	check(grown_ratio > initial_ratio*2.0,"camera pullback does not cancel visible growth")
	game.sim.score = 85
	game.sim.elapsed = 24.0
	game.restart()
	game.set_process(false)
	check(game.sim.score == 0 and game.sim.player.stage == 1 and not game.paused,"restart returns to a clean live small fish")
	check(game.best_score == 85 and game.best_time == 24.0,"restart preserves earned local records")
	check(game.fish_root.get_child_count() <= game.MAX_FISH_NODES+1,"restart reuses a bounded species pool")
	for cycle in 3:
		game.leave_game()
		check(not game.running and not game.is_processing() and game.keys.is_empty(),"exit stops processing and clears inputs")
		game.start({"seed":42+cycle,"save_service":store})
		game.set_process(false)
		check(game.running and game.sim.elapsed == 0 and not game.paused,"re-entry starts fresh without lingering elapsed time")
	game.leave_game()
	check(exit_count == 4,"each leave emits one host route request")
	check(game._record_fps_from_arg("NaN") == 12 and game._record_fps_from_arg("0") == 12 and game._record_fps_from_arg("60") == 60,"capture FPS rejects bad and out-of-range input")
	game.start({"seed":47,"save_service":store,"quit_handler":func(): quit_count += 1})
	game.set_process(false)
	game.sim.score = 96
	game.request_application_quit()
	game.request_application_quit()
	check(quit_count == 1 and not game.running and game.match_recorded,"ordinary window close records and deactivates before one host quit callback")
	check(store.value.best_score == 96,"window close does not drop the final run record")
	check(not game.audio.get_debug_state().music_playing and not game.hud.is_processing(),"exit stops all audio and HUD processing")
	game.queue_free()
	await process_frame
	await create_timer(0.6).timeout
	print("TIDE RUNTIME ","PASS" if failures.is_empty() else "FAIL"," eight-way/turn-frame mouth alignment; XY controls; pause; growth camera; pooled models; repeated exits")
	quit(0 if failures.is_empty() else 1)
