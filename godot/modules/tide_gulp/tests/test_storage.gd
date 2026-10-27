extends SceneTree
## Run with isolated XDG_DATA_HOME; no arbitrary save paths are accepted by game.
var failures: Array[String] = []
class Store extends RefCounted:
	var value: Variant = null
	var writes := 0
	var loaded_id := ""
	var saved_id := ""
	func load_game(id: String) -> Variant:
		loaded_id = id
		return value
	func save_game(id: String, data: Dictionary) -> void:
		saved_id = id
		value = data.duplicate(true)
		writes += 1
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func run() -> void:
	var game = load("res://modules/tide_gulp/main.tscn").instantiate()
	root.add_child(game)
	var valid := Store.new()
	valid.value = {"schema_version":1,"best_score":271,"max_stage":4,"best_time":83.25}
	game.start({"seed":19,"save_service":valid,"save_root":"user://hub/"})
	game.set_process(false)
	check(game.best_score == 271 and game.max_stage == 4 and game.best_time == 83.25,"schema 1 records load exactly")
	game.save_data()
	check(valid.loaded_id == "tide_gulp" and valid.saved_id == "tide_gulp","injected store always uses fixed game namespace")
	check(valid.value.size() == 4 and valid.value.schema_version == 1,"profile stores only schema, score, stage and time")
	for payload in [{"schema_version":2,"future":"untouched"},{"schema_version":"1"},{"schema_version":1.5},{"schema_version":-1},[1,2],null,{},
		{"schema_version":1,"best_score":-1,"max_stage":1,"best_time":0},
		{"schema_version":1,"best_score":1.5,"max_stage":1,"best_time":0},
		{"schema_version":1,"best_score":0,"max_stage":7,"best_time":0},
		{"schema_version":1,"best_score":0,"max_stage":1,"best_time":-2},
		{"schema_version":1,"best_score":0,"max_stage":1,"best_time":"22"}]:
		var store := Store.new()
		store.value = payload
		game.start({"seed":20,"save_service":store})
		game.set_process(false)
		if payload == null: game.apply_saved_data(null)
		game.save_data()
		check(not game.save_write_allowed and store.writes == 0,"unknown or corrupt profile is never overwritten: %s" % str(payload))
	var fresh := Store.new()
	game.start({"seed":21,"save_service":fresh})
	game.set_process(false)
	check(game.best_score == 0 and game.max_stage == 1 and game.best_time == 0.0,"fresh profile cannot inherit previous player's record")
	game.sim.score = 44
	game.sim.player.stage = 3
	game.sim.elapsed = 32.5
	game.leave_game()
	check(fresh.value.best_score == 44 and fresh.value.max_stage == 3 and fresh.value.best_time == 32.5,"active return records actual run without a death")
	check(game.sim.stats.reason == "return" and game.sim.alive,"return isn't recorded as death")
	check(fresh.writes == 1,"a run is recorded once")
	game.save_service = null
	DirAccess.make_dir_recursive_absolute(game.SAVE_DIR)
	var file := FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
	file.store_string("{\"schema_version\":99,\"future\":\"retain byte for byte\"}")
	file.close()
	var preserved := FileAccess.get_file_as_string(game.SAVE_PATH)
	game.load_data()
	game.best_score = 999
	game.save_data()
	check(FileAccess.get_file_as_string(game.SAVE_PATH) == preserved,"future on-disk JSON remains byte-for-byte intact")
	file = FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
	file.store_string("{broken JSON")
	file.close()
	game.load_data()
	game.save_data()
	check(FileAccess.get_file_as_string(game.SAVE_PATH) == "{broken JSON","malformed on-disk JSON remains intact")
	DirAccess.remove_absolute(game.SAVE_PATH)
	game.load_data()
	game.best_score = 37
	check(game.save_data(),"atomic profile write succeeds")
	check(not FileAccess.file_exists(game.SAVE_PATH + ".tmp"),"atomic rename leaves no temporary profile")
	game.load_data()
	check(game.best_score == 37 and game.save_write_allowed,"new atomic profile round-trips")
	game.queue_free()
	await process_frame
	await create_timer(0.6).timeout
	print("TIDE STORAGE ","PASS" if failures.is_empty() else "FAIL"," fixed namespace; schema preservation; atomic writes; honest return records")
	quit(0 if failures.is_empty() else 1)
