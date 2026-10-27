extends SceneTree
## Admission gate before host enablement: resolve, load, instantiate, then boot.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path := "res://modules/tide_gulp/main.tscn"
	if not ResourceLoader.exists(path):
		printerr("TIDE RESOURCE GATE FAIL: missing scene")
		quit(1); return
	var scene := ResourceLoader.load(path) as PackedScene
	if scene == null:
		printerr("TIDE RESOURCE GATE FAIL: not a PackedScene")
		quit(1); return
	var game := scene.instantiate()
	if game == null or not game.has_method("start") or not game.has_signal("exit_requested"):
		if game != null: game.free()
		printerr("TIDE RESOURCE GATE FAIL: host ABI")
		quit(1); return
	root.add_child(game)
	await process_frame
	await process_frame
	var ok: bool = game.has_started and game.running and game.sim.alive and game.fish_cache.size() > 0
	game.leave_game()
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(.6).timeout
	print("TIDE RESOURCE GATE: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
