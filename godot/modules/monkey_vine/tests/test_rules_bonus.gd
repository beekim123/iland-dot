extends SceneTree
const Rules = preload("../rules/rules.gd")
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ",message)
func _initialize() -> void:
	for template in [1,2]:
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://modules/monkey_vine/data/bonus_witness_%d.json"%template))
		var r = Rules.new()
		r.configure(int(route.seed),int(route.segment))
		var grabbed := false
		var golden := false
		var warning_tick := -1
		var release_tick := -1
		var events: Array = []
		for i in range(route.inputs.size()):
			var s: Dictionary = r.step(Rules.H,route.inputs[i])
			for e in s.events:
				events.append({"tick":i,"type":e.type,"id":e.id})
				if e.type=="grab" and e.id==("bonus_moving" if template==1 else "bonus_fragile"):grabbed=true
				if e.type=="collect" and e.id=="golden":golden=true
				if e.type=="break_warning":warning_tick=i
				if e.type=="release" and e.id=="bonus_fragile":release_tick=i
				check(e.type!="fail" and e.type!="vine_break","bonus route stays safe")
		var final: Dictionary = r.snapshot()
		check(grabbed,"normal inputs reach bonus vine")
		check(final.grounded and final.checkpoint==("rest" if template==1 else "exit"),"safe landing commits checkpoint")
		if template==1:
			check(golden,"normal inputs collect golden")
		else:
			check(warning_tick>=0 and release_tick>warning_tick,"warned then deliberately released")
			check((release_tick-warning_tick)*Rules.H<1.2,"released before break deadline")
			check((release_tick-warning_tick)*Rules.H>=.35,"human-visible warning observation period")
		print("BONUS template=",template," frames=",route.inputs.size()," warning_tick=",warning_tick," release_tick=",release_tick," events=",JSON.stringify(events))
	print("BONUS_TEST failures=",failures)
	quit(1 if failures else 0)
