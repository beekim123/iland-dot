extends SceneTree
## Independent disk-level preservation + namespace test; run only via isolated QA.
var checks := 0
var failures: Array[String] = []
class MemoryStore extends RefCounted:
	var reads: Array[String] = []
	var writes: Array[String] = []
	var value: Variant = null
	func load_game(id: String) -> Variant:
		reads.append(id); return value
	func save_game(id: String, data: Dictionary) -> void:
		writes.append(id); value=data.duplicate(true)
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("FAIL: ",label)
func write(path: String, value: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value); file.close()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game=load("res://modules/tide_gulp/main.tscn").instantiate()
	root.add_child(game)
	var store := MemoryStore.new()
	game.start({"seed":13,"save_service":store,"save_root":"user://hub/","game_id":"gummy_bomber"})
	game.set_process(false)
	game.save_data()
	check(store.reads==["tide_gulp"] and store.writes==["tide_gulp"],"untrusted context cannot redirect injected storage ID")
	game.leave_game()
	game.save_service=null
	var protected := {}
	var created: Array[String] = []
	for path in ["user://games/gummy_bomber/profile.json","user://games/bloom_skirmish/profile.json","user://hub/profile.json"]:
		if not FileAccess.file_exists(path):
			write(path,"QA ISOLATION SENTINEL "+path); created.append(path)
		protected[path]=FileAccess.get_file_as_bytes(path)
	var save_path := "user://games/tide_gulp/profile.json"
	check(game.SAVE_PATH==save_path,"profile path is module-owned and fixed")
	for text in ["{broken", "null", "[]", "{}", '{"schema_version":99,"future":"do not downgrade"}',
		'{"schema_version":true,"best_score":0,"max_stage":1,"best_time":0}',
		'{"schema_version":1.5,"best_score":0,"max_stage":1,"best_time":0}',
		'{"schema_version":1,"best_score":-1,"max_stage":1,"best_time":0}',
		'{"schema_version":1,"best_score":2.5,"max_stage":1,"best_time":0}',
		'{"schema_version":1,"best_score":0,"max_stage":7,"best_time":0}',
		'{"schema_version":1,"best_score":0,"max_stage":1,"best_time":"2"}',
		'{"schema_version":1,"best_score":0,"max_stage":1,"best_time":1e309}']:
		write(save_path,text)
		game.load_data(); game.best_score=12345
		check(not game.save_write_allowed and not game.save_data(),"invalid schema/data never writes")
		check(FileAccess.get_file_as_string(save_path)==text,"invalid/future disk profile retained byte-for-byte")
	for value in [NAN,INF,-INF]:
		game.save_write_allowed=true
		game.apply_saved_data({"schema_version":1,"best_score":0,"max_stage":1,"best_time":value})
		check(not game.save_write_allowed,"nonfinite injected records rejected")
	DirAccess.remove_absolute(save_path)
	game.start({"seed":15,"save_root":"user://games/gummy_bomber/","game_id":"gummy_bomber"})
	game.set_process(false)
	game.best_score=431; game.max_stage=3; game.best_time=19.75
	check(game.save_data(),"fresh profile atomic write succeeds")
	check(not FileAccess.file_exists(save_path+".tmp"),"atomic rename leaves no pending temp file")
	game.load_data()
	check(game.best_score==431 and game.max_stage==3 and game.best_time==19.75,"complete disk profile round-trips")
	var decoded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(decoded.size()==4 and decoded.schema_version==1,"profile has no permanent upgrades or foreign settings")
	game.leave_game(); game.queue_free()
	await process_frame
	await create_timer(.6).timeout
	for path in protected:
		check(FileAccess.get_file_as_bytes(path)==protected[path],"other game/hub profile unchanged: "+path)
	for path in created: DirAccess.remove_absolute(path)
	print("TIDE INDEPENDENT STORAGE: %d checks; %s" % [checks,"PASS" if failures.is_empty() else JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
