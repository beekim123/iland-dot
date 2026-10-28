extends SceneTree
const Game=preload("res://modules/monkey_vine/main.tscn")
func _initialize():call_deferred("run")
func run():
 var g=Game.instantiate()
 root.add_child(g)
 current_scene=g
 await process_frame
 if not g.started:g.start({})
 await create_timer(.15).timeout
 if "wm_close" in OS.get_cmdline_user_args():
  g.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 else:g.request_exit()
 # Successful standalone must exit before this timeout; do not falsely quit for it.
 await create_timer(3).timeout
 print("FAIL standalone failed to quit itself")
 quit(1)
