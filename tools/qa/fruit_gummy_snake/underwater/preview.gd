extends SceneTree
const Scene=preload("res://modules/fruit_gummy_snake/main.tscn")
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=Scene.instantiate();root.add_child(game);game.start({"seed":271});game.set_process(false)
 var rounds:int=game.profile.rounds
 if not game.preview:printerr("FAIL needs actual --snake-preview argument");quit(1);return
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 if not game.preview or not game.paused:printerr("FAIL focus lost preview flag");quit(1);return
 game.leave_game()
 if game.profile.rounds!=rounds:printerr("FAIL preview exit increments rounds");quit(1);return
 game.queue_free();await process_frame;await create_timer(.65).timeout
 print("INDEPENDENT UNDERWATER PREVIEW: actual CLI preview + focus loss + exit does not record round")
 quit()
