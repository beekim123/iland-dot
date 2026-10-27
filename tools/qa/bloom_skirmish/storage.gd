extends SceneTree
## Run with isolated XDG_DATA_HOME; intentionally writes only QA userdata fixtures.
const Game = preload("res://modules/bloom_skirmish/main.tscn")
const PROFILE := "user://games/bloom_skirmish/profile.json"
class Store extends RefCounted:
 var reads: Array[String] = []
 var writes: Array[String] = []
 var value: Variant = {}
 func load_game(id: String) -> Variant:
  reads.append(id)
  return value.duplicate(true) if value is Dictionary or value is Array else value
 func save_game(id: String, data: Dictionary) -> void:
  writes.append(id)
  value = data.duplicate(true)
var failures: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures.append(label)
  printerr("FAIL ", label)
func write_text(path: String, value: String) -> void:
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var f := FileAccess.open(path, FileAccess.WRITE)
 f.store_string(value)
 f.close()
func read_text(path: String) -> String:
 return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<absent>"
func snapshot_tree(path: String) -> Dictionary:
 var snapshot := {}
 if not DirAccess.dir_exists_absolute(path): return snapshot
 for filename in DirAccess.get_files_at(path):
  var file := path.path_join(filename)
  snapshot[file] = FileAccess.get_sha256(file)
 for directory in DirAccess.get_directories_at(path):
  snapshot.merge(snapshot_tree(path.path_join(directory)))
 return snapshot
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 if OS.get_environment("XDG_DATA_HOME").is_empty():
  printerr("Refusing storage fixtures without isolated XDG_DATA_HOME; use tools/test_all.sh")
  quit(2)
  return
 var hub := "user://hub/qa-sentinel.json"
 var gummy := "user://games/gummy_bomber/qa-sentinel.json"
 write_text(hub, "{\"sentinel\":\"hub-unchanged\"}")
 write_text(gummy, "{\"sentinel\":\"gummy-unchanged\"}")
 var hub_before := read_text(hub)
 var gummy_before := read_text(gummy)
 var foreign_before := snapshot_tree("user://hub")
 foreign_before.merge(snapshot_tree("user://games/gummy_bomber"))
 var store := Store.new()
 store.value = {"schema_version":1, "best_coverage":42.5, "wins":7, "matches":12, "audio_enabled":false}
 var game = Game.instantiate()
 root.add_child(game)
 game.start({"seed":4, "save_service":store, "save_root":"user://hub/"})
 await process_frame
 check(store.reads == ["bloom_skirmish"], "injected reads use own namespace")
 check(is_equal_approx(game.best_coverage,42.5) and game.wins == 7 and game.matches == 12, "injected profile is loaded")
 game.best_coverage = 55.0
 game.save_data()
 check(not store.writes.is_empty() and store.writes.all(func(id): return id == "bloom_skirmish"), "all injected writes use own namespace")
 check(store.value.get("schema_version") == 1 and is_equal_approx(float(store.value.get("best_coverage", 0)),55.0), "profile version and stats written")
 game.leave_game()
 game.queue_free()
 await process_frame
 game = Game.instantiate()
 root.add_child(game)
 game.start({"seed":5, "save_service":store})
 check(is_equal_approx(game.best_coverage,55.0), "profile persists between instances")
 check(game.matches == 12 and game.wins == 7, "mid-match exit does not fabricate a completed result")
 game.countdown_left = 0.0
 game.sim.bots_enabled = false
 game.sim._paint_disc(Vector2(6,2),2.4,0)
 game.step_simulation(180.0)
 check(game.sim.state == "finished" and game.matches == 13 and game.wins == 8 and store.value.matches == 13, "complete winning match persists exactly one result")
 game.step_simulation(1.0)
 game.restart()
 check(game.matches == 13 and game.wins == 8, "result reprocessing and replay do not duplicate saved wins")
 game.leave_game()
 game.queue_free()
 await process_frame
 for invalid in [{"schema_version":2, "unknown":"preserve", "best_coverage":99}, {"schema_version":99, "future_payload":{"x":[1,2,3]}}, {"schema_version":"1"}, {"schema_version":1.5}, {"schema_version":-1}, [1,2,3], "bad"]:
  var protected_store := Store.new()
  protected_store.value = invalid
  game = Game.instantiate()
  root.add_child(game)
  game.start({"seed":5, "save_service":protected_store})
  game.save_data()
  game.restart()
  game.leave_game()
  check(protected_store.writes.is_empty() and protected_store.value == invalid, "invalid/future injected data is never overwritten: " + str(invalid))
  game.queue_free()
  await process_frame
 for raw in ["{not-json]", "[1,2,3]", "{\"schema_version\":2,\"unknown\":{\"preserve\":true}}"]:
  write_text(PROFILE,raw)
  game = Game.instantiate()
  root.add_child(game)
  game.start({"seed":9, "save_root":"user://games/gummy_bomber/"})
  game.save_data()
  game.leave_game()
  check(read_text(PROFILE) == raw, "invalid/future local file byte-preserved")
  game.queue_free()
  await process_frame
 write_text(PROFILE,JSON.stringify({"schema_version":1,"best_coverage":12.0,"wins":1,"matches":2,"audio_enabled":true}))
 game = Game.instantiate()
 root.add_child(game)
 game.start({"seed":7,"game_id":"gummy_bomber","save_root":"user://hub/"})
 check(is_equal_approx(game.best_coverage,12.0), "hostile context cannot redirect local load")
 game.best_coverage = 65.0
 game.save_data()
 game.leave_game()
 game.queue_free()
 await process_frame
 var local: Variant = JSON.parse_string(read_text(PROFILE))
 check(local is Dictionary and is_equal_approx(float(local.get("best_coverage",0)),65.0), "local persistence remains module-owned")
 check(read_text(hub) == hub_before and read_text(gummy) == gummy_before, "hub and other module sentinel files unchanged")
 var foreign_after := snapshot_tree("user://hub")
 foreign_after.merge(snapshot_tree("user://games/gummy_bomber"))
 check(foreign_before == foreign_after, "all host/other-game filenames and byte hashes unchanged")
 check(not FileAccess.file_exists("user://save.json"), "no global save.json created")
 await create_timer(0.5).timeout
 print("BLOOM INDEPENDENT STORAGE: %d checks, %d failures" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
