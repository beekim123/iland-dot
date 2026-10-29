extends SceneTree
const Scene = preload("res://modules/woodland_duel/main.tscn")
const Rules = preload("res://modules/woodland_duel/rules.gd")
const AI = preload("res://modules/woodland_duel/ai.gd")
const Store = preload("res://modules/woodland_duel/profile_store.gd")
var checks := 0
var failures := 0
var exits := 0
func _initialize() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("woodland-storage-test"):
		printerr("FAIL runtime fixture requires isolated woodland-storage-test XDG_DATA_HOME")
		quit(2); return
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1; printerr("FAIL independent runtime: " + label)
func new_game():
	var game = Scene.instantiate()
	root.add_child(game)
	game.start({"game_id":"woodland_duel","save_root":"user://games/woodland_duel/","schema_version":1})
	game.set_process(false)
	return game
func run() -> void:
	var input_before := InputMap.get_actions().duplicate()
	var quit_before := auto_accept_quit
	var orphan_before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var game = new_game()
	check(game.started and game.running and game.phase == "select","host starts on deck selection")
	game.choose_deck("spores"); game.begin_match()
	# A boundary UI fixture: rule-legal targeted battlecry with zero valid targets.
	game.game_state = Rules.new_match("spores","forest",71,0)
	game.game_state.players[0].hand = ["spore_spitter"]
	game.game_state.players[0].mana = 3
	game.select_hand(0); game.play_selected()
	check(game.game_state.players[0].board.size() == 1 and game.game_state.players[0].hand.is_empty(),"UI plays target-optional battlecry when enemy board is empty")
	# From here all completion evidence uses untouched new_match states and public UI actions.
	for deck in ["forest","toys","spores"]:
		game.return_to_selection(); game.choose_deck(deck); game.begin_match()
		game.game_state = Rules.new_match(deck,"forest",20261029,0)
		var before_matches: int = game.profile.matches
		var choices := 0
		while game.phase == "match" and choices < 900:
			if game.game_state.current_player == 1:
				game._process(2.0)
			else:
				var action: Dictionary = AI.choose_action(game.game_state)
				var actions_before: int = game.game_state.actions_taken
				match action.type:
					"play":
						game.select_hand(action.hand_index)
						if action.has("target"): game.choose_target(action.target)
						else: game.play_selected()
					"attack":
						game.select_attacker(action.attacker_uid); game.choose_target(action.target)
					"end_turn": game.end_turn()
				check(game.game_state.actions_taken == actions_before+1,"human-facing public command performs one legal move")
			choices += 1
		check(game.phase == "result" and game.game_state.winner != -2,"public action lifecycle reaches a real result with "+deck)
		check(game.profile.matches == before_matches+1,"result counted exactly once")
		var terminal: Dictionary = game.game_state.duplicate(true)
		game.end_turn(); game.select_hand(0); game._process(50); game._finish_match()
		check(game.game_state == terminal and game.profile.matches == before_matches+1,"terminal UI actions and duplicate result callback are idempotent")
		game.retry_match()
		check(game.phase == "match" and game.game_state.winner == -2 and not game.result_recorded,"replay creates fresh actionable match")
	game.exit_requested.connect(func(): exits+=1)
	game.request_exit(true)
	await create_timer(0.7).timeout
	check(exits == 1,"normal public return emits exit once")
	game.queue_free(); await process_frame; await process_frame
	for cycle in 3:
		game = new_game(); game.begin_match()
		game.game_state = Rules.new_match("forest","toys",51+cycle,1)
		game.ai_delay = 0.3
		var pending: Dictionary = game.game_state.duplicate(true)
		game.set_paused(true); game._process(10)
		check(game.game_state == pending,"pause freezes pending AI action")
		game.set_paused(false); game.request_exit()
		check(game.modal == "exit" and game.running and game.paused,"exit confirmation leaves match alive and paused")
		game._process(10)
		check(game.game_state == pending,"AI cannot run behind exit confirmation")
		game.cancel_exit(); check(game.running and not game.paused and game.modal.is_empty(),"cancel exit resumes without replacing match")
		game.exit_requested.connect(func(): exits+=1)
		var audio_ref: WeakRef = weakref(game.audio)
		game.request_exit(); game.confirm_exit(); game.confirm_exit()
		game._process(10); game.end_turn()
		check(not game.running and game.ai_delay == 0 and game.game_state == pending,"confirmed exit cancels pending AI immediately")
		await create_timer(0.7).timeout
		check(exits == cycle+2,"repeated confirm emits one exit only")
		check(game.game_state == pending and not game.is_processing(),"no late AI action after asynchronous audio retirement")
		game.queue_free(); await process_frame; await process_frame
		check(audio_ref.get_ref() == null,"audio owner freed after retirement")
	# Abrupt owner free while AI and asynchronous fade are pending must not resurrect work.
	game = new_game(); game.begin_match(); game.game_state = Rules.new_match("forest","toys",91,1)
	game.ai_delay = 0.01
	game.confirm_exit(); game.queue_free()
	await process_frame; await process_frame; await create_timer(0.5).timeout
	check(InputMap.get_actions() == input_before,"module never mutates global InputMap")
	check(auto_accept_quit == quit_before,"exit restores global auto-quit behavior")
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == orphan_before,"all runtime cycles leave no orphan nodes")
	await protected_runtime_profile()
	print("WOODLAND INDEPENDENT RUNTIME: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func protected_runtime_profile() -> void:
	DirAccess.make_dir_recursive_absolute(Store.SAVE_DIR)
	var future: Dictionary = Store.new().fresh(); future.schema = 999
	var bytes := JSON.stringify(future)
	var file := FileAccess.open(Store.SAVE_PATH,FileAccess.WRITE); file.store_string(bytes); file.close()
	var game = new_game()
	check(not game.store.allowed and game.running,"future profile still allows temporary gameplay")
	game.choose_deck("toys"); game.change_volume(0.3); game.toggle_music(); game.toggle_motion(); game.begin_match()
	game.request_exit(true); await create_timer(0.7).timeout
	check(FileAccess.get_file_as_string(Store.SAVE_PATH) == bytes,"UI settings/gameplay/exit preserve future profile bytes")
	game.queue_free(); await process_frame; await process_frame
