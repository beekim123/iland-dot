extends SceneTree
const D = preload("res://modules/dawn_sword/scripts/game.gd")
const Y = preload("res://modules/apprentice_yokai_king/main.gd")
var exits = 0
var failed = false
func check(ok: bool, message: String):
 print("PASS " if ok else "FAIL ",message)
 failed = failed or not ok
func _initialize(): call_deferred("run")
func run():
 for kind in ["dawn_sword","apprentice_yokai_king"]:
  var original_quit = auto_accept_quit
  var game = D.new() if kind == "dawn_sword" else Y.new()
  game.exit_requested.connect(func(): exits += 1)
  root.add_child(game)
  game.start({"game_id":kind,"save_root":"user://games/"+kind})
  var model = game.rules if kind == "dawn_sword" else game.model
  game.start({"game_id":kind,"save_root":"user://games/"+kind})
  check(model == (game.rules if kind == "dawn_sword" else game.model),kind+" start is idempotent")
  check(auto_accept_quit == original_quit,kind+" hosted start preserves global close policy")
  var event = InputEventKey.new()
  event.physical_keycode = KEY_D
  event.pressed = true
  game._input(event)
  var before = exits
  if kind == "dawn_sword": game.request_exit(); game.request_exit()
  else: game.exit_game(); game.exit_game()
  await create_timer(0.6).timeout
  check(exits == before+1,kind+" duplicate exit emits exactly once")
  check((game.held if kind == "dawn_sword" else game.held_keys).is_empty(),kind+" exit clears held input")
  game.queue_free()
  await process_frame
  check(auto_accept_quit == original_quit,kind+" removed module preserves close policy")
 quit(1 if failed else 0)
