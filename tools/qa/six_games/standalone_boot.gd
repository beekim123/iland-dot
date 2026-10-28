extends SceneTree
## Run from a real freshly extracted project, without its island or siblings.
var exits := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene","")
	var scene := load(path) as PackedScene
	assert(scene != null,"Standalone main scene must load")
	var game := scene.instantiate()
	assert(game.has_method("start") and game.has_signal("exit_requested"),"Standalone keeps shell-independent interface")
	game.exit_requested.connect(func():exits+=1)
	root.add_child(game)
	for i in 5: await process_frame
	assert(game.get("has_started") and game.get("running"),"Real standalone scene autostarts")
	game.leave_game()
	for i in 2: await process_frame
	assert(exits==1 and not game.get("running"),"Standalone leave retires the actual module exactly once")
	game.queue_free()
	for i in 3: await process_frame
	await create_timer(.7).timeout
	print("SIX-GAME EXTRACTED BOOT PASS: ",path)
	quit()
