extends RefCounted
## Module-local versioned persistence. An incompatible or corrupt profile is never
## overwritten, even when the caller does not load it before attempting a save.
const GAME_ID := "dawn_sword"
const SCHEMA_VERSION := 1
const SAVE_DIR := "user://games/dawn_sword/v1"
const SAVE_PATH := SAVE_DIR + "/profile.json"
const TEMP_PATH := SAVE_DIR + "/profile.json.tmp"
const MAX_BYTES := 1048576
var last_error := ""

func load_profile() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(SAVE_PATH):
		return {"ok": true, "data": {}, "error": "", "exists": false}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return _failure("无法读取存档；原文件已保留。")
	if file.get_length() > MAX_BYTES:
		file.close()
		return _failure("存档大小异常；原文件已保留。")
	var contents := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(contents) != OK or not parser.data is Dictionary:
		return _failure("存档损坏；原文件已保留，未覆盖。")
	var data: Dictionary = parser.data
	var issue := _validate(data, true)
	if not issue.is_empty():
		return _failure(issue + " 原文件已保留。")
	return {"ok": true, "data": data.duplicate(true), "error": "", "exists": true}

func save_profile(data: Dictionary) -> bool:
	last_error = ""
	var outgoing := data.duplicate(true)
	var issue := _validate(outgoing, false)
	if not issue.is_empty():
		last_error = issue
		return false
	# Always inspect the existing slot before writing; a new service instance must
	# not bypass the preservation guarantee. No automatic migration or reset.
	var current := load_profile()
	if not current.ok:
		return false
	outgoing["game_id"] = GAME_ID
	outgoing["schema_version"] = SCHEMA_VERSION
	var text := JSON.stringify(outgoing, "\t", true)
	if text.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "存档过大，未写入。"
		return false
	var directory_error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if directory_error != OK:
		last_error = "无法创建本游戏存档目录。"
		return false
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		last_error = "无法创建临时存档；原存档未变。"
		return false
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "存档写入失败；原存档未变。"
		return false
	# Same-directory rename is atomic on the desktop target. Never delete the old
	# slot as a fallback if the filesystem rejects the replacement.
	var rename_error := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_error != OK:
		last_error = "无法替换存档；原存档已保留。"
		return false
	return true

func _failure(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "data": {}, "error": message, "exists": true}

func _validate(data: Dictionary, require_header: bool) -> String:
	if require_header and (not data.has("game_id") or not data.has("schema_version")):
		return "存档缺少版本信息。"
	if data.has("game_id") and data.game_id != GAME_ID:
		return "存档不属于晨曦之剑。"
	if data.has("schema_version") and (not _whole(data.schema_version) or int(data.schema_version) != SCHEMA_VERSION):
		return "不支持此存档版本。"
	if not _json_safe(data, 0):
		return "存档含有无效数据。"
	for key in ["chapter", "unlocked_chapter"]:
		if data.has(key) and not _integer_range(data[key], 0, 4):
			return "章节索引无效。"
	if data.has("segment") and not _integer_range(data.segment, 0, 3):
		return "段落索引无效。"
	for key in ["flags", "settings"]:
		if data.has(key) and not data[key] is Dictionary:
			return "存档字段 " + key + " 必须是字典。"
	var flags: Dictionary = data.get("flags", {})
	for key in ["dawn", "rescued", "completed", "seal_broken", "princess_safe", "dragon_defeated"]:
		if flags.has(key) and not flags[key] is bool:
			return "故事标记 " + key + " 无效。"
	if flags.has("memories"):
		if not flags.memories is Array:
			return "记忆收藏必须是列表。"
		var seen: Dictionary = {}
		for memory in flags.memories:
			if not _integer_range(memory, 0, 4) or seen.has(int(memory)):
				return "记忆收藏索引无效或重复。"
			seen[int(memory)] = true
	if flags.has("shortcuts"):
		if not flags.shortcuts is Array:
			return "捷径记录必须是列表。"
		for shortcut in flags.shortcuts:
			if not (shortcut is String or shortcut is StringName):
				return "捷径记录必须是字符串。"
	var settings: Dictionary = data.get("settings", {})
	for key in ["volume", "flash"]:
		if settings.has(key):
			var value: Variant = settings[key]
			if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0 or float(value) > 1:
				return "音量或闪光设置超出范围。"
	for key in ["fullscreen", "shake", "subtitles"]:
		if settings.has(key) and not settings[key] is bool:
			return "显示设置 " + key + " 无效。"
	if settings.has("difficulty") and settings.difficulty not in ["normal", "adventure", "story"]:
		return "设置中的难度无效。"
	if settings.has("keys"):
		if not settings.keys is Dictionary:
			return "键位映射必须是字典。"
		for action in settings.keys:
			if not (action is String or action is StringName) or not _valid_keycode(settings.keys[action]):
				return "键位映射无效。"
	if data.has("checkpoint"):
		if not data.checkpoint is Dictionary:
			return "篝火记录无效。"
		var checkpoint: Dictionary = data.checkpoint
		if not checkpoint.has("chapter") or not checkpoint.has("segment"):
			return "篝火记录缺少章节或段落。"
		if not _integer_range(checkpoint.chapter, 0, 4) or not _integer_range(checkpoint.segment, 0, 3):
			return "篝火位置无效。"
	if data.has("difficulty") and data.difficulty not in ["normal", "adventure", "story"]:
		return "难度设置无效。"
	for key in ["completed", "rescued"]:
		if data.has(key) and not data[key] is bool:
			return "故事状态无效。"
	return ""

func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

func _integer_range(value: Variant, minimum: int, maximum: int) -> bool:
	return _whole(value) and float(value) >= minimum and float(value) <= maximum

func _json_safe(value: Variant, depth: int) -> bool:
	if depth > 16:
		return false
	if value == null or value is bool or value is String or value is StringName or value is int:
		return true
	if value is float:
		return is_finite(value)
	if value is Array:
		for child in value:
			if not _json_safe(child, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName) or not _json_safe(value[key], depth + 1):
				return false
		return true
	return false

func _valid_keycode(value: Variant) -> bool:
	if not _whole(value):
		return false
	var code := int(value)
	# Printable Unicode and Godot's named physical special keys. Modifier masks
	# are excluded: the runtime stores event.physical_keycode, not key chords.
	if code >= 32 and code <= 0x10ffff and not (code >= 127 and code <= 159) and not (code >= 0xd800 and code <= 0xdfff):
		return true
	if code >= KEY_F1 and code <= KEY_F35:
		return true
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return true
	return code in [KEY_ESCAPE, KEY_TAB, KEY_BACKTAB, KEY_BACKSPACE, KEY_ENTER, KEY_KP_ENTER, KEY_INSERT, KEY_DELETE, KEY_PAUSE, KEY_PRINT, KEY_SYSREQ, KEY_CLEAR, KEY_HOME, KEY_END, KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_PAGEUP, KEY_PAGEDOWN, KEY_SHIFT, KEY_CTRL, KEY_META, KEY_ALT, KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK, KEY_MENU, KEY_HELP, KEY_KP_MULTIPLY, KEY_KP_DIVIDE, KEY_KP_SUBTRACT, KEY_KP_PERIOD, KEY_KP_ADD]
