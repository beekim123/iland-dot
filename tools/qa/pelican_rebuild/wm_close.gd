extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var g=load("res://modules/pelican_pedal/main.tscn").instantiate();root.add_child(g)
 g.start({"save_root":"user://games/pelican_pedal/"});await process_frame;await process_frame
 var e=InputEventKey.new();e.keycode=KEY_W;e.physical_keycode=KEY_W;e.pressed=true;root.push_input(e,true)
 await create_timer(.25).timeout
 var elapsed:float=g.sim.elapsed
 g._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 g._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 var saved=JSON.parse_string(FileAccess.get_file_as_string("user://games/pelican_pedal/profile.json"))
 if not (g.quit_pending and not g.running and not g.music.playing and not g.cue.playing and saved is Dictionary and float(saved.snapshot.elapsed)+.00001>=elapsed):
  printerr("FAIL WM close saves/stops/idempotent");quit(1);return
 print("PELICAN INDEPENDENT WM CLOSE saved/stopped; repeated notification accepted; awaiting engine shutdown")
 # The module must finish its scheduled shutdown, rather than the test quitting it.
 await create_timer(3).timeout
 printerr("FAIL module did not finish WM shutdown");quit(1)
