extends SceneTree
## Same entry, two ownership modes: host stays alive; standalone closes itself.
var exits := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://modules/gummy_bomber/main.tscn").instantiate()
	root.add_child(game)
	var standalone := OS.get_cmdline_user_args().has("standalone")
	if standalone:
		current_scene = game
	else:
		game.exit_requested.connect(func(): exits += 1)
	await process_frame
	await process_frame
	if not game.running:
		printerr("FAIL exit fixture did not autostart"); quit(1); return
	game.leave_game()
	game.leave_game()
	if game.running or game.is_processing() or game.hud.visible:
		printerr("FAIL exit did not stop gameplay"); quit(1); return
	if standalone:
		print("GUMMY STANDALONE EXIT: waiting for actual process shutdown")
		await create_timer(2).timeout
		printerr("FAIL standalone left frozen process"); quit(1)
	else:
		await create_timer(0.1).timeout
		if exits != 1:
			printerr("FAIL host exit signal count ", exits); quit(1); return
		game.queue_free()
		await process_frame
		await create_timer(0.5).timeout
		print("GUMMY HOST EXIT: signal once; host alive; PASS")
		quit(0)
