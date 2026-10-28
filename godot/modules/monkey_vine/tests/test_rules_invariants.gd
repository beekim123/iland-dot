extends SceneTree
const Rules = preload("../rules/rules.gd")
var failures := 0
const IDLE = {"left":false,"right":false,"grab_held":false,"grab_pressed":false,"grab_released":false}
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ",message)
func _initialize() -> void:
	var witness = JSON.parse_string(FileAccess.get_file_as_string("res://modules/monkey_vine/data/route_witness.json"))
	for route in witness.routes:
		var r = Rules.new()
		r.configure(int(route.seed),int(route.segment))
		var max_error := 0.0
		for input in route.inputs:
			var before: Dictionary = r.snapshot()
			var s: Dictionary = r.step(Rules.H,input)
			check(s.player_pos.is_finite() and s.player_vel.is_finite(),"finite state")
			check(s.player_vel.length() <= 8.8,"bounded energy")
			if s.vine_id != "":
				for vine in s.vines:
					if vine.id == s.vine_id:
						max_error = maxf(max_error,absf(s.grip_pos.distance_to(vine.anchor)-s.rope_length))
			for e in s.events:
				if e.type == "grab":
					# New grab keeps body position continuous (max one bounded fixed-step movement).
					check(s.player_pos.distance_to(before.player_pos)<.09,"no teleport on grab")
				if e.type == "release" and before.vine_id != "":
					check(s.player_vel.distance_to(before.player_vel)<.3,"release momentum")
		check(max_error < .00002,"rope constraint")
		var saved: Dictionary = r.export_progress()
		check(saved.segment == route.segment+1,"cleared save points forward")
		var loaded = Rules.new()
		loaded.configure(8)
		check(loaded.import_progress(saved),"valid progress imports")
		check(loaded.segment == route.segment+1 and loaded.grounded,"safe saved spawn")
	# Framerate grouping with identical control; long dt must process every fixed tick.
	for fps in [15,30,60,120]:
		var r = Rules.new()
		r.configure(2)
		for i in range(fps*2): r.step(1.0/float(fps),IDLE)
		check(absf(r.time-2.0)<.000001,"no lost time fps %d" % fps)
		check(r.player_pos.distance_to(Vector2(0,.32))<.00001,"stable ground")
	var r = Rules.new()
	r.configure(3)
	r.step(2.0,IDLE)
	check(absf(r.time-2)<.000001,"long delta preserved")
	var previous: Dictionary = r.export_progress()
	for bad in [{},{"schema":99},{"schema":1,"game_id":"other"}]:
		check(not r.import_progress(bad),"reject bad progress")
		check(r.export_progress()==previous,"bad progress atomic")
	var bad: Dictionary = previous.duplicate(true)
	bad.checkpoint_score = 100
	check(not r.import_progress(bad),"reject inconsistent score")
	var t: float = r.time
	for dt in [NAN,INF,-1.0,0.0]: r.step(dt,IDLE)
	check(r.time==t,"invalid dt ignored")
	# Checkpoint failure/recovery by ordinary inputs only, never a fixture.
	r.configure(937)
	for input in witness.routes[0].inputs:
		r.step(Rules.H,input)
		if r.checkpoint == "rest": break
	var checkpoint_progress: Dictionary = r.export_progress()
	check(checkpoint_progress.checkpoint=="rest","ordinary route reached safe rest")
	var expected_score: int = r.score
	var failed := false
	var restarted := false
	for i in range(1200):
		var s: Dictionary = r.step(Rules.H,{"right":true})
		for event in s.events:
			if event.type=="fail": failed=true
			if event.type=="restart": restarted=true
		if restarted: break
	check(failed and restarted and r.checkpoint=="rest","ordinary fall recovers checkpoint")
	check(r.score==expected_score,"checkpoint scoring rolls back")
	check(r.import_progress(checkpoint_progress),"mid-run safe checkpoint imports")
	check(r.player_pos==Vector2(12.5,.32),"import starts safe rest, not midair")
	# Boundary fixtures only: these are not completion/playability witnesses.
	r.configure(1)
	r.player_pos = Vector2(0,3)
	r.grounded = false
	r.step(Rules.H,{"grab_held":true})
	check(r.vine_id=="","cannot grab at remote distance")
	r.player_pos = Vector2(0,8)
	r.player_vel = Vector2(0,-100)
	var landed: Vector2 = r._sweep(Vector2(0,8),Vector2(0,-8))
	check(absf(landed.y-.32)<.00001 and r.grounded,"swept platform high speed")
	r.configure(1,2)
	r.player_pos = Vector2(21.5,4.55)
	r.grounded = false
	r._try_grab()
	check(r.vine_id=="bonus_fragile","fragile fixture attaches near actual tip")
	var warned := false
	var broke := false
	for i in range(150):
		var s: Dictionary = r.step(Rules.H,{"grab_held":true})
		for e in s.events:
			if e.type=="break_warning": warned=true
			if e.type=="vine_break":
				check(warned and i>=143,"break has full warning time")
				broke=true
	check(broke,"fragile eventually breaks")
	print("INVARIANT_TEST failures=",failures)
	quit(1 if failures else 0)
