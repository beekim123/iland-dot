extends RefCounted
## Pure bounded selection model plus a fixed, isolated shell profile.
## A refresh changes games, never the authored island door positions.
const LIMIT := 4
const SAVE_PATH := "user://hub/portal_rotation.json"
const SCHEMA := 1
var selected: Array[String] = []
var appearances: Dictionary = {}
var revision := 0
var write_allowed := true
var status := ""
var _disk_text := ""
var _disk_existed := false
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func reconcile(pool: Array) -> Array[String]:
	var ids := _ids(pool)
	var next: Array[String] = []
	var target := mini(LIMIT,ids.size())
	for slot in mini(selected.size(),target):
		var id := selected[slot]
		next.append(id if id in ids and id not in next else "")
	while next.size() < target: next.append("")
	for slot in next.size():
		if next[slot].is_empty(): next[slot] = _draw(ids,next)
	var changed := next != selected
	selected = next
	if changed: _record_selection()
	return selected.duplicate()

func shuffle(pool: Array) -> Array[String]:
	var ids := _ids(pool)
	if ids.is_empty():
		selected.clear(); return []
	var previous := selected.duplicate()
	var next: Array[String] = []
	# Force one genuine replacement when candidates exist; merely permuting
	# the same four doors does not count as changing the offered games.
	var outsiders: Array[String] = []
	for id in ids:
		if id not in previous: outsiders.append(id)
	if ids.size() > LIMIT and not outsiders.is_empty(): next.append(_draw(outsiders,[]))
	while next.size() < mini(LIMIT,ids.size()): next.append(_draw(ids,next))
	# Shuffle slot order without touching geometry, and use this RNG only.
	for i in range(next.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var swap := next[i]; next[i] = next[j]; next[j] = swap
	selected = next
	_record_selection()
	return selected.duplicate()

func _ids(pool: Array) -> Array[String]:
	var ids: Array[String] = []
	for item in pool:
		var id := str(item.get("id","")) if item is Dictionary else str(item)
		if item is Dictionary and not bool(item.get("enabled",false)): continue
		if not id.is_empty() and id not in ids: ids.append(id)
	return ids

func _draw(ids: Array, excluded: Array) -> String:
	var weights: Array[float] = []
	var candidates: Array[String] = []
	var total := 0.0
	for id in ids:
		if id in excluded: continue
		var weight := 1.0/(1.0+float(appearances.get(id,0)))
		total += weight; weights.append(weight); candidates.append(id)
	if candidates.is_empty(): return ""
	var value := rng.randf()*total
	for i in candidates.size():
		value -= weights[i]
		if value <= 0: return candidates[i]
	return candidates.back()

func _record_selection() -> void:
	for id in selected: appearances[id] = mini(1000000,int(appearances.get(id,0))+1)
	revision = mini(1000000,revision+1)

func snapshot() -> Dictionary:
	return {"schema_version":SCHEMA,"selected":selected.duplicate(),"appearances":appearances.duplicate(),"revision":revision}

func restore(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4 or not _integer(value.get("schema_version"),SCHEMA,SCHEMA): return false
	if not value.get("selected") is Array or not value.get("appearances") is Dictionary: return false
	if value.selected.size() > LIMIT or value.appearances.size() > 128 or not _integer(value.get("revision"),0,1000000): return false
	var next: Array[String] = []
	for id in value.selected:
		if not _valid_id(id) or id in next: return false
		next.append(id)
	for id in value.appearances:
		if not _valid_id(id) or not _integer(value.appearances[id],0,1000000): return false
	selected = next; appearances = value.appearances.duplicate(); revision = int(value.revision)
	return true

func _valid_id(id: Variant) -> bool:
	if not id is String or id.is_empty() or id.length() > 64: return false
	for character in id:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789_": return false
	return true

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and float(value)>=low and float(value)<=high

func load_profile() -> bool:
	write_allowed = true; status = ""; _disk_existed = FileAccess.file_exists(SAVE_PATH)
	if not _disk_existed: _disk_text = ""; return true
	var file := FileAccess.open(SAVE_PATH,FileAccess.READ)
	if file == null or file.get_length()>65536:
		write_allowed = false; status = "海岛记录暂不可读，本次不会覆盖原记录"; return false
	_disk_text = file.get_as_text(); file.close()
	var json := JSON.new()
	if json.parse(_disk_text) != OK or not restore(json.data):
		write_allowed = false; status = "海岛记录版本不兼容，本次不会覆盖原记录"; return false
	return true

func save_profile() -> bool:
	if not write_allowed: return false
	DirAccess.make_dir_recursive_absolute("user://hub")
	# Serialize competing shell instances without touching any game namespace.
	var lock_path := SAVE_PATH+".lock"
	if DirAccess.make_dir_absolute(lock_path) != OK:
		status = "海岛记录正被使用，本次组合暂未保存"; return false
	var result := _save_locked()
	DirAccess.remove_absolute(lock_path)
	return result

func _save_locked() -> bool:
	var exists := FileAccess.file_exists(SAVE_PATH)
	if exists != _disk_existed or (exists and FileAccess.get_file_as_string(SAVE_PATH) != _disk_text):
		write_allowed = false; status = "海岛记录已在别处更新，本次不会覆盖"; return false
	var text := JSON.stringify(snapshot())
	var tmp := SAVE_PATH+".tmp"
	if FileAccess.file_exists(tmp): status = "海岛记录有待处理文件，本次组合暂未保存"; return false
	var file := FileAccess.open(tmp,FileAccess.WRITE)
	if file == null: status = "海岛记录暂不能保存"; return false
	file.store_string(text); file.flush()
	var error := file.get_error(); file.close()
	if error != OK or FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp); status = "海岛记录写入失败"; return false
	if DirAccess.rename_absolute(tmp,SAVE_PATH) != OK:
		DirAccess.remove_absolute(tmp); status = "海岛记录替换失败"; return false
	_disk_existed = true; _disk_text = text; status = ""
	return true
