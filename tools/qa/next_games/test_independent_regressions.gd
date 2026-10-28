extends SceneTree
const YMain = preload("res://modules/apprentice_yokai_king/main.gd")
const DStore = preload("res://modules/dawn_sword/scripts/storage.gd")
var failures = 0
func check(ok: bool, message: String):
 print("PASS " if ok else "FAIL ", message)
 if not ok: failures += 1
func _initialize():
 call_deferred("run")
func run():
 # Fixture: malformed imported save, not a playthrough.
 var store = DStore.new()
 for bad in [{"flags":{"memories":1}}, {"settings":{"keys":1}}, {"settings":{"volume":[]}}, {"flags":{"completed":"false"}}]:
  var issue = store._validate(bad, false)
  check(not issue.is_empty(), "Dawn rejects unsafe save payload " + str(bad))
 # Real event flow after a public new-run call; no combat state injection.
 var game = YMain.new()
 root.add_child(game)
 game.start({"game_id":"apprentice_yokai_king"})
 game.set_process(false)
 game.new_run()
 # Draw list fixture corresponds to the actual HUD pause button; headless draw is not guaranteed.
 game.buttons = [{"id":"pause", "rect":Rect2(1055,41,166,49)}]
 var click = InputEventMouseButton.new()
 click.position = game.get_global_transform_with_canvas()*Vector2(1120,60)
 click.button_index = MOUSE_BUTTON_LEFT
 click.pressed = true
 game._input(click)
 game._input(click) # queued double-click before the next redraw
 game.resume_run()
 check(game.model.phase == "practice", "Yokai double-click pause then resume returns to practice (actual="+game.model.phase+")")
 game.new_run()
 game._process(1.0/120) # consume initial phase transition
 var press = InputEventMouseButton.new()
 press.position = game.get_global_transform_with_canvas()*Vector2(900,400)
 press.button_index = MOUSE_BUTTON_LEFT
 press.pressed = true
 game._input(press)
 game._process(1.0/240) # edge queued before next physics tick
 game.pause_run()
 press.pressed = false
 game._input(press) # physical release while paused
 game.resume_run()
 game._process(1.0/120)
 check(game.model.charge < 0, "Yokai released hold during pause does not resurrect queued charge (actual="+str(game.model.charge)+")")
 if game.audio: await game.audio.shutdown()
 game.queue_free()
 await process_frame
 quit(1 if failures else 0)
