extends SceneTree
const Store=preload("../store.gd")
var count:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	count+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func write(value:String)->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Store.SAVE_DIR));var f:=FileAccess.open(Store.SAVE_PATH,FileAccess.WRITE);f.store_string(value);f.close()
func _initialize()->void:
	var store=Store.new()
	for content in ["broken","null","[]","{}",'{"schema_version":999,"important":"preserve"}', '{"schema_version":true,"best_score":0,"longest":4,"rounds":0,"fruit_counts":[0,0,0,0,0]}']:
		write(content);store.load_profile();check(not store.allowed and not store.write_profile(Store.fresh()),"invalid/future read-only");check(FileAccess.get_file_as_string(Store.SAVE_PATH)==content,"invalid original bytes retained")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.SAVE_PATH));store.load_profile({"save_root":"user://games/fruit_gummy_snake/"});check(store.allowed,"canonical host root accepted")
	var data:=Store.fresh();data.best_score=234;data.longest=29;data.fruit_counts=[1,2,3,4,5];check(store.write_profile(data),"atomic fresh write")
	store.load_profile();check(store.profile==data,"round trip exact")
	var before:=FileAccess.get_file_as_bytes(Store.SAVE_PATH);store.load_profile({"save_root":"user://games/volcano_escape/"});check(not store.allowed and not store.write_profile(data),"foreign context cannot redirect writes");check(FileAccess.get_file_as_bytes(Store.SAVE_PATH)==before,"foreign root leaves own bytes alone")
	store.load_profile();write('{"other_writer":true}');check(not store.write_profile(data),"concurrent writer protected");check(FileAccess.get_file_as_string(Store.SAVE_PATH)=='{"other_writer":true}',"concurrent bytes preserved")
	for bad in [-1,NAN,INF,1.2,true,"2"]:
		var p:=Store.fresh();p.best_score=bad;check(not Store.valid(p),"bad score rejected")
	var p:=Store.fresh();p.longest=193;check(not Store.valid(p),"length cannot exceed board")
	print("FRUIT STORAGE: %d checks; %d failures"%[count,failures.size()]);quit(0 if failures.is_empty() else 1)
