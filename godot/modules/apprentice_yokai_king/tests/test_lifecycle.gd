extends SceneTree
const Scene = preload("res://modules/apprentice_yokai_king/main.tscn")
var exits = 0
func _initialize(): call_deferred("run")
func run():
	root.size = Vector2i(1280,800)
	var actions = InputMap.get_actions().duplicate()
	for i in range(4):
		var game = Scene.instantiate()
		game.exit_requested.connect(func(): exits += 1)
		root.add_child(game)
		game.start({"game_id":"apprentice_yokai_king","save_root":"user://games/apprentice_yokai_king"})
		await process_frame
		assert(game.started and game.model.phase == "title")
		if i == 0:
			# A button event carrying coordinates must work without mouse motion first.
			game.buttons = [{"id":"start","rect":Rect2(170,458,420,72)}]
			var click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true
			click.position = game.get_global_transform_with_canvas()*Vector2(338,492)
			Input.parse_input_event(click)
			Input.flush_buffered_events()
			await process_frame
			assert(game.model.phase == "practice", "Coordinate-only input click starts practice")
		else: game.new_run()
		game.model.advance(1.0/240.0,{"press":true})
		game.pause_run()
		game.pause_run() # repeated pause is idempotent; never lose paused_from
		var before = game.model.practice_time
		await process_frame
		assert(game.model.practice_time == before)
		game.action("exit")
		assert(game.quit_confirm)
		game.action("cancel_exit")
		game.resume_run()
		assert(game.model.phase == "practice")
		game.model.advance(1.0/120.0,{})
		assert(game.model.charge < 0 and game.model.queued.is_empty(), "pause discards sub-step queued press")
		game.exit_game()
		await create_timer(0.7).timeout
		assert(exits == i+1)
		game.queue_free()
		await process_frame
	assert(actions == InputMap.get_actions())
	print("YOKAI lifecycle 4 host entry/pause/confirm/cancel/resume/exit cycles PASS; no global InputMap mutations")
	quit()
