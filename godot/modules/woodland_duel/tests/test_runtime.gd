extends SceneTree
## Headless behavior regression. Uses a read-only profile so local player data is untouched.
const Scene = preload("../main.tscn")
const Rules = preload("../rules.gd")
const AI = preload("../ai.gd")
var failed := false
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: push_error(message); failed = true
func run() -> void:
	var game = Scene.instantiate(); root.add_child(game); game.start({})
	game.store.allowed = false; game.set_process(false)
	await process_frame
	check(game.started and game.phase == "select", "Module starts at deck selection")
	check(game.view.font.has_char("林".unicode_at(0)), "Module includes Chinese font")
	for deck in ["forest", "toys", "spores"]:
		game.choose_deck(deck); game.begin_match(); game.set_process(false)
		game.game_state = Rules.new_match(deck, "toys", 707, 0)
		check(game.phase == "match", "Deck begins a complete match")
		check(game.game_state.players[0].hp == 20, "Match starts at 20 HP")
		game.set_paused(true)
		var before: String = JSON.stringify(game.game_state)
		game.end_turn(); game._process(4)
		check(JSON.stringify(game.game_state) == before, "Pause blocks player and AI")
		game.set_paused(false)
		var initial_matches: int = game.profile.matches
		var actions := 0
		while game.phase == "match" and actions < 600:
			var action: Dictionary = AI.choose_action(game.game_state)
			if game.game_state.current_player == 0:
				if action.type == "play":
					game.select_hand(action.hand_index)
					if action.has("target"): game.choose_target(action.target)
					else: game.play_selected()
				elif action.type == "attack": game.select_attacker(action.attacker_uid); game.choose_target(action.target)
				else: game.end_turn()
			else: game._apply_action(action)
			actions += 1
		check(game.phase == "result", "UI action adapters play through to a result: " + deck)
		check(game.profile.matches == initial_matches + 1, "Result records exactly once")
		game._finish_match()
		check(game.profile.matches == initial_matches + 1, "Duplicate result does not double count")
		game.retry_match(); game.set_process(false)
		check(game.phase == "match" and game.game_state.winner == -2, "Replay clears final state")
		game.return_to_selection()
		check(game.phase == "select" and game.game_state.is_empty(), "Deck selection clears old match")
	game.begin_match(); game.set_process(false)
	game.request_exit(); check(game.modal == "exit" and game.running, "Exit opens confirmation")
	game.cancel_exit(); check(game.modal.is_empty() and game.running and not game.paused, "Cancel resumes")
	game.change_volume(0); check(game.profile.volume == 0, "Mute setting clamps correctly")
	game.change_volume(2); check(game.profile.volume == 1, "Maximum volume clamps")
	var exit_count := [0]
	game.exit_requested.connect(func(): exit_count[0] += 1)
	game.confirm_exit(); game.confirm_exit()
	await create_timer(0.5).timeout
	check(exit_count[0] == 1 and not game.running and game.ai_delay == 0, "Repeated exit is idempotent")
	game.queue_free(); await process_frame; await process_frame
	print("woodland runtime: PASS" if not failed else "woodland runtime: FAIL")
	quit(1 if failed else 0)
