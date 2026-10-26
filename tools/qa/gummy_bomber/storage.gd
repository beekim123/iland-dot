extends SceneTree
const Game = preload("res://modules/gummy_bomber/main.tscn")
const Sim = preload("res://modules/gummy_bomber/sim.gd")
class MemorySave extends RefCounted:
 var writes: Array = []
 var reads: Array = []
 var data := {"highscore":777}
 func load_game(id: String) -> Dictionary:
  reads.append(id); return data.duplicate()
 func save_game(id: String, value: Dictionary) -> void:
  writes.append(id); data = value.duplicate()
var failed := false
func check(ok: bool, label: String) -> void:
 if not ok: failed = true; printerr("FAIL ", label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var storage := MemorySave.new()
 var game = Game.instantiate(); root.add_child(game); game.start({"seed":4,"save_service":storage})
 await process_frame
 check(game.highscore == 777 and storage.reads == ["gummy_bomber"], "injected highscore loaded")
 game.sim.score = 999; game.leave_game()
 check(storage.data.highscore == 999 and storage.writes == ["gummy_bomber"], "injected highscore saved in module namespace")
 game.queue_free(); await process_frame
 game = Game.instantiate(); root.add_child(game); game.start({"seed":5,"save_service":storage})
 await process_frame
 check(game.highscore == 999, "injected highscore persists between instances")
 game.leave_game(); game.queue_free(); await process_frame
 var sim = Sim.new(); sim.start(1); sim.events.append({"type":"hit"}); sim.start(2)
 check(sim.events.size() == 1 and sim.events[0].type == "wave", "restart clears stale event queue")
 await create_timer(0.5).timeout
 print("STORAGE AND RESET QA ", "FAIL" if failed else "PASS")
 quit(1 if failed else 0)
