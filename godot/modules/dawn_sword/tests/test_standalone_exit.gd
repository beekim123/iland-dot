extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Node = load("res://modules/dawn_sword/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	assert(game.started and not game.hosted)
	print("Standalone automatic start verified; requesting normal audio-retired process exit")
	game.request_exit()
