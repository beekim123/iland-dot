extends SceneTree
const Scene = preload("res://modules/apprentice_yokai_king/main.tscn")
func _initialize(): call_deferred("run")
func run():
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	assert(game.started and not game.hosted and not auto_accept_quit)
	print("YOKAI independent WM close: invoking real notification; shutdown must exit normally")
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	await create_timer(2.0).timeout
	printerr("FAIL: independent WM close did not terminate")
	quit(1)
