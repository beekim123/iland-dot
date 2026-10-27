extends SceneTree
## Sends the real close notification through the scene tree; production code must quit.
## External runner also rejects ObjectDB/resource warnings and imposes a watchdog.
var mode := "standalone"
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--close-mode="): mode=arg.trim_prefix("--close-mode=")
 call_deferred("run")
func fail(message: String) -> void:
 printerr("FAIL WINDOW CLOSE ",mode,": ",message)
 quit(1)
func run() -> void:
 var top
 var game
 if mode=="standalone":
  top=load("res://modules/bloom_skirmish/main.tscn").instantiate(); root.add_child(top)
  top.start({"seed":611}); game=top
 else:
  top=load("res://app/main.tscn").instantiate(); root.add_child(top)
  await process_frame
  if mode!="host_hub":
   var id := "gummy_bomber" if mode=="host_gummy" else "bloom_skirmish"
   if not top.launch_game(id): fail("fixture failed to launch game"); return
   game=top.active_game
 if auto_accept_quit:
  fail("production close handler has not disabled immediate auto quit"); return
 if game and game.get_script().resource_path.contains("bloom_skirmish"):
  game.set_process(false); game._capture_mouse(); game.countdown_left=0
  game.sim.bots_enabled=false; game.sim.actors[0].pos=Vector2(5.5,2.5)
  game.sim._paint_disc(game.sim.actors[0].pos,.6,0); game.sim.deploy_pod(0)
  game.sim._fire(game.sim.actors[0],Vector2(10,2.5)); game._sync_visuals(.02)
  game.fx.impact({"world_pos":Vector3(5,.1,3),"normal":Vector3.UP,"team":0,"radius":1.4})
 var voices: Array = top.find_children("*","AudioStreamPlayer",true,false)
 for voice in voices: voice.play()
 if voices.size()<2: fail("fixture has too few active audio voices"); return
 await create_timer(.06).timeout
 var live := 0
 for voice in voices:
  if voice.playing: live+=1
 if live<2: fail("audio fixture did not start voices"); return
 print("BLOOM WINDOW CLOSE ",mode," START live_audio=",live,"; all-scene notification")
 root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 root.propagate_notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 await process_frame
 await process_frame
 if is_instance_valid(top): fail("root scene not released by close path"); return
 if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE: fail("mouse capture left behind by close"); return
 print("BLOOM WINDOW CLOSE ",mode," HANDLED; production retirement timer must exit now")
 # Do not call quit on success: the implementation must own the actual process exit.
 await create_timer(4.0).timeout
 fail("production close handler never terminated the process")
