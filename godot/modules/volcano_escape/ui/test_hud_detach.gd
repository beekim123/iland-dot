extends SceneTree
const HUD = preload("res://modules/volcano_escape/ui/rescue_hud.gd")
class HostInputProbe extends Node:
	var leaked := 0
	func _unhandled_input(_event: InputEvent) -> void: leaked += 1
var exits := 0
var handled_in_callback := false
func key(code: Key) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.pressed=true
	root.push_input(event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var probe := HostInputProbe.new(); root.add_child(probe)
	for viewport in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(960,540),Vector2i(640,360)]:
		root.content_scale_size=viewport; root.size=viewport
		for pointer in [false,true]:
			for result_screen in [false,true]:
				var game := Node.new(); root.add_child(game)
				var hud := HUD.new(); game.add_child(hud)
				hud.home_requested.connect(func():
					handled_in_callback=root.is_input_handled()
					root.remove_child(game)
					exits+=1)
				hud.update_snapshot({"status":"rescued" if result_screen else "running","time":20,"health":3})
				await process_frame
				if result_screen: key(KEY_DOWN)
				else:
					key(KEY_ESCAPE); await process_frame
					key(KEY_DOWN); key(KEY_DOWN); key(KEY_ENTER); await process_frame
					key(KEY_DOWN)
				await process_frame
				probe.leaked=0; handled_in_callback=false
				if pointer:
					var event := InputEventMouseButton.new()
					event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
					event.position=hud._buttons[1].get_center()*hud._scale
					root.push_input(event)
				else: key(KEY_ENTER)
				assert(not game.is_inside_tree())
				assert(hud.get_viewport()==null)
				assert(handled_in_callback, "Exit intent must already be handled before host detaches game")
				assert(probe.leaked==0,"Exit confirmation leaked to host _unhandled_input")
				game.free(); await process_frame
	assert(exits==16)
	probe.queue_free(); await process_frame
	print("PASS HUD synchronous detach: 16 keyboard/mouse pause-confirm/result exits across four viewports; consumed before callback; no host unhandled input")
	quit()
