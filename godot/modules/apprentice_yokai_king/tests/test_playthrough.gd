extends SceneTree
const Model = preload("res://modules/apprentice_yokai_king/run_model.gd")
var route = "ayk_core_wind"
var mode = "standard"
var seed_value = 2081
var trace_path = ""
var trace: FileAccess
func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("route="): route = arg.substr(6)
		elif arg.begins_with("mode="): mode = arg.substr(5)
		elif arg.begins_with("seed="): seed_value = int(arg.substr(5))
		elif arg.begins_with("trace="): trace_path = arg.substr(6)
	call_deferred("run")

func control(m, time: float) -> Dictionary:
	var target: Dictionary = {}
	var distance = INF
	for e in m.enemies:
		var d: float = e.pos.distance_to(m.player)
		if d < distance: distance = d; target = e
	if target.is_empty(): return {"move":(Vector2(640,440)-m.player).normalized() if m.player.distance_to(Vector2(640,440)) > 30 else Vector2.ZERO}
	var direction: Vector2 = (target.pos-m.player).normalized()
	var desired = 123.0
	if target.kind == "boss": desired = 68
	var move: Vector2 = direction if distance > desired+8 else (-direction if distance < desired-8 else Vector2.ZERO)
	var dodge = false
	# Evaluate telegraphed damage, then move to clear space; only legal actions.
	for e in m.enemies:
		var from_enemy: Vector2 = m.player-e.pos
		var dist: float = from_enemy.length()
		if e.state == "windup":
			if e.kind in ["spring","sleeper"] and m.player.distance_to(e.target) < 95:
				move += (m.player-e.target).normalized()*3 if m.player.distance_to(e.target)>1 else Vector2.from_angle(time)*3
				if e.timer < 0.25: dodge = true
			elif e.kind == "boss":
				match e.move%3:
					0:
						if dist < 180 and from_enemy.normalized().dot(e.face) > -0.1: move = (e.pos-e.face*85-m.player).normalized()*3; dodge = e.timer < 0.2
					1:
						if absf(from_enemy.cross(e.face)) < 100: move += e.face.orthogonal()*3; dodge = e.timer < 0.2
					2:
						var radius = 90+e.rings*65
						if absf(dist-radius) < 60: move += from_enemy.normalized()*(3 if dist>=radius else -3); dodge = e.timer < 0.2
			elif dist < 100 and e.kind != "bubble": move += from_enemy.normalized()*2; dodge = e.timer < 0.15
		elif e.state == "slide" and dist < 130: move += e.face.orthogonal()*4; dodge = true
		if dist < 65: move += from_enemy.normalized()*2
	for p in m.projectiles:
		if p.pos.distance_to(m.player) < 90:
			move += (m.player-p.pos).normalized()*2; dodge = p.pos.distance_to(m.player) < 45
	# Avoid getting trapped on the boundary.
	if m.player.x < 120: move.x = maxf(move.x,0.6)
	if m.player.x > 1160: move.x = minf(move.x,-0.6)
	if m.player.y < 205: move.y = maxf(move.y,0.6)
	if m.player.y > 675: move.y = minf(move.y,-0.6)
	return {"move":move.normalized(),"aim":direction,"press":m.charge < 0 and m.cooldown <= 0,"release":m.charge >= 0.76,"dodge":dodge and m.dodge_cd <= 0}

func run():
	if trace_path != "":
		trace = FileAccess.open(trace_path,FileAccess.WRITE)
		assert(trace != null)
		trace.store_line(JSON.stringify({"seed":seed_value,"mode":mode,"route":route,"dt":1.0/60.0}))
	var m = Model.new()
	m.reset(seed_value,mode,false)
	var steps = 0
	var choices = 0
	var wave_seen = 0
	while not m.phase in ["won","lost"] and steps < 120000:
		if m.wave != wave_seen:
			wave_seen = m.wave; print("WAVE ",m.wave," hp=",m.hp," elapsed=",m.elapsed)
		if m.phase == "choice":
			var offers = m.build.offers()
			var pick = route if choices == 0 else offers[0]
			if choices > 0:
				for id in offers:
					if not id in ["ayk_fast","ayk_elastic","ayk_roll"]: pick=id; break
			assert(m.select_card(pick)); choices += 1
			if trace: trace.store_line(JSON.stringify({"choose":pick}))
		else:
			var input = control(m,steps/60.0)
			if trace:
				var record = input.duplicate()
				for key in ["move","aim"]:
					if record.has(key): record[key] = [record[key].x,record[key].y]
				trace.store_line(JSON.stringify(record))
			m.advance(1.0/60.0,input)
		steps += 1
	print("PLAYTHROUGH route=",route," mode=",mode," seed=",seed_value," result=",m.phase," wave=",m.wave," choices=",choices," hp=",m.hp," elapsed=",m.elapsed," core_triggers=",m.core_triggers," reason=",m.result_reason)
	if trace:
		trace.store_line(JSON.stringify({"result":m.phase,"hp":m.hp,"elapsed":m.elapsed,"wave":m.wave,"choices":choices})); trace.close()
	quit(0 if m.phase == "won" and choices == 5 else 1)
