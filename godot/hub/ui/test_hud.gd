extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var hud=load("res://hub/ui/island_hud.gd").new()
	root.add_child(hud); hud.set_muted(true); hud.set_status("拖动旋转")
	await process_frame
	hud.queue_free(); await process_frame
	print("ISLAND_HUD_OK"); quit()
