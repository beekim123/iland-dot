extends SceneTree
var failures: Array[String]=[]
var checks:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL ",label)
func event(code: Key, pressed: bool) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=pressed;root.push_input(e)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game=load("res://modules/pelican_pedal/main.tscn").instantiate();root.add_child(game);game.start({});game.set_process(false);game.retry()
	event(KEY_W,true)
	for frame in 75:game._process(1.0/60)
	event(KEY_W,false);event(KEY_SPACE,true)
	for frame in 40:game._process(1.0/60)
	event(KEY_SPACE,false)
	check(game.sim.interactable(),"actual W and brake arrive at pickup")
	event(KEY_E,true);event(KEY_E,false);game._process(1.0/60)
	check(game.sim.phase=="delivery","same-frame E edge is retained")
	var visible_parcels:=0
	for parcel in game.cargo_items:
		if parcel.visible:visible_parcels+=1
	check(visible_parcels==game.sim.deliveries.size(),"picked-up packages visibly fill basket")
	event(KEY_ESCAPE,true);event(KEY_ESCAPE,false)
	check(game.paused and game.hud.menu_kind=="pause","real Escape pauses")
	var before: Dictionary=game.sim.snapshot()
	event(KEY_W,true);game._process(.8);event(KEY_W,false)
	check(game.sim.snapshot()==before,"pause rejects held movement")
	game.set_paused(false);game._process(.1)
	check(game.sim.pos==Vector2(before.pos[0],before.pos[1]),"resume no stale throttle")
	var mouse:=InputEventMouseButton.new();mouse.button_index=MOUSE_BUTTON_RIGHT;mouse.pressed=true;root.push_input(mouse)
	check(game.look_held,"RMB held enables look")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.paused and not game.look_held and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"focus loss releases mouse")
	game.leave_game();game.queue_free();await process_frame;await create_timer(.3).timeout
	print("PELICAN REAL INPUT ",checks," checks; ","PASS" if failures.is_empty() else "FAIL");quit(0 if failures.is_empty() else 1)
