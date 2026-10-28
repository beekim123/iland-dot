extends SceneTree
const Store=preload("../storage.gd")
const Sim=preload("../sim.gd")
var checks:=0
var failed:=false
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failed=true;printerr("FAIL ",label)
func put(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(Store.SAVE_DIR)
	var f:=FileAccess.open(Store.SAVE_PATH,FileAccess.WRITE);f.store_string(text);f.close()
func _initialize() -> void:
	var s=Store.new();var sim=Sim.new();sim.start()
	for raw in ['{broken','null','[]','{"schema":99,"future":"preserve"}']:
		put(raw);var p=s.load_profile();p.snapshot=sim.snapshot();check(not s.save(p),"reject invalid existing");check(FileAccess.get_file_as_string(Store.SAVE_PATH)==raw,"retain bytes")
	DirAccess.remove_absolute(Store.SAVE_PATH)
	var p=s.load_profile();p.snapshot=sim.snapshot();check(s.save(p),"fresh atomic save");check(not FileAccess.file_exists(Store.SAVE_PATH+".tmp"),"temp renamed")
	DirAccess.make_dir_absolute(Store.SAVE_PATH+".lock");check(not s.save(p),"existing writer lock blocks");check(DirAccess.dir_exists_absolute(Store.SAVE_PATH+".lock"),"foreign lock preserved");DirAccess.remove_absolute(Store.SAVE_PATH+".lock")
	var copy=s.load_profile();check(copy==JSON.parse_string(JSON.stringify(p)),"roundtrip numeric JSON representation")
	put("foreign writer");check(not s.save(p),"external modification blocks");check(FileAccess.get_file_as_string(Store.SAVE_PATH)=="foreign writer","external bytes preserved")
	DirAccess.remove_absolute(Store.SAVE_PATH)
	p=s.load_profile({"save_root":"user://hub/"});p.snapshot=sim.snapshot();check(not s.save(p) and not FileAccess.file_exists(Store.SAVE_PATH),"foreign context zero IO")
	p=s.load_profile({"save_root":"user://games/pelican_pedal/"});p.snapshot=sim.snapshot();check(s.save(p),"canonical host context accepted")
	for field in ["schema","completed","total_score"]:
		for value in [true,NAN,INF,-1,1.5]:
			var bad=p.duplicate(true);bad[field]=value;check(not s.valid(bad),"reject malformed counter "+field)
	var bad=p.duplicate(true);bad.snapshot.checkpoint=[35,35];check(not s.valid(bad),"safe reset checkpoint must be road")
	print("PELICAN STORAGE ",checks," checks; ","FAIL" if failed else "PASS");quit(1 if failed else 0)
