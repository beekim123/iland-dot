extends SceneTree
const Witness = preload("../data/witness.gd")
var failures: Array[String] = []
func host_context() -> Dictionary:
	return {"game_id":"beach_cleanup","save_root":"user://games/beach_cleanup/","schema_version":1,"quit_handler":Callable(self,"host_quit")}
func host_quit() -> void: pass
class Store extends RefCounted:
	var value: Variant = null
	var reads := 0
	var writes := 0
	var id := ""
	func load_game(key: String) -> Variant: reads += 1; id = key; return value
	func save_game(key: String, data: Dictionary) -> void: writes += 1; id = key; value = data.duplicate(true)
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message); push_error(message)
func write_disk(game, bytes: String) -> void:
	DirAccess.make_dir_recursive_absolute(game.SAVE_DIR)
	var file := FileAccess.open(game.SAVE_PATH,FileAccess.WRITE)
	file.store_string(bytes); file.close()
func run() -> void:
	var game = load("res://modules/beach_cleanup/main.tscn").instantiate()
	root.add_child(game)
	var store := Store.new()
	var context := host_context()
	context.save_service = store
	game.start(context); game.set_process(false)
	check(game.context_valid and game.save_write_allowed and store.reads == 1,"exact full host context permits fixed-namespace reads and writes")
	for i in range(6): check(Witness.collect_one(game.sim,game.sim.remaining[0]),"collect midrun cargo")
	check(game.save_data() and store.id == "beach_cleanup","fixed store namespace")
	var saved: Dictionary = game.sim.snapshot()
	game.leave_game()
	game.start(context); game.set_process(false)
	check(game.context_valid and game.save_write_allowed and game.sim.snapshot() == saved,"midrun reload preserves exact cargo/ground/delivered sets")
	check(Witness.unload(game.sim),"unload retained cargo")
	check(game.save_data(),"save unload")
	var delivered: Array = game.sim.delivered.duplicate()
	game.start({"save_service":store}); game.set_process(false)
	for id in delivered: check(not game.sim.remaining.has(id) and not game.sim.cargo.has(id),"unloaded trash never duplicates")
	check(Witness.complete(game.sim),"complete via commands")
	game._record_result(); game.save_data()
	game.start({"save_service":store}); game.set_process(false); game._record_result()
	check(game.profile.results.size() == 1 and game.sim.phase == "complete","completed resume never doubles result")
	var valid: Dictionary = store.value.duplicate(true)
	var invalid: Array = [null,[],{}, {"schema_version":99,"game_id":"beach_cleanup","future":true}]
	for field in ["schema_version","game_id","run_serial","snapshot","results"]:
		var bad: Dictionary = valid.duplicate(true); bad.erase(field); invalid.append(bad)
	var mismatched: Dictionary = valid.duplicate(true)
	mismatched.results["0"].distance += 1
	invalid.append(mismatched)
	var duplicated: Dictionary = valid.duplicate(true)
	duplicated.snapshot.cargo.append(duplicated.snapshot.delivered[0]); invalid.append(duplicated)
	for payload in invalid:
		var bad_store := Store.new(); bad_store.value = payload
		game.start({"save_service":bad_store}); game.set_process(false)
		if payload == null: game.apply_saved_data(null)
		check(not game.save_data() and bad_store.writes == 0,"invalid/future data preserved")
	for rejected_context in [{"game_id":"tide_gulp"},{"schema_version":99},{"save_root":"user://hub"},{"save_root":"user://games/beach_cleanup"},{"save_root":"user://games/beach_cleanup/../"},{"save_root":"user://games/tide_gulp/"},{"save_root":null},{"save_root":42}]:
		var isolated := Store.new(); rejected_context.save_service = isolated
		game.start(rejected_context); game.set_process(false)
		check(not game.save_data() and isolated.reads == 0 and isolated.writes == 0,"foreign context cannot touch any store")
	game.start(); game.set_process(false)
	for bytes in ["{broken", "null", '{"schema_version":99,"future":"preserve exact bytes"}']:
		write_disk(game,bytes); game.load_data()
		check(not game.save_data() and FileAccess.get_file_as_string(game.SAVE_PATH) == bytes,"corrupt/future primary never overwritten")
	DirAccess.remove_absolute(game.SAVE_PATH)
	game.load_data(); game.sim.start()
	check(game.save_data(),"atomic initial write")
	var first := FileAccess.get_file_as_string(game.SAVE_PATH)
	check(Witness.collect_one(game.sim,game.sim.remaining[0]),"pickup before backup write")
	check(game.save_data() and FileAccess.get_file_as_string(game.SAVE_PATH+".bak") == first,"atomic update retains exact previous good backup")
	check(not FileAccess.file_exists(game.SAVE_PATH+".tmp"),"no leftover atomic temp")
	# Real host contract, without an injected store: save on island return,
	# destroy the old game, then reload cargo from the fixed on-disk namespace.
	var disk_cargo: Dictionary = game.sim.snapshot()
	game.start(host_context()); game.set_process(false)
	check(game.context_valid and game.save_write_allowed and JSON.parse_string(JSON.stringify(game.sim.snapshot())) == JSON.parse_string(JSON.stringify(disk_cargo)),"full native host context reads canonical disk save")
	game.leave_game()
	game.queue_free()
	await process_frame
	game = load("res://modules/beach_cleanup/main.tscn").instantiate()
	root.add_child(game)
	game.start(host_context()); game.set_process(false)
	check(game.context_valid and game.save_write_allowed and JSON.parse_string(JSON.stringify(game.sim.snapshot())) == JSON.parse_string(JSON.stringify(disk_cargo)),"destroyed host return/reentry retains exact cargo and ground identities")
	check(game.save_data() and JSON.parse_string(FileAccess.get_file_as_string(game.SAVE_PATH)).snapshot == JSON.parse_string(JSON.stringify(disk_cargo)),"full host context writes only canonical profile after reentry")

	var changed := '{"schema_version":99,"external":"writer"}'
	write_disk(game,changed)
	check(not game.save_data() and FileAccess.get_file_as_string(game.SAVE_PATH) == changed,"external modification preserved")
	game.queue_free(); await process_frame; await create_timer(0.5).timeout
	print("BEACH STORAGE ","PASS" if failures.is_empty() else "FAIL"," isolated profile, midrun identity, result idempotence, backup, future/corrupt preservation")
	quit(0 if failures.is_empty() else 1)
