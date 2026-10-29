extends SceneTree
const Store = preload("res://modules/woodland_duel/profile_store.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	if not OS.get_environment("XDG_DATA_HOME").contains("woodland-storage-test"):
		printerr("FAIL refusing fixture writes outside isolated woodland-storage-test XDG_DATA_HOME")
		quit(2); return
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1; printerr("FAIL independent storage: " + label)
func write_slot(contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(Store.SAVE_DIR)
	var file := FileAccess.open(Store.SAVE_PATH,FileAccess.WRITE)
	file.store_string(contents); file.close()
func run() -> void:
	DirAccess.make_dir_recursive_absolute(Store.SAVE_DIR)
	DirAccess.remove_absolute(Store.SAVE_PATH)
	var store = Store.new()
	var initial: Dictionary = store.load_profile()
	check(store.allowed and store.valid(initial),"missing profile gets writable valid defaults")
	var original := initial.duplicate(true)
	check(store.save(initial) and initial == original,"first save works without mutating caller")
	var baseline := FileAccess.get_file_as_string(Store.SAVE_PATH)
	var second = Store.new()
	var current: Dictionary = second.load_profile()
	current.wins = 3; current.losses = 2; current.draws = 1; current.matches = 6
	current.volume = 0.42; current.music_enabled = false; current.reduce_motion = true; current.selected_deck = "spores"
	check(second.save(current),"valid profile replacement saves")
	var reloaded = Store.new()
	var roundtrip: Dictionary = reloaded.load_profile()
	for field in current.keys():
		check(roundtrip[field] == current[field],"setting/count round trip: "+str(field))
	check(FileAccess.get_file_as_string(Store.SAVE_PATH+".bak") == baseline,"atomic save preserves preceding content in backup")
	baseline = FileAccess.get_file_as_string(Store.SAVE_PATH)
	check(not store.save(initial) and not store.allowed,"stale writer cannot clobber newer profile")
	check(FileAccess.get_file_as_string(Store.SAVE_PATH) == baseline,"stale write leaves exact bytes")
	for field in ["wins","losses","draws","matches"]:
		for invalid in [-1, 0.5, 1000000001, true, "1", NAN, INF]:
			var bad := current.duplicate(true); bad[field] = invalid
			check(not reloaded.valid(bad) and not reloaded.save(bad),"bad typed or bounded outcome count rejected: "+field)
			check(FileAccess.get_file_as_string(Store.SAVE_PATH) == baseline,"invalid counts cannot change slot")
	for patch in [{"schema":99},{"game_id":"another_game"},{"volume":-0.1},{"volume":1.1},{"volume":true},{"volume":NAN},{"volume":INF},{"music_enabled":1},{"reduce_motion":"false"},{"selected_deck":"missing"},{"matches":7}]:
		var bad := current.duplicate(true); bad.merge(patch,true)
		check(not reloaded.valid(bad) and not reloaded.save(bad),"invalid settings/schema/statistics rejected")
		check(FileAccess.get_file_as_string(Store.SAVE_PATH) == baseline,"invalid input preserves exact bytes")
	for field in current.keys():
		var missing := current.duplicate(true); missing.erase(field)
		check(not reloaded.valid(missing),"required field enforced: "+str(field))
	var future := current.duplicate(true); future.schema = 999
	var foreign := current.duplicate(true); foreign.game_id = "other_game"
	for corrupt in ["{truncated", "[]", "null", "{}", JSON.stringify(future), JSON.stringify(foreign)]:
		write_slot(corrupt)
		var protected_store = Store.new()
		var fallback: Dictionary = protected_store.load_profile()
		check(not protected_store.allowed and not protected_store.status.is_empty(),"bad/future/foreign data gives explicit read-only state")
		check(protected_store.valid(fallback),"invalid slot still permits fresh temporary gameplay profile")
		check(not protected_store.save(fallback),"bad/future/foreign data cannot be silently replaced")
		check(FileAccess.get_file_as_string(Store.SAVE_PATH) == corrupt,"bad/future/foreign bytes preserved exactly")
	write_slot(baseline)
	for context in [{"game_id":"other_game"},{"save_root":"user://games/other_game/"},{"schema_version":2}]:
		var wrong_context = Store.new()
		var fallback: Dictionary = wrong_context.load_profile(context)
		check(not wrong_context.allowed and not wrong_context.save(fallback),"foreign context cannot write this namespace")
		check(FileAccess.get_file_as_string(Store.SAVE_PATH) == baseline,"foreign context preserves current file")
	var lock_store = Store.new(); lock_store.load_profile()
	check(DirAccess.make_dir_absolute(Store.SAVE_PATH+".lock") == OK,"exclusive writer fixture lock created")
	check(not lock_store.save(current),"concurrent lock makes write fail without clobbering")
	check(FileAccess.get_file_as_string(Store.SAVE_PATH) == baseline,"locked slot unchanged")
	DirAccess.remove_absolute(Store.SAVE_PATH+".lock")
	check(lock_store.save(current),"writer safely recovers after transient lock removed")
	print("WOODLAND INDEPENDENT STORAGE: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
