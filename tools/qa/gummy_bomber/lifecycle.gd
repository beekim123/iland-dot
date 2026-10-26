extends SceneTree
const Game = preload("res://modules/gummy_bomber/main.tscn")
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
 if not ok: failures += 1; printerr("FAIL ", label)
func run() -> void:
 await process_frame
 var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 print("BASE ORPHANS ", baseline)
 for cycle in 20:
  var game = Game.instantiate()
  root.add_child(game)
  game.start({"seed":cycle})
  await process_frame
  game.sim.place_bomb()
  game._process(0.02)
  var received := [0]
  game.exit_requested.connect(func(): received[0] += 1)
  game.leave_game()
  expect(not game.running and not game.is_processing() and not game.is_processing_unhandled_input(), "exit stops processing %d" % cycle)
  expect(received[0] == 1, "exit once %d" % cycle)
  for voice in game.sounds.values(): expect(not voice.playing, "sound stopped")
  if game.music: expect(not game.music.playing, "music stopped")
  game.leave_game(); expect(received[0] == 1, "exit idempotent")
  game.queue_free()
  await process_frame
  await process_frame
  var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
  print("CYCLE ", cycle, " ORPHANS ", orphans, " OBJECTS ", Performance.get_monitor(Performance.OBJECT_COUNT))
  expect(orphans == baseline, "no orphan nodes %d" % cycle)
  root.size_changed.emit()
 await create_timer(0.5).timeout
 print("LIFECYCLE FAILURES ", failures)
 quit(0 if failures == 0 else 1)
