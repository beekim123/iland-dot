extends SceneTree
const Game=preload("res://modules/monkey_vine/main.tscn")
var game
var checks=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok: failures.append(label);print("FAIL ",label)
func key(code:int,down:bool):
 var e=InputEventKey.new()
 e.keycode=code;e.physical_keycode=code;e.pressed=down
 root.push_input(e,true)
func tick(dt:float):
 game._process(dt)
func _initialize(): call_deferred("run")
func run():
 game=Game.instantiate()
 root.add_child(game)
 game.start({"save_root":"user://games/monkey_vine/"})
 game.set_process(false)
 await process_frame
 var initial=game.snapshot()
 game.start({})
 check(game.snapshot()==initial,"start idempotent")
 key(KEY_SPACE,true);key(KEY_SPACE,false)
 tick(1.0/60)
 var jumped=game.snapshot()
 check(jumped.player_pos.y>initial.player_pos.y,"same-frame short Space really jumps")
 check(not jumped.grounded,"short Space airborne")
 key(KEY_D,true)
 tick(.2)
 key(KEY_P,true)
 check(game.paused,"real viewport P pauses")
 var frozen=game.snapshot()
 tick(2.0)
 check(game.snapshot()==frozen,"paused time does not advance")
 key(KEY_D,true)
 key(KEY_P,true)
 check(not game.paused,"real viewport P resumes")
 var before=game.snapshot()
 tick(1.0/120)
 check(game.snapshot().player_vel.x<=before.player_vel.x+.0001,"paused inputs cleared")
 game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(game.paused,"focus loss pauses")
 game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
 check(game.paused,"focus return stays paused")
 game.request_retry()
 var t=float(game.snapshot().time)
 tick(2.0)
 for i in range(8): tick(0)
 check(absf(game.snapshot().time-t-2.0)<.00001,"large render dt backlog conserved")
 game.request_retry()
 game.request_pause(true)
 key(KEY_SPACE,true);key(KEY_SPACE,false)
 tick(1.0/60)
 check(not game.paused,"Space confirms focused Resume")
 check(game.snapshot().grounded,"Space menu confirmation does not jump")
 var signalled=[false]
 game.exit_requested.connect(func():
  signalled[0]=true
  root.remove_child(game)
  game.queue_free())
 game.request_pause(true)
 var exit_button: Button
 for button in game.hud.buttons.get_children():
  if button is Button and button.text in ["返回海岛","Return to island"]: exit_button=button
 check(exit_button!=null,"host exit button exists")
 if exit_button:
  exit_button.grab_focus()
  key(KEY_ENTER,true);key(KEY_ENTER,false)
 check(signalled[0],"host return signal synchronous detach")
 await process_frame
 await create_timer(.4).timeout
 check(not is_instance_valid(game),"runtime freed")
 print(JSON.stringify({"suite":"independent_real_viewport_runtime","checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
