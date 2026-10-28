extends SceneTree
var game: Node
var exits: int = 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var previous_quit: bool = auto_accept_quit
	var previous_window: int = DisplayServer.window_get_mode()
	game = load("res://modules/dawn_sword/main.tscn").instantiate()
	game.exit_requested.connect(func(): exits += 1)
	root.add_child(game)
	game.start({"game_id":"dawn_sword","save_root":"user://forbidden"})
	await process_frame
	assert(game.started and game.hosted and game.menu == "title")
	assert(auto_accept_quit == previous_quit)
	await process_frame
	assert(root.gui_get_focus_owner() is Button)
	game._new_game()
	assert(game.menu == "")
	assert(game.storage.load_profile().ok and game.storage.load_profile().exists)
	game.pressed["jump_pressed"] = true
	game._process(0.001)
	assert(game.pressed.has("jump_pressed"))
	game._process(0.02)
	assert(game.rules.hero.vy<0)
	game._show_menu("pause")
	var x: float = game.rules.hero.x
	game._process(1.0)
	assert(game.rules.hero.x == x)
	game.rules.mode = "dead"
	game._resume()
	assert(game.menu == "dead")
	game.rules.retry()
	game._show_menu("title")
	game._show_menu("settings")
	assert(game.settings_return == "title")
	game.remap = "attack"
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	game._input(key)
	assert(game.keys.attack == KEY_K and game.keys.roll == KEY_J)
	game._show_menu("pause")
	game._resume()
	await game.request_exit()
	assert(exits == 1)
	assert(auto_accept_quit == previous_quit and DisplayServer.window_get_mode() == previous_window)
	game.queue_free()
	await process_frame
	await process_frame
	print("PASS hosted runtime, menu/settings/pause, retained substep edge, audio shutdown, exactly one hosted exit")
	quit()
