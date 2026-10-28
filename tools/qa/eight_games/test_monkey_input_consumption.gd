extends SceneTree
const Game = preload("res://modules/monkey_vine/main.tscn")
class Probe extends Node:
	var leaked: Array = []
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey: leaked.append({"code":event.keycode,"pressed":event.pressed})
var failures: Array = []
func check(ok: bool, name: String) -> void:
	print(("PASS " if ok else "FAIL ")+name)
	if not ok: failures.append(name)
func key(code: int, down: bool, echo_value: bool=false) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;event.echo=echo_value
	root.push_input(event,true)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=Game.instantiate();root.add_child(game);game.start({});game.set_process(false)
	var probe:=Probe.new();root.add_child(probe)
	await process_frame
	key(KEY_ESCAPE,true);key(KEY_ESCAPE,false)
	check(game.paused and probe.leaked.is_empty(),"Escape down and up consumed before root unhandled observer")
	key(KEY_KP_ENTER,true);key(KEY_KP_ENTER,true,true);key(KEY_KP_ENTER,false)
	check(not game.paused and probe.leaked.is_empty(),"keypad Enter confirms once; hidden-modal release consumed")
	game._process(1.0/120)
	check(game.snapshot().grounded,"menu confirmation never becomes gameplay jump")
	key(KEY_ESCAPE,true);key(KEY_ESCAPE,false)
	var exit_button: Button
	for child in game.hud.buttons.get_children():
		if child is Button and child.text=="返回海岛": exit_button=child
	exit_button.grab_focus()
	var count: Array=[0]
	game.exit_requested.connect(func(): count[0]+=1;root.remove_child(game))
	key(KEY_ENTER,true)
	check(count[0]==1 and probe.leaked.is_empty(),"Enter down consumed before synchronous host detach")
	# Release after module removal belongs to the host's tail-event guard;
	# the independent eight-game host test verifies that full boundary.
	game.free();probe.queue_free();await process_frame;await create_timer(.4).timeout
	print("INPUT_CONSUMPTION_RESULT ",failures)
	quit(0 if failures.is_empty() else 1)
