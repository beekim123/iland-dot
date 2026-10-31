extends SceneTree
const Rules = preload("res://modules/moon_post/rules.gd")
var failures := 0
var checks := 0
var exit_count := 0

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize():
	call_deferred("run")

func run():
	var model = Rules.new()
	check(model.levels.size() == 12,"12 levels")
	for i in range(model.levels.size()):
		model.reset(i)
		var initial: Array = model.positions.duplicate()
		check(not model.won(),"not initially won %d" % i)
		var solution: String = model.solve()
		check(solution != "!","BFS solvable %d" % i)
		check(solution.length() == int(model.levels[i].par),"shortest par verified %d" % i)
		var gate_entries := 0
		for direction in solution:
			var before: Array = model.positions.duplicate()
			var before_gate: bool = model.gates_open(before)
			var count: int = model.moves
			check(model.move(int(direction)),"optimal solution has no no-ops")
			var after: Array = model.positions.duplicate()
			for courier in range(after.size()):
				if after[courier] != before[courier] and model.tile(after[courier]) == "g": gate_entries += 1
			check(model.undo(),"undo available")
			check(model.positions == before and model.moves == count,"undo restores positions and moves")
			check(model.gates_open(model.positions) == before_gate,"undo restores gate state")
			model.move(int(direction))
			check(model.positions == after,"deterministic replay")
		check(model.won(),"BFS replay delivery %d" % i)
		if i >= 6: check(gate_entries > 0,"gate lesson actually crosses a gate %d" % i)
		model.reset(i)
		check(model.positions == initial and model.moves == 0 and model.history.is_empty(),"restart exact")
		check(not model.undo(),"no undo beyond beginning")
		for d in model.levels[i].solution: model.move(int(d))
		check(model.won(),"baked solution verified %d" % i)
		print("MOON POST level %02d shortest=%d replay=PASS" % [i+1,solution.length()])
	# Focused gate proof. Opening is evaluated at departure; gate occupants can leave after closing.
	model.levels.append({"grid":["#######","#.sg..#","#.....#","#######"],"starts":[[2,1],[4,1]],"goals":[[3,1],[5,1]]})
	model.reset(12)
	check(model.gates_open(model.positions),"plate opens gate")
	model.move(1)
	check(model.positions == [Vector2i(3,1),Vector2i(5,1)],"last plate departure can cross gate")
	check(not model.gates_open(model.positions),"gate closes after plate departure")
	model.move(1)
	check(model.positions[0] == Vector2i(4,1),"closed gate occupant can leave")
	model.undo(); model.undo()
	check(model.gates_open(model.positions),"undo reopens plate")
	model.positions = [Vector2i(4,1),Vector2i(5,2)]
	model.move(3)
	check(model.positions[0] == Vector2i(4,1),"closed gate blocks entry")
	# Scene lifecycle, UI flows, full campaign and namespaced profile.
	var game = load("res://modules/moon_post/main.tscn").instantiate()
	root.add_child(game)
	game.exit_requested.connect(func(): exit_count += 1)
	game.start({"game_id":"moon_post","save_dir":"user://games/moon_post","schema_version":1})
	game.start({})
	await process_frame
	check(game.started and game.phase == "title","idempotent hosted start")
	game.show_help(); check(game.phase == "help" and game.previous_phase == "title","title help")
	game.change_phase(game.previous_phase)
	check(game.phase == "title","help returns to title")
	game.play_level(0)
	game.change_phase("pause")
	game.do_move(1)
	check(game.model.moves == 0,"pause blocks movement")
	game.change_phase("play")
	game.swipe_start = Vector2(200,300); game.swiping = true
	game.finish_swipe(Vector2(260,300))
	check(game.model.moves == 1,"swipe movement")
	game.undo_move(); check(game.model.moves == 0,"UI undo")
	for i in range(12):
		game.play_level(i)
		for direction in game.model.levels[i].solution: game.do_move(int(direction))
		check(game.phase == "win","UI win %d" % i)
		check(game.unlocked >= mini(12,i+2),"progress unlock %d" % i)
		game.advance()
	check(game.phase == "ending","campaign ending")
	game.change_phase("levels"); check(game.buttons.size() == 13,"12 level selectors and back")
	game.request_exit(); game.request_exit()
	check(exit_count == 1,"exit exactly once")
	game.queue_free()
	await process_frame
	# Let the audio thread release synthesized WAV resources before process shutdown.
	await create_timer(0.7).timeout
	print("MOON POST TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
