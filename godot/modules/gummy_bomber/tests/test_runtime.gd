extends SceneTree
## Regression: low rendering FPS must not stretch the fuse or movement clock.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://modules/gummy_bomber/main.tscn").instantiate()
	root.add_child(game)
	game.start({"seed": 42})
	game.set_process(false)
	for enemy in game.sim.enemies: enemy.wait = 999.0
	var batch_count: int = game.board.get_child_count()
	game.sim.place_bomb()
	game.sim.player = Vector2i(5, 1)
	for i in 9:
		OS.delay_msec(300)
		# Deliberately supply an inaccurate engine delta; wall clock governs rules.
		game._process(0.016)
	var ok: bool = game.sim.bombs.is_empty() and batch_count < 30
	print("GUMMY RUNTIME: static batches=%d, bomb after 2.7 wall seconds=%d, pass=%s" % [batch_count, game.sim.bombs.size(), ok])
	game.leave_game(); game.queue_free()
	await create_timer(0.5).timeout
	quit(0 if ok else 1)
