extends SceneTree
# Run in an extracted project. Exit success requires the production scene to quit
# its own process; the watchdog only quits on failure.
const Scene = preload("res://modules/woodland_duel/main.tscn")
const Rules = preload("res://modules/woodland_duel/rules.gd")
func _initialize() -> void: call_deferred("run")
func fail(message: String) -> void:
	printerr("FAIL independent standalone: "+message); quit(1)
func run() -> void:
	var game = Scene.instantiate(); root.add_child(game); current_scene = game
	await process_frame; await process_frame
	if not game.started or not game.running or game.phase != "select": fail("automatic startup"); return
	game.begin_match(); game.game_state = Rules.new_match("forest","toys",771,1)
	game.ai_delay = 1.0
	var pending: Dictionary = game.game_state.duplicate(true)
	game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	if game.modal != "exit" or not game.paused or game.exit_intent != "window": fail("window-close notification did not request confirmation"); return
	await create_timer(0.3).timeout
	if not game.running or game.game_state != pending: fail("window-close confirmation failed to freeze pending AI"); return
	game.cancel_exit()
	if not game.running or game.paused or not game.modal.is_empty(): fail("cancel window close did not resume"); return
	game.request_exit()
	if game.exit_intent != "home": fail("normal exit reused canceled window-close intent"); return
	print("WOODLAND INDEPENDENT STANDALONE: automatic start, WM confirm/cancel and pending AI freeze PASS; requesting production process exit")
	game.confirm_exit()
	await create_timer(3.0).timeout
	fail("production confirm_exit did not terminate standalone process")
