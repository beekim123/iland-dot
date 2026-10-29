extends RefCounted
## Per-module settings and outcome statistics. No match, deck ownership or economy data.
const SAVE_DIR := "user://games/woodland_duel"
const SAVE_PATH := SAVE_DIR + "/profile.json"
var allowed := true
var status := ""
var original_exists := false
var original_text := ""
var profile: Dictionary = {}

func fresh() -> Dictionary:
	return {"schema":1,"game_id":"woodland_duel","volume":0.65,"music_enabled":true,"reduce_motion":false,"wins":0,"losses":0,"draws":0,"matches":0,"selected_deck":"forest"}

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("game_id") != "woodland_duel" or not _integer(data.get("schema"), 1, 1): return false
	if typeof(data.get("volume")) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(data.volume)) or float(data.volume) < 0 or float(data.volume) > 1: return false
	if not data.get("music_enabled") is bool or not data.get("reduce_motion") is bool: return false
	if data.get("selected_deck") not in ["forest", "toys", "spores"]: return false
	for key in ["wins", "losses", "draws", "matches"]:
		if not _integer(data.get(key), 0, 1000000000): return false
	return int(data.matches) == int(data.wins) + int(data.losses) + int(data.draws)

func _integer(value: Variant, low: int, high: int) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) >= low and float(value) <= high and floor(float(value)) == float(value)

func load_profile(context: Dictionary = {}) -> Dictionary:
	allowed = true; status = ""; original_exists = false; original_text = ""; profile = fresh()
	if context.get("game_id", "woodland_duel") != "woodland_duel" or context.get("save_root", SAVE_DIR + "/") != SAVE_DIR + "/" or not _integer(context.get("schema_version", 1), 1, 1):
		allowed = false; status = "存档位置或版本不匹配，本次临时游玩，不覆盖原记录"; return profile
	original_exists = FileAccess.file_exists(SAVE_PATH)
	if not original_exists: return profile
	original_text = FileAccess.get_file_as_string(SAVE_PATH)
	var parser := JSON.new()
	if parser.parse(original_text) != OK or not valid(parser.data):
		allowed = false; status = "原存档损坏或版本较新，已保留；本次设置与战绩不保存"; return profile
	profile = parser.data.duplicate(true)
	return profile

func save(data: Dictionary) -> bool:
	if not allowed or not valid(data): return false
	if DirAccess.make_dir_recursive_absolute(SAVE_DIR) != OK: return _failed()
	if DirAccess.make_dir_absolute(SAVE_PATH + ".lock") != OK:
		status = "存档正在使用，请稍后重试"; return false
	var result := _save_locked(data)
	DirAccess.remove_absolute(SAVE_PATH + ".lock")
	return result

func _save_locked(data: Dictionary) -> bool:
	if FileAccess.file_exists(SAVE_PATH) != original_exists or (original_exists and FileAccess.get_file_as_string(SAVE_PATH) != original_text):
		allowed = false; status = "存档已被其他窗口更新，已停止覆盖"; return false
	var serialized := JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null: return _failed()
	file.store_string(serialized); file.flush()
	var error := file.get_error(); file.close()
	if error != OK: return _failed()
	if original_exists:
		var backup := FileAccess.open(SAVE_PATH + ".bak.tmp", FileAccess.WRITE)
		if backup == null: return _failed()
		backup.store_string(original_text); backup.flush(); error = backup.get_error(); backup.close()
		if error != OK or DirAccess.rename_absolute(SAVE_PATH + ".bak.tmp", SAVE_PATH + ".bak") != OK: return _failed()
	if DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH) != OK: return _failed()
	original_exists = true; original_text = serialized; profile = data.duplicate(true); status = ""
	return true

func _failed() -> bool:
	status = "设置暂未保存，请检查磁盘后重试"
	return false
