extends SceneTree
const Scene = preload("res://modules/apprentice_yokai_king/main.tscn")
const Model = preload("res://modules/apprentice_yokai_king/run_model.gd")
func _initialize(): call_deferred("run")
func mouse(game, pressed: bool, right: bool = false):
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	event.position = Vector2(800,440); event.pressed = pressed
	Input.parse_input_event(event); Input.flush_buffered_events()
func key(code: int, pressed: bool, echo: bool = false):
	var event = InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed; event.echo = echo
	Input.parse_input_event(event); Input.flush_buffered_events()
func run():
	root.size = Vector2i(1280,800)
	var game = Scene.instantiate()
	game.exit_requested.connect(func(): pass)
	root.add_child(game)
	game.start({"game_id":"apprentice_yokai_king"})
	await process_frame
	key(KEY_ENTER,true); key(KEY_ENTER,true,true)
	await process_frame
	assert(game.model.phase == "title", "held Enter cannot reenter module")
	key(KEY_ENTER,false)
	game.new_run()
	game.profile.data.settings.charge_mode = "hold_primary"
	mouse(game,true)
	await create_timer(0.08).timeout
	mouse(game,false)
	await create_timer(0.15).timeout
	assert(game.model.attack_id == 1 and not game.model.attack.heavy)
	await create_timer(0.4).timeout
	game.profile.data.settings.charge_mode = "right_charge"
	mouse(game,true,true); mouse(game,false,true)
	await create_timer(0.85).timeout
	assert(game.model.charge >= 0.75 and game.model.attack_id == 1)
	mouse(game,true,true); mouse(game,false,true)
	await create_timer(0.15).timeout
	assert(game.model.attack_id == 2 and game.model.attack.full)
	key(KEY_ESCAPE,true); key(KEY_ESCAPE,false)
	var before = game.model.practice_time
	await create_timer(0.2).timeout
	assert(game.model.phase == "paused" and game.model.practice_time == before)
	game.exit_game(); await create_timer(0.65).timeout
	game.queue_free(); await process_frame
	# A real no-input failed run, followed by a clean retry; no HP/state injection.
	var m = Model.new(); m.reset(2081,"standard",false)
	for i in range(120*60):
		m.advance(1.0/60.0,{})
		if m.phase == "lost": break
	assert(m.phase == "lost" and m.hp == 0 and m.attack_id == 0)
	m.reset(2081,"standard",false)
	assert(m.hp == 5 and m.wave == 1 and m.phase == "countdown" and m.build.chosen_count == 0 and m.attack_id == 0)
	print("YOKAI event input PASS: Enter guard, short primary, accessible toggle-charge, pause freeze; actual no-input defeat then clean retry")
	quit()
