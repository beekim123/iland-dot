extends SceneTree
const Game = preload("../game.gd")
var failures: Array[String] = []
class Store extends RefCounted:
	var value: Variant = null
	var reads := 0
	var writes := 0
	var id := ""
	func load_game(key: String) -> Variant: reads += 1; id = key; return value
	func save_game(key: String, data: Dictionary) -> void: writes += 1; id = key; value = data.duplicate(true)
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func disk(bytes: String) -> void:
	DirAccess.make_dir_recursive_absolute(Game.SAVE_DIR)
	var f := FileAccess.open(Game.SAVE_PATH,FileAccess.WRITE)
	f.store_string(bytes); f.close()
func run() -> void:
	var game = Game.new()
	var store := Store.new()
	game.save_service = store
	game.load_data()
	game.sim.start(0)
	game.run_id = "0123456789abcdef0123456789abcdef"
	game.sim.command({"move":Vector2(0,1)})
	game.sim.tick(1)
	check(game.save_data() and store.id=="volcano_escape","fixed service namespace")
	check(not store.value.has("snapshot") and store.value.results.is_empty(),"mid-disaster state never persisted")
	game.sim.command({"move":Vector2.ZERO})
	game.sim.tick(330)
	game._record_result(); game._record_result()
	check(game.profile.results.size()==1 and store.value.results.size()==1,"completed rescue idempotent")
	var valid: Dictionary = store.value.duplicate(true)
	for value in [[],{},null,{"schema_version":99,"game_id":"volcano_escape"}]:
		game.load_data(); game.apply_saved_data(value)
		var count: int = store.writes
		check(not game.save_data() and store.writes==count,"corrupt or unknown version preserved")
	store.value = valid.duplicate(true); game.load_data()
	store.value.settings.zoom = 22
	check(not game.save_data() and store.value.settings.zoom==22,"service concurrent modification retained")
	game.context_valid = false
	var reads: int = store.reads
	game.load_data()
	check(not game.save_data() and reads==store.reads,"invalid context does not read/write service")
	game.context_valid = true; game.save_service = null
	for bytes in ["{broken","null",'{"schema_version":99,"future":"keep exact"}']:
		disk(bytes); game.load_data()
		check(not game.save_data() and FileAccess.get_file_as_string(Game.SAVE_PATH)==bytes,"unknown/corrupt primary byte preservation")
	DirAccess.remove_absolute(Game.SAVE_PATH)
	game.load_data()
	check(game.save_data(),"atomic initial profile")
	var first := FileAccess.get_file_as_string(Game.SAVE_PATH)
	game.profile.settings.zoom = 20
	check(game.save_data() and FileAccess.get_file_as_string(Game.SAVE_PATH+".bak")==first,"atomic previous-good backup")
	check(not FileAccess.file_exists(Game.SAVE_PATH+".tmp"),"atomic temp retired")
	DirAccess.make_dir_absolute(Game.SAVE_PATH+".lock")
	check(not game.save_data(),"competing writer lock respected")
	DirAccess.remove_absolute(Game.SAVE_PATH+".lock")
	var changed := '{"external":"preserved"}'
	disk(changed)
	check(not game.save_data() and FileAccess.get_file_as_string(Game.SAVE_PATH)==changed,"optimistic concurrent disk writer preserved")
	game.free()
	print("VOLCANO STORAGE ","PASS" if failures.is_empty() else "FAIL", " completed-only, idempotence, atomicity, preservation, concurrent writers")
	quit(0 if failures.is_empty() else 1)
