extends SceneTree
## Run with a fresh isolated XDG_DATA_HOME; refuses to overwrite an existing profile.
const Store = preload("../profile_store.gd")
var failed := false
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: push_error(message); failed = true
func write_raw(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(Store.SAVE_DIR)
	var file := FileAccess.open(Store.SAVE_PATH,FileAccess.WRITE); file.store_string(text); file.close()
func cleanup() -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]: DirAccess.remove_absolute(Store.SAVE_PATH+suffix)
	DirAccess.remove_absolute(Store.SAVE_PATH+".lock")
func run() -> void:
	if FileAccess.file_exists(Store.SAVE_PATH):
		push_error("Storage test requires a fresh isolated XDG_DATA_HOME; existing profile was not touched."); quit(1); return
	var store := Store.new(); var data: Dictionary = store.load_profile()
	check(store.valid(data) and store.allowed, "Fresh profile validates")
	data.wins = 2; data.losses = 1; data.draws = 1; data.matches = 4; data.volume = 0.35
	check(store.save(data), "First atomic save succeeds")
	var first_bytes := FileAccess.get_file_as_string(Store.SAVE_PATH)
	var reload_store := Store.new(); var reloaded: Dictionary = reload_store.load_profile()
	check(int(reloaded.wins) == 2 and int(reloaded.losses) == 1 and int(reloaded.draws) == 1 and int(reloaded.matches) == 4 and is_equal_approx(float(reloaded.volume), 0.35), "Settings and statistics round trip")
	data.reduce_motion = true; check(store.save(data), "Second atomic save succeeds")
	check(FileAccess.get_file_as_string(Store.SAVE_PATH+".bak") == first_bytes, "Previous bytes retained as backup")
	var invalid: Dictionary = data.duplicate(true); invalid.matches = 0
	check(not store.save(invalid), "Inconsistent totals rejected")
	var bytes := FileAccess.get_file_as_string(Store.SAVE_PATH)
	for bad in ["{not-json", "{\"schema\":2,\"game_id\":\"woodland_duel\"}", "[]"]:
		write_raw(bad); var protected := Store.new(); protected.load_profile()
		check(not protected.allowed and not protected.save(protected.fresh()), "Bad/future profile is write protected")
		check(FileAccess.get_file_as_string(Store.SAVE_PATH) == bad, "Original bad/future bytes preserved")
	write_raw(bytes)
	var conflict := Store.new(); conflict.load_profile(); write_raw(bytes+" ")
	check(not conflict.save(data) and FileAccess.get_file_as_string(Store.SAVE_PATH) == bytes+" ", "External edits are not overwritten")
	var wrong := Store.new(); wrong.load_profile({"save_root":"user://games/other/"})
	check(not wrong.allowed, "Wrong namespace rejected")
	wrong.load_profile({"schema_version":true}); check(not wrong.allowed, "Boolean version rejected")
	for field in ["wins", "losses", "draws", "matches"]:
		invalid = store.fresh(); invalid[field] = -1
		check(not store.valid(invalid), "Negative count rejected")
	invalid = store.fresh(); invalid.volume = NAN; check(not store.valid(invalid), "NaN rejected")
	cleanup()
	print("woodland storage: PASS" if not failed else "woodland storage: FAIL")
	quit(1 if failed else 0)
