extends RefCounted
const SAVE_DIR := "user://games/fruit_gummy_snake/underwater_v2"
const SAVE_PATH := SAVE_DIR+"/profile.json"
const LOCK_PATH := SAVE_DIR+"/.write-lock"
var allowed := true
var warning := ""
var baseline := PackedByteArray()
var existed := false
var profile := fresh()

static func fresh() -> Dictionary:
	return {"schema_version":2,"best_score":0,"longest":8,"rounds":0,"fruit_counts":[0,0,0,0,0]}

static func integer(value:Variant, low:int, high:int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floorf(float(value))==float(value) and float(value)>=low and float(value)<=high

static func valid(value:Variant) -> bool:
	if not value is Dictionary or value.size()!=5:return false
	if not integer(value.get("schema_version"),2,2) or not integer(value.get("best_score"),0,1000000000000) or not integer(value.get("longest"),8,120) or not integer(value.get("rounds"),0,1000000000):return false
	var counts:Variant=value.get("fruit_counts")
	if not counts is Array or counts.size()!=5:return false
	for count in counts:
		if not integer(count,0,1000000000000):return false
	return true

func load_profile(context:Dictionary={}) -> void:
	profile=fresh();allowed=true;warning=""
	if context.has("save_root") and str(context.save_root) not in [SAVE_DIR+"/", "user://games/fruit_gummy_snake/"]:
		allowed=false;warning="存档位置不匹配，本次仅游玩，不写入。";return
	existed=FileAccess.file_exists(SAVE_PATH);baseline=PackedByteArray()
	if not existed:return
	baseline=FileAccess.get_file_as_bytes(SAVE_PATH)
	var parser:=JSON.new()
	var error:=parser.parse(baseline.get_string_from_utf8())
	var data:Variant=parser.data if error==OK else null
	if not valid(data):allowed=false;warning="原存档版本较新或损坏，已保留原文件。";return
	profile=fresh()
	for key in ["schema_version","best_score","longest","rounds"]:profile[key]=int(data[key])
	for i in 5:profile.fruit_counts[i]=int(data.fruit_counts[i])

func write_profile(value:Dictionary) -> bool:
	if not allowed or not valid(value):return false
	if FileAccess.file_exists(SAVE_PATH)!=existed or (existed and FileAccess.get_file_as_bytes(SAVE_PATH)!=baseline):
		allowed=false;warning="存档已被其他窗口更新，本窗口停止保存。";return false
	var global_dir:=ProjectSettings.globalize_path(SAVE_DIR)
	if DirAccess.make_dir_recursive_absolute(global_dir)!=OK:
		warning="无法创建存档目录，成绩暂未保存。";return false
	if DirAccess.make_dir_absolute(ProjectSettings.globalize_path(LOCK_PATH))!=OK:
		warning="其他窗口正在保存，请稍后再试。";return false
	# Recheck after owning the lock to prevent a concurrent lost update.
	if FileAccess.file_exists(SAVE_PATH)!=existed or (existed and FileAccess.get_file_as_bytes(SAVE_PATH)!=baseline):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_PATH));allowed=false;warning="存档已被其他窗口更新，本窗口停止保存。";return false
	var temporary:=SAVE_PATH+".tmp"
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_PATH));warning="写入失败，原存档未修改。";return false
	file.store_string(JSON.stringify(value));file.flush();file.close()
	var err:=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(SAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LOCK_PATH))
	if err!=OK:
		warning="存档替换失败，原存档未修改。";return false
	baseline=FileAccess.get_file_as_bytes(SAVE_PATH);existed=true;profile=value.duplicate(true);warning="";return true
