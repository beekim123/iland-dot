extends SceneTree
## An actual extracted scene must self-start without the island host context.
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var scene = load("res://modules/bloom_skirmish/main.tscn").instantiate()
 root.add_child(scene)
 for frame in 120:
  await process_frame
 var ok: bool = scene.has_started and scene.running and scene.sim.actors.size() == 4
 print("BLOOM STANDALONE AUTO-START: ", "PASS" if ok else "FAIL")
 scene.leave_game()
 scene.queue_free()
 await process_frame
 await process_frame
 # Allow the native dummy-audio server to retire its final stream playbacks.
 await create_timer(0.5).timeout
 quit(0 if ok else 1)
