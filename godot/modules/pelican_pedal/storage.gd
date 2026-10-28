extends RefCounted
const Sim = preload("sim.gd")
const SAVE_DIR := "user://games/pelican_pedal"
const SAVE_PATH := SAVE_DIR+"/profile.json"
var allowed := true
var status := ""
var original_exists := false
var original_text := ""
var profile: Dictionary
func fresh() -> Dictionary: return {"schema":1,"game_id":"pelican_pedal","completed":0,"total_score":0,"comfort":true,"snapshot":{}}
func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("game_id")!="pelican_pedal" or not number(data.get("schema"),1,1): return false
	if not number(data.get("completed"),0,1000000) or not number(data.get("total_score"),0,1000000000) or not data.get("comfort") is bool or not data.get("snapshot") is Dictionary: return false
	if not data.snapshot.is_empty():
		var probe=Sim.new()
		if not probe.restore(data.snapshot): return false
	return true
func number(value: Variant, low: float, high: float) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=low and float(value)<=high and floor(float(value))==float(value)
func load_profile(context: Dictionary = {}) -> Dictionary:
	allowed=true;status="";profile=fresh();original_exists=false;original_text=""
	if context.has("save_root") and context.save_root!="user://games/pelican_pedal/":
		allowed=false;status="存档位置不匹配，本次临时游玩，不覆盖原记录";return profile
	original_exists=FileAccess.file_exists(SAVE_PATH)
	if not original_exists: return profile
	original_text=FileAccess.get_file_as_string(SAVE_PATH)
	var json:=JSON.new()
	if json.parse(original_text)!=OK or not valid(json.data):
		allowed=false;status="原存档版本或内容不兼容，已保留；本次临时游玩";return profile
	profile=json.data.duplicate(true);return profile
func save(data: Dictionary) -> bool:
	if not allowed or not valid(data): return false
	if DirAccess.make_dir_recursive_absolute(SAVE_DIR)!=OK:return failed()
	if DirAccess.make_dir_absolute(SAVE_PATH+".lock")!=OK:
		status="存档正在被使用，请稍后重试";return false
	var result:=_save_locked(data)
	DirAccess.remove_absolute(SAVE_PATH+".lock")
	return result
func _save_locked(data: Dictionary) -> bool:
	if FileAccess.file_exists(SAVE_PATH)!=original_exists or (original_exists and FileAccess.get_file_as_string(SAVE_PATH)!=original_text):
		allowed=false;status="存档在别处改变，已停止覆盖";return false
	if DirAccess.make_dir_recursive_absolute(SAVE_DIR)!=OK: return failed()
	var text:=JSON.stringify(data)
	var f:=FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if f==null:return failed()
	f.store_string(text);f.flush();var error:=f.get_error();f.close()
	if error!=OK:return failed()
	if original_exists:
		var backup:=FileAccess.open(SAVE_PATH+".bak.tmp",FileAccess.WRITE)
		if backup==null:return failed()
		backup.store_string(original_text);backup.flush();error=backup.get_error();backup.close()
		if error!=OK or DirAccess.rename_absolute(SAVE_PATH+".bak.tmp",SAVE_PATH+".bak")!=OK:return failed()
	if DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)!=OK:return failed()
	original_exists=true;original_text=text;profile=data.duplicate(true);status="";return true
func failed() -> bool:
	status="进度暂时无法保存，请稍后重试";return false
