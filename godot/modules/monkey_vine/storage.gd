extends RefCounted
## Save boundary for this module only. Never redirects to another game's path.
const ROOT := "user://games/monkey_vine/"
const PATH := ROOT + "profile.json"
const SCHEMA := 1
var writable := true
var warning := ""
var _observed := ""
var _existed := false

func load_profile(context: Dictionary = {}) -> Dictionary:
	writable = true
	warning = ""
	if context.has("save_root") and context["save_root"] != ROOT:
		_block("存档路径不匹配：本次游玩不会写入存档")
		return {}
	_existed = FileAccess.file_exists(PATH)
	if not _existed:
		_observed = ""
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		_block("无法读取存档；已保留原文件")
		return {}
	var raw := file.get_as_text()
	file.close()
	_observed = raw.sha256_text()
	var parser := JSON.new()
	if parser.parse(raw) != OK or not parser.data is Dictionary:
		_block("存档损坏；已保留原文件，本次不会覆盖")
		return {}
	var data: Dictionary = parser.data
	if not _integer(data.get("schema"), SCHEMA, SCHEMA) or not data.get("progress", {}) is Dictionary:
		_block("存档版本或内容不兼容；已保留原文件")
		return {}
	if data.has("volume") and (not _number(data.volume) or float(data.volume) < 0.0 or float(data.volume) > 1.0):
		_block("存档设置异常；已保留原文件")
		return {}
	return data

func save_profile(progress: Dictionary, volume: float = 0.65) -> bool:
	if not writable: return false
	var exists_now := FileAccess.file_exists(PATH)
	if exists_now != _existed or (exists_now and FileAccess.get_file_as_string(PATH).sha256_text() != _observed):
		_block("存档已由其他窗口修改；本窗口停止写入以保护记录")
		return false
	if DirAccess.make_dir_recursive_absolute(ROOT) != OK:
		_block("无法创建存档目录")
		return false
	var text := JSON.stringify({"schema":SCHEMA,"progress":progress,"volume":clampf(volume, 0.0, 1.0)})
	var tmp := PATH + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		_block("无法写入存档；进度仍保留在本次游玩中")
		return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(tmp, PATH) != OK:
		_block("保存失败；原存档未被主动删除")
		return false
	_existed = true
	_observed = text.sha256_text()
	return true

func invalidate(message: String) -> void:
	_block(message)

func _block(message: String) -> void:
	writable = false
	warning = message

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high
