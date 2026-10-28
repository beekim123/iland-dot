extends SceneTree
var checks:=0
var failures:Array[String]=[]
var home_events:=0
var background_events:=0
class Probe extends Node:
 var seen:=0
 func _unhandled_input(_event:InputEvent)->void:
  if _event.is_pressed():
   seen+=1
   print("HOST INPUT ",_event.as_text())
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func key(code:int,down:bool)->void:
 var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true)
func click(p:Vector2,down:bool)->void:
 var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=p;root.push_input(e,true)
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1280,800)
 var probe=Probe.new();root.add_child(probe)
 var base=Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
 for cycle in 6:
  var g=load("res://modules/pelican_pedal/main.tscn").instantiate();root.add_child(g)
  g.start({"save_root":"user://games/pelican_pedal/"});await process_frame;await process_frame
  check(g.running and not g.paused,"entry live")
  check(not g.get_tree().auto_accept_quit,"module intercepts normal WM-close for save")
  key(KEY_W,true);await create_timer(.2).timeout
  var time:float=g.sim.elapsed
  key(KEY_ESCAPE,true);key(KEY_ESCAPE,false)
  check(g.paused and g.keys.is_empty(),"real Esc pause clears movement")
  await create_timer(.15).timeout
  check(is_equal_approx(time,g.sim.elapsed),"paused clock frozen")
  g.set_paused(false);key(KEY_W,true);g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  check(g.paused and g.keys.is_empty() and not g.look_held,"focus loss releases keys/capture")
  g._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
  check(g.paused,"focus regain does not secretly resume")
  var before:float=g.sim.elapsed
  await process_frame
  var button:Button=g.hud.actions.get_child(3)
  var ref=weakref(g);g.exit_requested.connect(func():print("HOME SIGNAL");home_events+=1;root.remove_child(g);g.queue_free())
  probe.seen=0
  if cycle%2==0:
   button.grab_focus();await process_frame;key(KEY_ENTER,true);key(KEY_ENTER,false)
  else:
   var point=button.get_global_transform_with_canvas()*(button.size*.5)
   click(point,true);click(point,false)
  check(home_events==cycle+1,"actual pause Home emits once and synchronously detaches cycle%d"%cycle)
  check(probe.seen==0,"home confirmation does not leak to underlying host input cycle%d"%cycle)
  if g.is_inside_tree():g.leave_game()
  await process_frame;await process_frame;await create_timer(.4).timeout
  check(ref.get_ref()==null,"module and audio nodes freed after home")
  check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==base,"no orphan growth across home")
  check(root.get_tree().auto_accept_quit,"WM close policy restored after detach")
  var profile=JSON.parse_string(FileAccess.get_file_as_string("user://games/pelican_pedal/profile.json"))
  check(profile is Dictionary and float(profile.snapshot.elapsed)+.00001>=before,"exit saved latest progress")
 probe.queue_free();await process_frame
 print("PELICAN INDEPENDENT LIFECYCLE ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
