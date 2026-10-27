extends SceneTree
var failures:Array[String]=[]
class Store extends RefCounted:
	var value:Variant={}
	var writes:=0
	var loaded_id:=""
	var saved_id:=""
	func load_game(id:String)->Variant: loaded_id=id; return value
	func save_game(id:String,data:Dictionary)->void: saved_id=id; value=data.duplicate(true); writes+=1
func _initialize()->void: call_deferred("run")
func check(ok:bool,message:String)->void:
	if not ok: failures.append(message); push_error(message)
func run()->void:
	var game=load("res://modules/bloom_skirmish/main.tscn").instantiate(); root.add_child(game)
	var legacy:=Store.new(); legacy.value={"best_coverage":61.7,"wins":3,"matches":5,"audio_enabled":false,"extension":"preserve"}
	game.start({"seed":42,"save_service":legacy,"save_root":"user://hub/"}); game.set_process(false); game.save_data()
	check(game.best_coverage==61.7 and not game.audio_enabled and legacy.value.schema_version==1,"legacy v1 migrates with settings")
	check(legacy.value.extension=="preserve" and legacy.loaded_id=="bloom_skirmish" and legacy.saved_id=="bloom_skirmish","namespace is fixed and unknown v1 fields preserved")
	for invalid in [{"schema_version":2,"future":"untouched"},{"schema_version":"1"},{"schema_version":1.5},{"schema_version":-1},[1,2],null,{"schema_version":1,"best_coverage":101},{"wins":2,"matches":1},{"audio_enabled":"yes"}]:
		var store:=Store.new(); store.value=invalid
		game.start({"save_service":store,"seed":2}); game.set_process(false)
		# A null injected result means no profile exists, unlike a corrupt on-disk JSON.
		if invalid==null:
			game.apply_saved_data(null)
		game.save_data()
		check(not game.save_write_allowed and store.writes==0,"future/malformed payload remains unwritten: %s"%str(invalid))
	var fresh:=Store.new(); game.start({"save_service":fresh,"seed":4}); game.set_process(false)
	check(game.best_coverage==0 and game.wins==0 and game.matches==0 and game.audio_enabled,"new store cannot inherit prior profile")
	game.save_data(); check(fresh.value.schema_version==1,"new profile writes current version")
	game.leave_game(); game.queue_free(); await create_timer(.5).timeout
	print("BLOOM STORAGE ","PASS" if failures.is_empty() else "FAIL"," schema migration, namespace, validation, preservation")
	quit(0 if failures.is_empty() else 1)
