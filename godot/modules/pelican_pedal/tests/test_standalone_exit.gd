extends SceneTree
# Real main scene ownership, real Button GUI event; process must quit itself.
func _initialize()->void:call_deferred("run")
func run()->void:
 var game=load("res://modules/pelican_pedal/main.tscn").instantiate()
 root.add_child(game);current_scene=game
 await process_frame;await process_frame
 var result_mode:=OS.get_cmdline_user_args().has("result")
 if result_mode:
  game.sim.phase="complete";game._show_result()
 else:game.set_paused(true)
 await process_frame;await process_frame
 var button:Button
 for child in game.hud.actions.get_children():
  if child is Button and child.text=="关闭游戏":button=child
 if button==null:printerr("FAIL missing home button");quit(1);return
 button.grab_focus()
 for pressed in [true,false]:
  var event:=InputEventKey.new();event.keycode=KEY_ENTER;event.physical_keycode=KEY_ENTER;event.pressed=pressed
  root.push_input(event,true)
 await process_frame
 if not game.quit_pending or game.running or game.music.playing:
  printerr("FAIL standalone home did not schedule clean shutdown");quit(1);return
 print("STANDALONE HOME ","result" if result_mode else "pause", " saved/stopped; waiting for actual self-shutdown")
 await create_timer(3).timeout
 printerr("FAIL standalone left frozen process");quit(1)
