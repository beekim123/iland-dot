extends SceneTree
const M = preload("res://modules/apprentice_yokai_king/run_model.gd")
const YS = preload("res://modules/apprentice_yokai_king/profile_store.gd")
const DS = preload("res://modules/dawn_sword/scripts/storage.gd")
var failures = 0
func check(ok: bool, message: String):
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures += 1
func write(path: String, bytes: String):
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var f = FileAccess.open(path,FileAccess.WRITE)
 f.store_string(bytes)
 f.close()
func _initialize():
 # Fixture: isolated future/corrupt files. Never user data; not a playthrough.
 var sentinel = "OTHER_MODULE_UNCHANGED"
 write("user://games/qa_sentinel/profile.json",sentinel)
 var y = YS.new()
 var future_y = JSON.stringify({"schema_version":99,"module_id":"apprentice_yokai_king"})
 write(YS.PATH,future_y)
 y.load_profile()
 check(y.blocked and not y.save_profile() and FileAccess.get_file_as_string(YS.PATH)==future_y,"Yokai future profile byte preservation")
 var d = DS.new()
 var future_d = JSON.stringify({"schema_version":99,"game_id":"dawn_sword"})
 write(DS.SAVE_PATH,future_d)
 check(not d.load_profile().ok and not d.save_profile({}) and FileAccess.get_file_as_string(DS.SAVE_PATH)==future_d,"Dawn future profile byte preservation")
 check(FileAccess.get_file_as_string("user://games/qa_sentinel/profile.json")==sentinel,"Sibling save namespace unchanged")
 # Actual simulation: movement only, no state mutation or forced kills.
 for hz in [30,60,120]:
  var m = M.new()
  m.reset(998,"standard",false)
  for frame in range(hz*130):
   var angle = float(frame)/hz*0.55
   var destination = Vector2(640,441)+Vector2(cos(angle)*400,sin(angle)*200)
   m.advance(1.0/hz,{"move":(destination-m.player).normalized()})
   if m.phase == "lost": break
  check(m.phase == "lost" and m.wave == 1 and m.build.chosen_count == 0,"No-attack movement cannot clear wave at "+str(hz)+"Hz; spawned="+str(m.spawned))
  check(m.spawned <= 12 and m.enemies.size() <= 12,"Wave1 finite budget at "+str(hz)+"Hz")
 quit(1 if failures else 0)
