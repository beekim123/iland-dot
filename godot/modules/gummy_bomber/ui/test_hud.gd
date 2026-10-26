extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var hud=load("res://modules/gummy_bomber/ui/candy_hud.gd").new()
	root.add_child(hud)
	hud.update_state({"wave":2,"score":123,"paused":true})
	await process_frame
	hud.queue_free()
	await process_frame
	print("CANDY_HUD_OK")
	quit()
