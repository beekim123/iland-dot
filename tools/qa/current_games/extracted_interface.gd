extends SceneTree
## Exercises the public interface in a genuinely extracted project, not process-level standalone exit.
var exits := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var scene := load(path) as PackedScene
	assert(scene != null, "Extracted main scene loads")
	var game := scene.instantiate()
	assert(game.has_method("start") and game.has_signal("exit_requested"), "Public interface exists")
	game.exit_requested.connect(func(): exits += 1)
	root.add_child(game)
	var id: String = path.split("/")[3]
	game.start({"game_id": id, "save_root": "user://games/" + id + "/", "schema_version": 1})
	for frame in 10: await process_frame
	if id == "woodland_duel": game.request_exit(true)
	elif game.has_method("request_exit"): game.request_exit()
	elif game.has_method("exit_game"): game.exit_game()
	else: game.leave_game()
	for attempt in 100:
		if exits > 0: break
		await create_timer(.02).timeout
	assert(exits == 1, "Public exit emitted exactly once")
	game.queue_free()
	for frame in 3: await process_frame
	await create_timer(0.7).timeout
	print("CURRENT_EXTRACTED_INTERFACE_PASS: ", id)
	quit()
