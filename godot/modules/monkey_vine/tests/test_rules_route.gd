extends SceneTree
const Rules = preload("../rules/rules.gd")
var failures := 0
func check(condition: bool,message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL ",message)
func control(s: Dictionary,held: bool,offset: float = 0.0) -> Dictionary:
	var next_held := held
	if s.grounded: next_held = not held and s.player_pos.x < 25 and s.player_pos.x > (1.0 if s.player_pos.x < 11 else 15.0)+offset
	elif s.vine_id != "":
		var v: Dictionary = {}
		for item in s.vines:
			if item.id == s.vine_id: v = item
		next_held = not (s.player_pos.x > v.anchor.x+.65+offset and s.player_vel.x > 0)
	else: next_held = true
	return {"right":true,"left":false,"grab_held":next_held,"grab_pressed":next_held and not held,"grab_released":held and not next_held}
func _initialize() -> void:
	var witnesses: Dictionary = {"schema":1,"rules":"monkey_vine_v1","fixed_dt":1.0/120.0,"routes":[]}
	for template in range(4):
		for offset in [0.0,-.06,.06]:
			var r = Rules.new()
			r.configure(937,template)
			var held := false
			var grabs: Array = []
			var route: Array = []
			var cleared := false
			for frame in range(1800):
				var s: Dictionary = r.snapshot()
				var input := control(s,held,offset)
				held = input.grab_held
				route.append(input)
				s = r.step(1.0/120,input)
				for e in s.events:
					if e.type == "grab": grabs.append(e.id)
					check(e.type != "fail","route fell template %d offset %.2f" % [template,offset])
				if s.phase == "segment_clear":
					cleared = true
					break
			check(cleared,"template %d offset %.2f did not clear" % [template,offset])
			check(grabs.size() >= 6,"all six vines must be used")
			print("ROUTE template=",template," offset=",offset," frames=",route.size()," grabs=",grabs," cleared=",cleared)
			if offset == 0:
				witnesses.routes.append({"seed":937,"segment":template,"inputs":route,"grabs":grabs})
				# Exact ordinary key stream replay, no state fixture/teleport.
				var replay = Rules.new()
				replay.configure(937,template)
				for input in route: replay.step(1.0/120,input)
				check(replay.snapshot().phase == "segment_clear","witness replay")
	if failures == 0:
		var file := FileAccess.open("res://modules/monkey_vine/data/route_witness.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(witnesses))
	print("ROUTE_TEST failures=",failures)
	quit(1 if failures else 0)
