extends SceneTree
const Scene=preload("res://modules/fruit_gummy_snake/main.tscn")
var checks:=0
var failures:Array[String]=[]
var exits:=0
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func key(code:int,down:bool,echo_value:bool=false)->void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;e.echo=echo_value;root.push_input(e)
func tap(code:int)->void:key(code,true);key(code,false)
func _initialize()->void:call_deferred("run")
func run()->void:
 var original_mouse:=Input.mouse_mode;var original_quit:=auto_accept_quit
 var baseline:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 for size_value in [Vector2i(1280,800),Vector2i(960,600),Vector2i(800,600),Vector2i(640,360)]:
  root.size=size_value;root.content_scale_size=size_value
  var game=Scene.instantiate();root.add_child(game);game.start({"seed":271});game.set_process(false)
  game.exit_requested.connect(func():exits+=1;root.remove_child(game);game.queue_free())
  await process_frame;await process_frame
  ck(game.countdown==3.0 and game.sim.elapsed==0,"new countdown isn't simulated gameplay")
  key(KEY_D,true);key(KEY_SPACE,true);key(KEY_W,true)
  ck(game.sim.controls==Vector3(1,1,1),"real held XYZ and throttle controls")
  key(KEY_D,false);key(KEY_SPACE,false);key(KEY_W,false)
  ck(game.sim.controls==Vector3.ZERO,"real releases clear all control axes")
  var clock:float=game.countdown;tap(KEY_ESCAPE);game._process(2.0)
  ck(game.paused and game.countdown==clock and game.sim.elapsed==0,"real Escape pauses countdown and time")
  tap(KEY_ESCAPE);game._process(2.5);ck(absf(game.countdown-.5)<.00001 and game.sim.elapsed==0,"countdown remainder retained")
  game._process(.8);ck(game.countdown==0 and absf(game.sim.elapsed-.3)<.00001,"crossing countdown uses only remaining dt")
  var before_s:Vector3=game.sim.head
  key(KEY_S,true);game._process(.5)
  ck(absf(float(game.hud.state.speed)-1.7)<.00001,"real S press shows actual slow speed")
  ck(absf(game.sim.head.distance_to(before_s)-.85)<.0001,"real S swims 1.7m/s")
  key(KEY_S,false);game._process(0)
  ck(absf(float(game.hud.state.speed)-3.9)<.00001,"real S release restores normal speed")
  var start:Vector3=game.sim.head
  key(KEY_D,true);key(KEY_SPACE,true);game._process(.8)
  ck(game.sim.head.y>start.y and game.sim.head.x>start.x and game.sim.head.z<start.z,"actual controls swim three axes")
  key(KEY_D,false);key(KEY_SPACE,false);key(KEY_C,true);game._process(1.5);key(KEY_C,false)
  ck(game.sim.forward.y<0,"actual C turns into descending swim")
  game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);ck(game.paused and game.pressed.is_empty(),"focus loss releases input")
  game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);ck(game.paused,"focus return needs deliberate resume")
  game.set_paused(false);game._process(30)
  ck(not game.sim.alive and game.accounted,"ordinary straight drive reaches wall result")
  var rounds:int=game.profile.rounds;game._process(10);ck(game.profile.rounds==rounds,"result recorded only once")
  # Real default GUI result button activation must restart without synthetic handlers.
  await process_frame;tap(KEY_ENTER);await process_frame
  ck(game.sim.alive and game.countdown==3 and not game.accounted,"real result Enter restarts")
  tap(KEY_ESCAPE);await process_frame
  game.store.warning="原存档版本较新或损坏，已保留原文件。";game._refresh_hud();await process_frame
  var banner:Control=game.hud.warning_banner
  var view:=Rect2(Vector2.ZERO,Vector2(size_value))
  ck(banner.visible and banner.z_index>game.hud.panel.z_index,"save warning drawn above modal")
  ck(view.encloses(banner.get_global_rect()),"save warning inside viewport "+str(size_value))
  ck(not banner.get_global_rect().intersects(game.hud.panel.get_global_rect()),"save warning doesn't obscure modal actions "+str(size_value))
  # Synchronous removal initiated by real mouse, including second confirmation click.
  var button:Control=game.hud.exit_button
  for i in 2:
   var p:Vector2=button.get_global_rect().get_center()
   var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.global_position=p;e.pressed=true;root.push_input(e)
   e=e.duplicate();e.pressed=false;root.push_input(e);await process_frame
  await create_timer(.65).timeout
  ck(not is_instance_valid(game),"real confirm click synchronously retires scene")
  ck(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline,"no scene/orphan growth after actual exit")
 ck(exits==4,"exactly one exit per scene")
 ck(Input.mouse_mode==original_mouse and auto_accept_quit==original_quit,"window/mouse ownership restored")
 print("INDEPENDENT UNDERWATER INPUT: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
