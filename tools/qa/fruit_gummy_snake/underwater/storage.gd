extends SceneTree
const Store=preload("res://modules/fruit_gummy_snake/store.gd")
var checks:=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func write_text(path:String,text:String)->void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()
func remove_profile()->void:
 if FileAccess.file_exists(Store.SAVE_PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.SAVE_PATH))
func _initialize()->void:
 var s=Store.new();var profile:=Store.fresh()
 ck(Store.fresh().schema_version==2 and Store.fresh().longest==8,"underwater schema 2 starts with eight segments")
 ck(Store.SAVE_PATH=="user://games/fruit_gummy_snake/underwater_v2/profile.json","explicit new underwater namespace")
 var sentinels:={}
 for id in ["gummy_bomber","bloom_skirmish","tide_gulp","pelican_pedal","beach_cleanup","volcano_escape","fruit_gummy_snake"]:
  var path:String="user://games/"+str(id)+"/profile.json";write_text(path,"SENTINEL_"+id);sentinels[path]=FileAccess.get_file_as_bytes(path)
 for invalid in ["{broken","null","[]",'{"schema_version":99,"future":"keep"}',JSON.stringify({"schema_version":true,"best_score":0,"longest":4,"rounds":0,"fruit_counts":[0,0,0,0,0]})]:
  write_text(Store.SAVE_PATH,invalid);s.load_profile();ck(not s.allowed and not s.write_profile(profile),"invalid/future remains readonly");ck(FileAccess.get_file_as_string(Store.SAVE_PATH)==invalid,"invalid/future exact bytes preserved")
 remove_profile();s.load_profile({"save_root":"user://games/fruit_gummy_snake/"});ck(s.allowed,"canonical root accepted")
 for value in [NAN,INF,-INF,1.5,-1,"9",true,null]:
  for field in ["best_score","longest","rounds","schema_version"]:
   var bad:=profile.duplicate(true);bad[field]=value;ck(not Store.valid(bad),"reject invalid numeric field "+field)
  var bad:=profile.duplicate(true);bad.fruit_counts[0]=value;ck(not Store.valid(bad),"reject invalid collection count")
 profile.best_score=999;profile.longest=13;profile.rounds=3;profile.fruit_counts=[1,3,0,7,9]
 ck(s.write_profile(profile),"fresh atomic write succeeds");s.load_profile();ck(s.profile==profile,"roundtrip normalized values")
 ck(not FileAccess.file_exists(Store.SAVE_PATH+".tmp"),"no dangling temp after success")
 # Independent writer starts from same baseline; one succeeds, loser never clobbers.
 var second=Store.new();second.load_profile();var first_value:=profile.duplicate(true);first_value.best_score=1000
 ck(s.write_profile(first_value),"first writer saves")
 ck(not second.write_profile(profile),"stale concurrent writer refused")
 ck(FileAccess.get_file_as_string(Store.SAVE_PATH)==JSON.stringify(first_value),"winner exact bytes retained")
 s.load_profile();remove_profile();ck(not s.write_profile(profile),"external deletion not resurrected")
 s.load_profile();write_text(Store.SAVE_PATH,"EXTERNAL_CREATE");ck(not s.write_profile(profile),"external creation not overwritten")
 ck(FileAccess.get_file_as_string(Store.SAVE_PATH)=="EXTERNAL_CREATE","new external bytes retained")
 remove_profile();s.load_profile();DirAccess.make_dir_absolute(ProjectSettings.globalize_path(Store.LOCK_PATH));ck(not s.write_profile(profile),"active writer lock blocks")
 ck(not FileAccess.file_exists(Store.SAVE_PATH),"lock rejection doesn't fabricate profile")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(Store.LOCK_PATH));ck(s.write_profile(profile),"lock release permits retry")
 var bytes:=FileAccess.get_file_as_bytes(Store.SAVE_PATH)
 for root_value in ["user://hub/","user://games/volcano_escape/","../outside",null]:
  s.load_profile({"save_root":root_value});ck(not s.allowed and not s.write_profile(profile),"foreign roots cannot redirect IO")
  ck(FileAccess.get_file_as_bytes(Store.SAVE_PATH)==bytes,"foreign root leaves own file unchanged")
 for path in sentinels:ck(FileAccess.get_file_as_bytes(path)==sentinels[path],"other module namespace untouched")
 print("INDEPENDENT UNDERWATER STORAGE: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
