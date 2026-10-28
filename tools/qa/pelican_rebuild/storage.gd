extends SceneTree
const Store=preload("res://modules/pelican_pedal/storage.gd")
const Sim=preload("res://modules/pelican_pedal/sim.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func put(path:String,text:String)->void:
 DirAccess.make_dir_recursive_absolute(path.get_base_dir());var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(text);f.close()
func fresh_data()->Dictionary:
 var d=Store.new().fresh();var s=Sim.new();s.start();d.snapshot=s.snapshot();return d
func _initialize()->void:
 var sentinel="user://games/fruit_gummy_snake/profile.json";put(sentinel,"foreign-module-sentinel")
 for context in [{"save_root":"user://hub/"},{"save_root":"user://games/fruit_gummy_snake/"}]:
  var s=Store.new();var p=s.load_profile(context);p.snapshot=Sim.new().snapshot()
  check(not s.allowed and not s.save(p),"foreign path context no save")
  check(not FileAccess.file_exists(Store.SAVE_PATH),"foreign context no disk write")
 var s=Store.new();s.load_profile({"save_root":"user://games/pelican_pedal/"});var p=fresh_data()
 check(s.save(p),"first valid save")
 var first=FileAccess.get_file_as_string(Store.SAVE_PATH)
 p.comfort=false;check(s.save(p),"second valid save")
 check(FileAccess.get_file_as_string(Store.SAVE_PATH+".bak")==first,"backup retains previous exact bytes")
 check(not FileAccess.file_exists(Store.SAVE_PATH+".tmp") and not DirAccess.dir_exists_absolute(Store.SAVE_PATH+".lock"),"atomic completion removes own temp and lock")
 for corrupt in ['{oops','null','[]','{}','{"schema":9,"future":"keep"}','{"schema":1,"game_id":"fruit_gummy_snake"}']:
  put(Store.SAVE_PATH,corrupt);s.load_profile();check(not s.allowed,"bad existing profile blocks save")
  check(not s.save(fresh_data()),"bad profile not overwritten")
  check(FileAccess.get_file_as_string(Store.SAVE_PATH)==corrupt,"bad profile exact preservation")
 DirAccess.remove_absolute(Store.SAVE_PATH);s.load_profile();put(Store.SAVE_PATH,"external-new")
 check(not s.save(fresh_data()),"concurrent new profile protected")
 check(FileAccess.get_file_as_string(Store.SAVE_PATH)=="external-new","concurrent new bytes kept")
 DirAccess.remove_absolute(Store.SAVE_PATH);s.load_profile();check(s.save(fresh_data()),"fresh after reload")
 s.load_profile();DirAccess.remove_absolute(Store.SAVE_PATH)
 check(not s.save(fresh_data()) and not FileAccess.file_exists(Store.SAVE_PATH),"concurrent deletion protected")
 s.load_profile();DirAccess.make_dir_absolute(Store.SAVE_PATH+".lock")
 check(not s.save(fresh_data()),"foreign lock blocks write")
 check(DirAccess.dir_exists_absolute(Store.SAVE_PATH+".lock"),"foreign lock not removed")
 DirAccess.remove_absolute(Store.SAVE_PATH+".lock")
 check(s.save(fresh_data()),"can retry after external lock released")
 check(FileAccess.get_file_as_string(sentinel)=="foreign-module-sentinel","other module unchanged")
 print("PELICAN INDEPENDENT STORAGE ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
