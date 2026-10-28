extends RefCounted

const PATH := "user://games/apprentice_yokai_king/profile.json"
const MODULE_ID := "apprentice_yokai_king"
const ENEMIES := ["grunt", "shield", "spring", "bubble", "sleeper", "elite", "boss", "dart", "lobber", "warder", "caller"]
const CORES := ["ayk_core_wind", "ayk_core_thunder", "ayk_core_quake"]
var data: Dictionary = {}
var blocked: bool = false
var warning: String = ""
var _recorded: Dictionary = {}

func _init() -> void:
 data = defaults()

static func defaults() -> Dictionary:
 var record := {"runs_finished": 0, "wins": 0, "best_wave": 0, "best_clear_ms": null}
 return {"schema_version": 1, "module_id": MODULE_ID,
 "records": {"standard": record.duplicate(), "assist": record.duplicate()},
 "discovery": {"enemy_ids": [], "cleared_core_ids": []},
 "settings": {"screen_shake": false, "reduced_flashes": true, "aim_assist": false, "charge_mode": "hold_primary", "sound": true}, "completed_run_ids": []}

func load_profile() -> Dictionary:
 data = defaults()
 blocked = false
 warning = ""
 _recorded.clear()
 if not FileAccess.file_exists(PATH):
  return data
 var parser := JSON.new()
 if parser.parse(FileAccess.get_file_as_string(PATH)) != OK or not parser.data is Dictionary:
  _block("存档损坏，原文件已保留。可继续游玩，但不会写入记录。")
  return data
 var candidate: Dictionary = parser.data
 if _whole(candidate.get("schema_version"), 2, 1000000):
  _block("存档来自更新版本，已原样保留；当前版本只读游玩。")
  return data
 if not _valid(candidate):
  _block("存档字段无效，原文件已保留；当前版本只读游玩。")
  return data
 data = candidate.duplicate(true)
 if not data.has("completed_run_ids"):
  data["completed_run_ids"] = []
 for id in data.completed_run_ids:
  _recorded[id] = true
 for field: String in ["enemy_ids", "cleared_core_ids"]:
  var unique: Array = []
  for id in data.discovery[field]:
   if not id in unique:
    unique.append(id)
   else:
    warning = "已移除重复的图鉴条目。"
  data.discovery[field] = unique
 for key: String in defaults().settings:
  if not data.settings.has(key):
   data.settings[key] = defaults().settings[key]
 return data

func _block(message: String) -> void:
 blocked = true
 warning = message

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
 if not (value is int or value is float):
  return false
 return is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func _valid(candidate: Dictionary) -> bool:
 if not _whole(candidate.get("schema_version"), 1, 1) or candidate.get("module_id") != MODULE_ID:
  return false
 if not candidate.get("records") is Dictionary or not candidate.get("discovery") is Dictionary or not candidate.get("settings") is Dictionary:
  return false
 for mode: String in ["standard", "assist"]:
  var records: Dictionary = candidate.records
  if not records.get(mode) is Dictionary:
   return false
  var r: Dictionary = records[mode]
  for field: String in ["runs_finished", "wins", "best_wave", "best_clear_ms"]:
   if not r.has(field):
    return false
  if not _whole(r.get("runs_finished"), 0, 2147483647) or not _whole(r.get("wins"), 0, int(r.get("runs_finished", 0))) or not _whole(r.get("best_wave"), 0, 6):
   return false
  if r.get("best_clear_ms") != null and (not _whole(r.best_clear_ms, 1, 2147483647) or r.wins < 1):
   return false
 for field: String in ["enemy_ids", "cleared_core_ids"]:
  if not candidate.discovery.get(field) is Array:
   return false
  var allowed: Array = ENEMIES if field == "enemy_ids" else CORES
  for id in candidate.discovery[field]:
   if not id is String or not id in allowed:
    return false
 var settings: Dictionary = candidate.settings
 for key: String in ["screen_shake", "reduced_flashes", "aim_assist", "sound"]:
  if settings.has(key) and not settings[key] is bool:
   return false
 if settings.get("charge_mode", "hold_primary") not in ["hold_primary", "right_charge"]:
  return false
 if settings.has("bindings"):
  if not settings.bindings is Dictionary:
   return false
  for action in settings.bindings:
   if action not in ["up", "down", "left", "right", "dodge", "pause"] or not _whole(settings.bindings[action], 1, 4194400):
    return false
 if candidate.has("completed_run_ids"):
  if not candidate.completed_run_ids is Array or candidate.completed_run_ids.size() > 128:
   return false
  for id in candidate.completed_run_ids:
   if not id is String or id.length() > 128 or id.is_empty():
    return false
 return true

func save_profile() -> bool:
 if blocked or not _valid(data):
  return false
 var directory := ProjectSettings.globalize_path(PATH.get_base_dir())
 if DirAccess.make_dir_recursive_absolute(directory) != OK:
  warning = "无法建立存档目录。"
  return false
 var temporary := PATH + ".tmp"
 var file := FileAccess.open(temporary, FileAccess.WRITE)
 if file == null:
  warning = "无法写入存档临时文件。"
  return false
 file.store_string(JSON.stringify(data, "\t"))
 file.flush()
 var write_error := file.get_error()
 file.close()
 if write_error != OK:
  warning = "存档临时文件写入失败，未覆盖原文件。"
  return false
 if FileAccess.file_exists(PATH):
  var previous := JSON.new()
  if previous.parse(FileAccess.get_file_as_string(PATH)) != OK or not previous.data is Dictionary or not _valid(previous.data):
   _block("写入前发现存档已变更或损坏，已保留原文件。")
   DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
   return false
  if DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".bak")) != OK:
   warning = "无法保留上一份有效备份，未覆盖原文件。"
   return false
 var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(PATH))
 if result != OK:
  warning = "存档原子替换失败，原文件未删除。"
 return result == OK

func record_result(mode: String, won: bool, wave: int, elapsed: float, selected_core: String, enemies: Array, run_id: String) -> bool:
 if blocked or mode not in ["standard", "assist"] or run_id.is_empty() or run_id.length() > 128 or _recorded.has(run_id):
  return false
 if wave < 1 or wave > 6 or not is_finite(elapsed) or elapsed <= 0.0 or (won and wave != 6) or (not selected_core.is_empty() and selected_core not in CORES):
  return false
 for enemy in enemies:
  if enemy not in ENEMIES:
   return false
 var previous := data.duplicate(true)
 var r: Dictionary = data.records[mode]
 r.runs_finished = int(r.runs_finished) + 1
 r.best_wave = maxi(int(r.best_wave), wave)
 if won:
  r.wins = int(r.wins) + 1
  var ms := maxi(1, int(elapsed * 1000.0))
  if r.best_clear_ms == null or ms < r.best_clear_ms:
   r.best_clear_ms = ms
  if not selected_core.is_empty() and not selected_core in data.discovery.cleared_core_ids:
   data.discovery.cleared_core_ids.append(selected_core)
 for enemy in enemies:
  if not enemy in data.discovery.enemy_ids:
   data.discovery.enemy_ids.append(enemy)
 data.completed_run_ids.append(run_id)
 while data.completed_run_ids.size() > 128:
  data.completed_run_ids.pop_front()
 if not save_profile():
  data = previous
  return false
 _recorded[run_id] = true
 return true

# Call only after an explicit, confirmed user action. Does not touch any other module.
# Corrupt and newer-version bytes are archived rather than interpreted or discarded.
var last_preserved_path: String = ""

func reset_profile(confirmed: bool = false) -> bool:
 if not confirmed:
  return false
 var previous_data := data.duplicate(true)
 var previous_recorded := _recorded.duplicate()
 var previous_blocked := blocked
 var previous_warning := warning
 last_preserved_path = ""
 if FileAccess.file_exists(PATH):
  var archive := PATH + ".%d-%d.preserved" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
  while FileAccess.file_exists(archive):
   archive += "_"
  if DirAccess.rename_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(archive)) != OK:
   warning = "无法保留原存档，未执行重置。"
   return false
  last_preserved_path = archive
 data = defaults()
 _recorded.clear()
 blocked = false
 warning = ""
 if save_profile():
  warning = "仅本游戏记录已重置；原存档已完整保留。" if not last_preserved_path.is_empty() else "仅本游戏记录已重置。"
  return true
 # Restore the exact original if creating the replacement failed.
 var write_warning := warning
 if not last_preserved_path.is_empty():
  var restored := DirAccess.rename_absolute(ProjectSettings.globalize_path(last_preserved_path), ProjectSettings.globalize_path(PATH))
  if restored != OK:
   blocked = true
   warning = "重置未完成，原字节仍保留于：" + last_preserved_path
   data = previous_data
   _recorded = previous_recorded
   return false
  last_preserved_path = ""
 data = previous_data
 _recorded = previous_recorded
 blocked = previous_blocked
 warning = previous_warning + " 重置未完成：" + write_warning
 return false
