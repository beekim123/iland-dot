extends SceneTree
const Scene=preload("../main.tscn")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	for size_value in [Vector2i(1280,800),Vector2i(960,600),Vector2i(800,600),Vector2i(640,360)]:
		root.size=size_value;root.content_scale_size=size_value
		var game=Scene.instantiate();root.add_child(game);game.start({"seed":42});game.set_process(false)
		await process_frame;await process_frame
		game.set_paused(true);await process_frame;await process_frame
		var view:=Rect2(Vector2.ZERO,Vector2(size_value))
		print("UI BOUNDS ",size_value," hud ",game.hud.size," panel ",game.hud.panel.get_global_rect()," min ",game.hud.panel.get_combined_minimum_size())
		check(view.encloses(game.hud.panel.get_global_rect()),"pause panel fits %s"%size_value)
		for button in [game.hud.resume_button,game.hud.retry_button,game.hud.exit_button]:check(view.encloses(button.get_global_rect()),"modal action fits %s"%size_value)
		game.hud.collection_requested.emit();await process_frame;await process_frame
		check(game.paused and game.hud.collection_open and not game.hud.retry_button.visible,"collection pauses and presents true counts")
		check(view.encloses(game.hud.resume_button.get_global_rect()),"collection back fits %s"%size_value)
		game.set_paused(false);game.set_paused(true);game.hud._request_home();check(game.hud.confirmation,"live exit asks confirmation")
		check(game.hud.cancel_confirmation() and not game.hud.confirmation,"confirmation cancel")
		game.leave_game();game.queue_free();await process_frame;await create_timer(.6).timeout
	print("FRUIT UI: %d checks; %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
