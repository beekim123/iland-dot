extends SceneTree
const Scene=preload("../main.tscn")
var checks:=0
var failures:Array[String]=[]
var exits:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func key(code:int,pressed:bool)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;root.push_input(event)
func _initialize()->void:call_deferred("run")
func run()->void:
	var baseline:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for cycle in 4:
		var g=Scene.instantiate();root.add_child(g);g.start({"seed":42,"save_root":"user://games/fruit_gummy_snake/"});g.set_process(false);g.exit_requested.connect(func():exits+=1)
		await process_frame
		check(g.running and g.has_started and g.sim.body.size()==8,"real main starts through ABI")
		check(g.camera.environment!=null and g.find_children("*","WorldEnvironment",true,false).is_empty(),"camera-local environment")
		key(KEY_UP,true);key(KEY_UP,false);key(KEY_LEFT,true);key(KEY_LEFT,false)
		check(g.sim.controls==Vector3.ZERO,"released steering never sticks")
		g.set_paused(true);var saved:Dictionary=g.sim.snapshot();g._process(2);check(g.sim.snapshot()==saved,"pause freezes authoritative clock")
		check(g.sim.controls==Vector3.ZERO,"pause clears pending direction")
		g.set_paused(false);g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);check(g.paused,"focus loss pauses")
		g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);check(g.paused,"focus return stays paused")
		g.set_paused(false);g._process(10);check(not g.sim.alive and g.accounted,"natural wall collision produces one result")
		var rounds:int=int(g.profile.rounds);g._process(3);check(int(g.profile.rounds)==rounds,"result cannot save twice")
		g.restart();g.set_process(false);check(g.sim.alive and not g.accounted and not g.paused and g.sim.score==0,"restart real new round")
		g.leave_game();g.leave_game();check(exits==cycle+1 and not g.running,"idempotent exit signal")
		check(not g.music.playing and not g.sfx.playing,"audio stopped before detach")
		g.queue_free();await process_frame;await process_frame
		await create_timer(.6).timeout
		check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline,"no orphan nodes after retirement")
	print("FRUIT RUNTIME: %d checks; %d failures"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
