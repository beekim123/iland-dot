extends SceneTree
const Rules = preload("res://modules/dawn_sword/scripts/rules.gd")
const Game = preload("res://modules/dawn_sword/scripts/game.gd")
const Storage = preload("res://modules/dawn_sword/scripts/storage.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	# Run only under isolated XDG paths: tests intentionally corrupt their slot.
	if not OS.get_environment("XDG_DATA_HOME").contains("dawn-storage-test"):
		printerr("Refusing destructive fixture test without isolated dawn-storage-test XDG_DATA_HOME")
		quit(2)
		return
	var store := Storage.new()
	DirAccess.make_dir_recursive_absolute(Storage.SAVE_DIR)
	DirAccess.remove_absolute(Storage.SAVE_PATH)
	_check(store.load_profile().ok and not store.load_profile().exists, "missing slot is a fresh profile")
	var data := {"checkpoint": {"chapter": 2, "segment": 3}, "flags": {"bridge": true}, "difficulty": "normal", "settings": {"volume": 0.5}, "completed": false}
	_check(store.save_profile(data), "first write")
	var loaded := store.load_profile()
	_check(loaded.ok and loaded.data.checkpoint.chapter == 2 and loaded.data.game_id == "dawn_sword", "round trip")
	_check(not data.has("schema_version"), "caller dictionary not mutated")
	data.checkpoint.chapter = 4
	_check(store.save_profile(data), "atomic replacement")
	_check(store.load_profile().data.checkpoint.chapter == 4, "replacement read")
	var runtime := Game.new()
	var actual_profile: Dictionary = Rules.new().profile()
	actual_profile.settings = runtime.settings.duplicate(true)
	_check(actual_profile.keys().any(func(key): return key is StringName), "fixture reproduces dot-assignment StringName key")
	_check(store.save_profile(actual_profile), "actual rules profile and runtime settings save")
	var actual_loaded := store.load_profile()
	_check(actual_loaded.ok and actual_loaded.data.settings.volume == runtime.settings.volume and actual_loaded.data.flags.memories == [], "actual runtime profile round trip")
	runtime.free()
	_check(store.save_profile({"flags": {&"label": &"bridge"}}), "JSON-compatible StringName keys and values accepted")
	_check(store.load_profile().data.flags.label == "bridge", "StringName serializes to plain JSON string")
	var baseline := FileAccess.get_file_as_bytes(Storage.SAVE_PATH)
	for invalid in [{"game_id": "other_game"}, {"schema_version": 99}, {"chapter": 5}, {"chapter": 1.5}, {"segment": -1}, {"checkpoint": {}}, {"flags": []}, {"settings": "oops"}, {"difficulty": "unknown"}, {"completed": 1}, {"settings": {"volume": NAN}}, {"flags": {"vector": Vector2.ZERO}}, {"flags": {42: "not a JSON object key"}}]:
		_check(not store.save_profile(invalid), "invalid input refused: " + str(invalid))
		_check(FileAccess.get_file_as_bytes(Storage.SAVE_PATH) == baseline, "invalid input preserves original")
	var malformed: Array = [
		{"flags":{"memories":"bad"}}, {"flags":{"memories":[0,0]}}, {"flags":{"memories":[0,0.0]}},
		{"flags":{"memories":[5]}}, {"flags":{"memories":[-1]}}, {"flags":{"memories":[1.5]}}, {"flags":{"memories":[true]}},
		{"flags":{"shortcuts":{}}}, {"flags":{"shortcuts":[1]}},
		{"settings":{"volume":-0.1}}, {"settings":{"volume":1.1}}, {"settings":{"volume":true}}, {"settings":{"flash":"0.5"}},
		{"settings":{"difficulty":"unknown"}}, {"settings":{"keys":[]}}, {"settings":{"keys":{"jump":0}}},
		{"settings":{"keys":{"jump":-1}}}, {"settings":{"keys":{"jump":65.5}}}, {"settings":{"keys":{"jump":999999999}}},
		{"settings":{"keys":{"jump":0xd800}}}, {"settings":{"keys":{"jump":true}}}
	]
	for flag in ["dawn", "rescued", "completed", "seal_broken", "princess_safe", "dragon_defeated"]:
		malformed.append({"flags":{flag:1}})
	for setting in ["fullscreen", "shake", "subtitles"]:
		malformed.append({"settings":{setting:1}})
	for invalid in malformed:
		_check(not store.save_profile(invalid), "invalid typed progression/settings rejected")
		_check(FileAccess.get_file_as_bytes(Storage.SAVE_PATH) == baseline, "invalid progression/settings preserves slot")
		var disk_fixture: Dictionary = invalid.duplicate(true)
		disk_fixture["game_id"] = Storage.GAME_ID
		disk_fixture["schema_version"] = Storage.SCHEMA_VERSION
		var bytes := JSON.stringify(disk_fixture)
		_write(bytes)
		_check(not store.load_profile().ok and not store.save_profile(data), "invalid on-disk typed settings blocks overwrite")
		_check(FileAccess.get_file_as_string(Storage.SAVE_PATH) == bytes, "incompatible on-disk profile preserved byte-for-byte")
		var original := FileAccess.open(Storage.SAVE_PATH, FileAccess.WRITE)
		original.store_buffer(baseline)
		original.close()
	_check(store.save_profile({"flags":{}, "settings":{}}), "empty legacy dictionaries remain valid")
	_check(store.save_profile({"flags":{"memories":[0,1,2,3,4],"shortcuts":["bridge"]},"settings":{"volume":0,"flash":1,"keys":{&"jump":KEY_SPACE,"pause":KEY_ESCAPE,"f":KEY_F12,"left":KEY_LEFT}}}), "valid full progression and physical keycodes accepted")
	for fixture in ["{broken", "[]", '{"game_id":"dawn_sword","schema_version":99}', '{"game_id":"other_game","schema_version":1}', '{"game_id":"dawn_sword","schema_version":0}', '{"game_id":"dawn_sword","schema_version":1,"chapter":999}', '{"chapter":0}']:
		_write(fixture)
		var fresh := Storage.new()
		_check(not fresh.load_profile().ok, "bad or foreign profile fails safely")
		_check(not fresh.save_profile(data) and not fresh.last_error.is_empty(), "fresh service refuses overwrite")
		_check(FileAccess.get_file_as_string(Storage.SAVE_PATH) == fixture, "bad or future bytes preserved")
	_write(JSON.stringify({"game_id": "dawn_sword", "schema_version": 1, "chapter": 0, "segment": 0}))
	_check(store.load_profile().ok, "valid numeric JSON fields accepted")
	print("Dawn Sword storage: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _write(text: String) -> void:
	var file := FileAccess.open(Storage.SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
