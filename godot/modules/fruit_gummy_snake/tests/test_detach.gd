extends SceneTree
const Scene=preload("../main.tscn")
var checks:=0
var failures:Array[String]=[]
var signal_seen:=false
class Probe extends Node:
	var keys:=0
	func _unhandled_input(event:InputEvent)->void:
		if event is InputEventKey and event.pressed:keys+=1
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func key(code:int,on:bool)->void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=on;root.push_input(e,true)
func _initialize()->void:call_deferred("run")
func run()->void:
	for mode in ["keyboard","mouse"]:
		var game=Scene.instantiate();root.add_child(game);game.start({"seed":2});game.set_process(false)
		game.set_paused(true);game.hud._request_home();await process_frame;await process_frame
		var probe:=Probe.new();root.add_child(probe)
		signal_seen=false
		game.exit_requested.connect(func():signal_seen=true;check(root.is_input_handled(),"input consumed before synchronous detach");root.remove_child(game))
		if mode=="keyboard":
			game.hud.exit_button.grab_focus();key(KEY_ENTER,true);key(KEY_ENTER,false)
		else:
			var p:Vector2=game.hud.exit_button.get_global_rect().get_center()
			var motion:=InputEventMouseMotion.new();motion.position=p;root.push_input(motion,true)
			for down in [true,false]:
				var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.pressed=down;root.push_input(e,true)
		check(signal_seen,"real button %s exits"%mode);check(probe.keys==0,"exit event not leaked to host")
		game.queue_free();probe.queue_free();await process_frame;await create_timer(.6).timeout
	print("FRUIT DETACH: %d checks; %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
