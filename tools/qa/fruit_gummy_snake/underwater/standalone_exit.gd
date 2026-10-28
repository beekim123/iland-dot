extends SceneTree
const Scene=preload("res://modules/fruit_gummy_snake/main.tscn")
func _initialize()->void:call_deferred("run")
func key(code:int,down:bool)->void:
 var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e)
func run()->void:
 root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600)
 var game=Scene.instantiate();root.add_child(game);current_scene=game;game.start({"seed":271});game.set_process(false)
 if not game.standalone:printerr("FAIL standalone detection");quit(1);return
 await process_frame;await process_frame;key(KEY_ESCAPE,true);key(KEY_ESCAPE,false);await process_frame
 if not game.hud.exit_button.text.contains("关闭"):printerr("FAIL standalone close label");quit(1);return
 for i in 2:
  var p:Vector2=game.hud.exit_button.get_global_rect().get_center()
  for down in [true,false]:
   var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.global_position=p;e.pressed=down;root.push_input(e)
  await process_frame;await process_frame
 if game.running or game.music.playing or game.sfx.playing:printerr("FAIL standalone did not stop");quit(1);return
 print("INDEPENDENT UNDERWATER STANDALONE: real close stopped gameplay/audio; awaiting production quit")
 await create_timer(2).timeout
 printerr("FAIL standalone did not quit within 2 seconds");quit(1)
