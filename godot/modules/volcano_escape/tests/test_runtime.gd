extends SceneTree
var failures: Array[String] = []
class Store extends RefCounted:
	var value: Variant = null
	var reads := 0
	var writes := 0
	func load_game(_key: String) -> Variant: reads += 1; return value
	func save_game(_key: String,data: Dictionary) -> void: writes += 1; value = data.duplicate(true)
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func press_e(game) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E; event.pressed = true
	game._unhandled_input(event)
func release_e(game) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E; event.pressed = false
	game._input(event)
func tap_e(game) -> void:
	press_e(game); release_e(game)
	check(not game.keys.has(KEY_E) and game.interact_edge_pending,"same-frame press/release buffers edge without held key")
	game._process(0.02)
func walk_to(game,target: Vector2) -> void:
	var steps := 0
	while game.sim.pos.distance_to(target)>0.01 and steps<10000:
		game.sim.command({"move":((target-game.sim.pos)/(2.8*game.FIXED_DT)).limit_length(),"interact":false})
		game.sim.tick(game.FIXED_DT); steps += 1
	check(steps<10000,"tap regression reaches target through continuous movement")
	game.clear_input()
func test_same_frame_taps() -> void:
	var game = load("res://modules/volcano_escape/main.tscn").instantiate()
	root.add_child(game)
	game.start({"save_service":Store.new()}); game.set_process(false)
	game._new_run(0); game.set_process(false)
	walk_to(game,game.sim.map_data.nodes.H); walk_to(game,game.sim.map_data.nodes.K)
	game.sim.tick(120.1-game.sim.time)
	tap_e(game)
	check(game.sim.status=="success" and game.sim.result.exit=="boat","same-frame boat tap boards once")
	game._new_run(0); game.set_process(false)
	walk_to(game,game.sim.map_data.nodes.H); walk_to(game,game.sim.map_data.nodes.G); walk_to(game,game.sim.map_data.nodes.J)
	tap_e(game); game._process(1.2)
	check(game.sim.called_at<0 and game.sim.interaction.progress==0,"tap cannot masquerade as one-second airship call")
	press_e(game); game._process(1.1); release_e(game); game._process(0.02)
	check(game.sim.called_at>=0,"actual held one-second call works")
	game.sim.tick(310.0-game.sim.time)
	tap_e(game)
	check(game.sim.status=="success" and game.sim.result.exit=="airship","same-frame airship tap boards in second window at310")
	game._new_run(0); game.set_process(false)
	walk_to(game,game.sim.map_data.nodes.H); walk_to(game,game.sim.map_data.nodes.H+Vector2(1.5,0))
	tap_e(game)
	check(game.sim.lit_beacons.has("beacon_H"),"same-frame beacon tap lights beacon")
	game._new_run(0); game.set_process(false)
	walk_to(game,game.sim.map_data.nodes.D)
	tap_e(game); check(game.sim.shelter_id=="shelter_D","same-frame shelter tap enters")
	game._process(0.2); check(game.sim.shelter_id=="shelter_D","buffered edge fires once, not repeat")
	tap_e(game); check(game.sim.shelter_id=="","second deliberate shelter tap leaves")
	press_e(game); game._process(0.02)
	check(game.sim.shelter_id=="shelter_D","held shelter press enters once")
	release_e(game); tap_e(game)
	check(game.sim.shelter_id=="","same-frame release/repress after prior hold still delivers one new edge")
	game._new_run(0); game.set_process(false)
	walk_to(game,game.sim.map_data.nodes.B); walk_to(game,game.sim.map_data.nodes.C)
	game.sim.tick(135.1-game.sim.time)
	tap_e(game); game._process(3.5); game._process(3.5)
	check(game.sim.status=="running" and game.sim.interaction.progress==0,"tap balloon gets zero held-time, never six seconds")
	press_e(game); release_e(game); game.set_paused(true)
	check(not game.interact_edge_pending,"pause clears unconsumed tap")
	game.set_paused(false); game._process(0.1)
	check(game.sim.interaction.kind=="","resume cannot replay paused tap")
	press_e(game); release_e(game); game._new_run(0); game.set_process(false)
	check(not game.interact_edge_pending and game.keys.is_empty(),"new run clears unconsumed tap")
	game.leave_game(); game.queue_free()
	await process_frame
func run() -> void:
	await test_same_frame_taps()
	var original_quit := auto_accept_quit
	var game = load("res://modules/volcano_escape/main.tscn").instantiate()
	root.add_child(game)
	var store := Store.new()
	game.start({"save_service":store}); game.set_process(false)
	check(not auto_accept_quit,"native close suppressed during play")
	check(game.camera.projection==Camera3D.PROJECTION_ORTHOGONAL and game.camera.size==18,"local orthographic close-up")
	check(game.camera.environment!=null and game.find_children("*","WorldEnvironment").is_empty(),"camera-local environment only")
	var world_state: Dictionary = game.sim.snapshot()
	game.set_paused(true)
	game.sim.tick(10)
	check(game.sim.snapshot().time==world_state.time,"pause freezes authoritative time")
	game.set_paused(false)
	var low_fps_before: float = game.sim.time
	game._process(1.0/3.0)
	check(absf(game.sim.time-low_fps_before-1.0/3.0)<0.02,"3 FPS preserves world elapsed time")
	game.keys[KEY_W] = true
	var moving: Dictionary = game.input_command()
	check(moving.move.length()>0.99,"camera-relative WASD gives continuous movement")
	game.keys[KEY_E] = true
	check(game.input_command().move==moving.move and game.input_command().interact,"E preserves raw same-key movement intent for sim-owned stopping")
	var stopped_at: Vector2 = game.sim.pos
	game.sim.command(game.input_command()); game.sim.tick(0.1)
	check(game.sim.pos==stopped_at,"sim owns same-key E autostop")
	game.keys.erase(KEY_W); game.keys[KEY_D] = true
	check(game.input_command().move!=moving.move,"changed direction intent reaches sim while E held")
	game.sim.command(game.input_command()); game.sim.tick(0.1)
	check(game.sim.pos!=stopped_at,"changed direction unlocks actual movement")
	var released := InputEventKey.new(); released.physical_keycode = KEY_E; released.pressed = false
	game._input(released)
	check(game.input_command().move.length()>0.99 and not game.input_command().interact,"release E resumes still-held movement")
	game.clear_input()
	for script_id in 3:
		for exit_id in ["boat","balloon","airship"]:
			game.demo_exit = exit_id
			game.sim.start(script_id)
			game._plan_demo()
			var steps := 0
			while game.sim.status=="running" and steps<20000:
				var before: Vector2 = game.sim.pos
				game.sim.command(game._demo_command())
				game.sim.tick(game.FIXED_DT)
				check(game.sim.pos.distance_to(before)<=2.8*game.FIXED_DT+0.001,"demo never teleports")
				steps += 1
			check(game.sim.status=="success" and game.sim.result.exit==exit_id,"normal commands solve script %d via %s"%[script_id,exit_id])
			check(game.sim.lit_beacons.is_empty(),"beacons not exit admission requirement")
	# Reach balloon through normal route, then exercise runtime's held WASD+E
	# auto-stop and actual uninterrupted six-second interaction, including pause.
	game.demo_exit = "balloon"
	game.sim.start(0); game._plan_demo()
	while not game.demo_route.is_empty():
		var cmd: Dictionary = game._demo_command()
		cmd.interact = false
		game.sim.command(cmd); game.sim.tick(game.FIXED_DT)
	game.sim.command({"move":Vector2.ZERO,"interact":false})
	game.sim.tick(135.1-game.sim.time)
	game.keys[KEY_W] = true; game.keys[KEY_E] = true
	var at_balloon: Vector2 = game.sim.pos
	game.sim.command(game.input_command()); game.sim.tick(2)
	check(game.sim.status=="running" and game.sim.pos==at_balloon and game.sim.interaction.progress>1.99,"runtime E auto-stop holds balloon, not instant completion")
	game.keys.erase(KEY_W); game.keys[KEY_D] = true
	game.sim.command(game.input_command()); game.sim.tick(game.FIXED_DT)
	check(game.sim.interaction.kind=="" and game.sim.pos!=at_balloon,"changed direction cancels real balloon hold")
	game.keys.erase(KEY_D)
	game.sim.command(game.input_command()); game.sim.tick(0.1)
	check(game.sim.interaction.kind=="","release direction while E held cannot retrigger")
	game.keys.erase(KEY_E); game.sim.command(game.input_command())
	game.keys[KEY_W] = true; game.keys[KEY_E] = true
	game.sim.command(game.input_command()); game.sim.tick(2)
	check(game.sim.interaction.progress>1.99,"explicit new E starts a fresh hold")
	var progress_before: float = game.sim.interaction.progress
	game.set_paused(true)
	check(game.sim.interaction.progress==progress_before,"pause entry preserves six-second progress")
	var frozen: Dictionary = game.sim.snapshot()
	game.sim.tick(20)
	check(game.sim.snapshot()==frozen,"pause freezes all authoritative state including holds and warnings")
	game.set_paused(false)
	# Pause clears held keys for safety: a deliberate fresh hold is required.
	game.keys[KEY_W] = true; game.keys[KEY_E] = true
	game.sim.command(game.input_command()); game.sim.tick(5.9)
	check(game.sim.status=="running","fresh hold cannot complete early")
	game.sim.command(game.input_command()); game.sim.tick(0.2)
	check(game.sim.status=="success" and game.sim.result.exit=="balloon","held runtime input completes actual six seconds")
	game.clear_input()
	game._update_presentation(0)
	game._record_result(); game._record_result()
	check(game.profile.results.size()==1,"one completion record")
	game.start({"save_service":store}); game.set_process(false)
	check(game.sim.time==0 and game.sim.status=="running" and game.profile.results.size()==1,"re-entry starts fresh, retains only finished result")
	# Exact production app/app.gd context, without a test service: canonical
	# root is accepted as an identity assertion, never a configurable path.
	game.start({"game_id":"volcano_escape","save_root":"user://games/volcano_escape/","schema_version":1,"quit_handler":func(): pass})
	game.set_process(false)
	check(game.context_valid and game.save_write_allowed and game.debug_state().save_allowed,"real complete host context enables saving")
	check(game.save_data() and FileAccess.file_exists(game.SAVE_PATH),"real host context writes only fixed module profile")
	var host_profile: Variant = JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH))
	check(host_profile is Dictionary and host_profile.game_id=="volcano_escape" and not host_profile.has("snapshot"),"real host profile has fixed namespace and completed-only shape")
	for context in [{"game_id":"other"},{"schema_version":99},{"save_root":"user://foreign"},{"save_root":"user://games/volcano_escape"},{"save_root":"user://games/volcano_escape/../other/"},{"save_root":null}]:
		context.save_service = Store.new()
		game.start(context); game.set_process(false)
		check(not game.save_data() and context.save_service.value==null and context.save_service.reads==0 and context.save_service.writes==0,"foreign context cannot read or write")
	game.start({"save_service":store}); game.set_process(false)
	var exits := [0]
	game.exit_requested.connect(func(): exits[0]+=1)
	game.leave_game()
	check(exits[0]==1 and not game.running and auto_accept_quit==original_quit,"normal detach restores host policy")
	game.queue_free(); await process_frame; await process_frame
	var closing = load("res://modules/volcano_escape/main.tscn").instantiate()
	root.add_child(closing)
	var callbacks := [0]
	closing.start({"save_service":Store.new(),"quit_handler":func(): callbacks[0]+=1})
	closing.set_process(false)
	closing.request_application_quit(); closing.request_application_quit()
	check(callbacks[0]==1 and not auto_accept_quit,"shutdown idempotent and suppresses OS autoquit")
	closing.queue_free(); await process_frame
	check(not auto_accept_quit,"shutdown _exit_tree does not restore unsafe autoquit")
	auto_accept_quit = original_quit
	await create_timer(0.5).timeout
	print("VOLCANO RUNTIME ","PASS" if failures.is_empty() else "FAIL", " 9 continuous exits, same-frame E taps, held E, pause, fresh start, lifecycle")
	quit(0 if failures.is_empty() else 1)
