extends SceneTree
## Independent oracle: fixed boundary/contact fixtures are deliberately separate
## from the unmodified, command-only survival run at the end.
const Sim = preload("res://modules/tide_gulp/sim.gd")
var checks := 0
var failures: Array[String] = []
var clock_started := Time.get_ticks_msec()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: ", label)
func fresh():
	var sim = Sim.new()
	sim.start(2026)
	return sim
func fixture(length: float, pos: Vector2, direction: Vector2 = Vector2.RIGHT) -> Dictionary:
	return {"id":999999,"species":"ribbon" if length >= 1.25 else "silver","pos":pos,"dir":direction,
		"velocity":Vector2.ZERO,"length":length,"state":"cruise","state_left":0.0,"warning_left":0.0,
		"threat":false,"home_chunk":0,"slot":999,"phase":0.0,"heading":direction.x,"armed":false,"chase_time":0.0,"lunges":0}
func _initialize() -> void:
	thresholds_and_mouths()
	tide_and_warning()
	world_growth_and_revisit()
	command_only_survival()
	single_life_soak()
	print("TIDE INDEPENDENT: %d checks; %s; %.2fs wall" % [checks,"PASS" if failures.is_empty() else JSON.stringify(failures),(Time.get_ticks_msec()-clock_started)/1000.0])
	quit(0 if failures.is_empty() else 1)
func thresholds_and_mouths() -> void:
	var sim = fresh()
	for length in [1.0,1.25,1.56,1.95,2.44,3.05]:
		for factor in [.79999,.8,.80001,1.24999,1.25,1.25001]:
			var expected := "food" if factor <= .8 else ("danger" if factor >= 1.25 else "peer")
			check(sim.relation(length*factor,length)==expected,"independent 80/125 percent boundary")
	check(sim.relation(4.0,3.05)=="danger" and sim.relation(4.8,3.05)=="danger","adult still has two apex threats")
	# Points come from the declared independent size brackets, never elapsed time.
	for pair in [[.349,0],[.35,45],[.499,45],[.5,100],[.649,100],[.65,180],[.8,180]]:
		sim = fresh(); sim.fish.clear(); sim.drain_events()
		sim.fish.append(fixture(pair[0],Vector2(.48,0)))
		sim._check_contacts()
		check(sim.fish.is_empty() and sim.score==pair[1],"exact size-bracket score %s" % pair[0])
		var summed := 0
		for event in sim.drain_events():
			if event.type=="score": summed += int(event.delta)
		check(summed==sim.score,"score event ledger matches actual consumption")
	sim = fresh(); sim.fish.clear()
	sim.fish.append(fixture(.6,Vector2(-.48,0)))
	sim._check_contacts()
	check(sim.score==0 and sim.fish.size()==1,"own tail is not an eating hitbox")
	sim.player.dir = Vector2.LEFT; sim._check_contacts()
	check(sim.score==100 and sim.fish.is_empty(),"rotated mouth consumes same fish")
	sim = fresh(); sim.fish.clear()
	sim.fish.append(fixture(1,Vector2(.1,0)))
	sim._check_contacts()
	check(sim.alive and sim.score==0 and sim.fish.size()==1 and sim.player.pos!=Vector2.ZERO,"peer contact only separates")
	for point in [Vector2(-.96,0),Vector2(0,.65),Vector2(.96,0)]:
		sim = fresh(); sim.fish.clear()
		var enemy := fixture(2,Vector2.ZERO)
		enemy.armed=true; enemy.state="lunge"
		sim.fish.append(enemy); sim.player.pos=point; sim.player.dash_left=.5
		sim._check_contacts()
		check(sim.alive == (point.x < .9),"predator mouth only; tail/flank safe; dash does not grant immunity")
		if not sim.alive:
			var frozen: Dictionary = sim.snapshot()
			var events: Array = sim.drain_events()
			var death_count := 0
			for event in events:
				if event.type=="death": death_count += 1
			sim.command({"move":Vector2.RIGHT,"dash":true}); sim.tick(20.0)
			check(sim.snapshot()==frozen and sim.drain_events().is_empty(),"death freezes authoritative world, score, cooldown, time and events")
			check(death_count==1,"death emitted exactly once")
func tide_and_warning() -> void:
	var sim = fresh()
	sim.fish.clear(); sim.drain_events(); sim.tick(.9)
	check(sim.score==0 and sim.stats.eaten==0,"elapsed time alone earns no food score")
	for pair in [[0.0,"calm"],[34.999,"calm"],[35.0,"warning"],[39.999,"warning"],[40.0,"flow"],[59.999,"flow"],[60.0,"calm"]]:
		sim.elapsed=pair[0]
		check(sim.tide_state().phase==pair[1],"35+5+20 exact interval boundary")
	sim.elapsed=45.0
	check(sim.current_velocity(4)==Vector2(1,0) and sim.current_velocity(2)==Vector2(.5,0),"current gives all speeds the same one-quarter multiplier")
	check((-Vector2.RIGHT*4+sim.current_velocity(4)).x < 0,"normal upstream swim remains possible")
	sim.elapsed=105.0
	check(sim.current_velocity(4)==Vector2(-1,0),"next 60-second cycle reverses flow")
	for seed_number in range(16):
		sim.start(seed_number)
		check(sim.player.pos==Vector2.ZERO and sim.position_clear(sim.player.pos,.5),"safe opening center is clear")
		for body in sim.fish:
			check(body.pos is Vector2,"all collision coordinates are XY; no hidden depth")
			if sim.relation(body.length)=="danger":
				check(body.pos.distance_to(sim.player.pos)>=14.0 and not body.armed,"new danger has off-screen response clearance and is unarmed")
		check(sim.fish.size()<=60,"initial fish pool bounded")
	# A threat can enter camera view already near the player, but cannot skip
	# its warning + committed windup. This tests time, not UI artwork.
	sim = fresh(); sim.player.pos=Vector2(24,0); sim._update_world(); sim.fish.clear(); sim.elapsed=20.0
	var enemy := fixture(2,Vector2(30,0),Vector2.LEFT); enemy.home_chunk=1
	sim.fish.append(enemy); sim.drain_events()
	sim._update_fish(enemy,1.0/60.0)
	var warnings: Array = sim.drain_events()
	check(warnings.size()==1 and warnings[0].type=="threat" and warnings[0].duration>=1.2,"first visible threat has at least 1.2 seconds warning")
	for step in 100: sim._update_fish(enemy,1.0/60.0)
	check(not enemy.armed,"warning plus windup cannot arm before 1.8 seconds")
	for step in 12: sim._update_fish(enemy,1.0/60.0)
	check(enemy.armed and enemy.state=="lunge","danger eventually commits a genuine attack")
	var committed: Vector2 = enemy.dir
	sim.player.pos+=Vector2.UP*3; sim._update_fish(enemy,.1)
	check(enemy.dir.is_equal_approx(committed),"lunge cannot instantly turn toward an evasive player")
	enemy.chase_time=7.01; sim._update_fish(enemy,.01)
	check(enemy.state=="retreat" and not enemy.armed,"finite chase guarantees a disengagement")
func world_growth_and_revisit() -> void:
	var sim = fresh()
	var prey: Dictionary = sim.fish[0].duplicate(true)
	# Contact eats the real resident slot; travel fixture only controls where we revisit.
	sim.player.pos=prey.pos-Vector2.RIGHT*.48; sim.player.dir=Vector2.RIGHT
	sim._check_contacts()
	var consumed_slot := int(prey.slot)
	var consumed_home := int(prey.home_chunk)
	check(sim._chunk_memory.has(consumed_home),"real eating records a depletion slot")
	sim.player.pos=Vector2(240,0); sim._update_world()
	sim.player.pos=Vector2(consumed_home*24,0); sim._update_world()
	var reappeared := false
	for body in sim.fish:
		if int(body.home_chunk)==consumed_home and int(body.slot)==consumed_slot: reappeared=true
	check(not reappeared,"returning before natural replenishment never re-farms a consumed slot")
	var seen := {}
	for index in range(-36,37):
		sim.player.pos=Vector2(index*24,0); sim._update_world()
		seen[sim.biome_at(sim.player.pos.x)]=true
		check(sim.chunks.size()==5 and sim.fish.size()<=60,"long continuous world has five chunks and at most sixty residents")
		for offset in [-11,0,11]:
			check(sim.position_clear(Vector2(index*24+offset,0),3.05/2),"adult has an unobstructed required center route in every biome")
	check(seen.size()==3,"single connected map reaches three ecological regions")
	sim=fresh(); sim.fish.clear(); sim.player.pos=Vector2(6.5,3.49); sim._nutrition=1000
	var prior := 1.0
	for step in 420:
		sim._update_growth(1.0/60.0)
		check(sim.position_clear(sim.player.pos,sim.player.length*.5),"growth expands actual collision without trapping at reef")
		check(sim.player.length-prior <= .32/60.0+.00001,"growth is continuous rather than a size teleport")
		prior=sim.player.length
	check(sim.player.stage==6 and is_equal_approx(sim.player.length,3.05),"six actual growth stages culminate at adult cap")
	var paused: Dictionary = sim.snapshot()
	sim.set_paused(true); paused=sim.snapshot(); sim.command({"move":Vector2.RIGHT,"dash":true}); sim.tick(20)
	check(sim.snapshot()==paused,"pause freezes the complete authoritative state")
func legal_command(sim) -> Dictionary:
	var p: Dictionary=sim.player
	var target: Vector2=p.pos+Vector2(8, sin(sim.elapsed*.2)*2)
	var closest := INF
	for body in sim.fish:
		var offset: Vector2=body.pos-p.pos
		var distance := offset.length()
		if sim.relation(body.length)=="danger" and distance<4.7:
			return {"move":Vector2(-offset.x, -signf(offset.y+.1)*maxf(2,absf(offset.x))).normalized(),"use_target":false,"dash":true}
		if sim.relation(body.length)=="food" and body.length>=p.length*.35 and distance<closest:
			closest=distance; target=body.pos
	return {"move":Vector2.ZERO,"target":target,"use_target":true,"dash":closest>3 and closest<7}
func command_only_survival() -> void:
	var sim = Sim.new(); sim.start(42)
	var sum_points := 0
	var legal_eats := 0
	var max_stage := 1
	var lives := 1
	var simulated := 0.0
	var previous_score := 0
	# 600 seconds of genuine input; deaths restart honestly. No scene/debug API,
	# forced fish/size/score, teleport, invulnerability or enemy disabling here.
	for frame in 18000:
		sim.command(legal_command(sim)); sim.tick(1.0/30.0); simulated+=1.0/30.0
		var meal_points := 0
		var score_points := 0
		for event in sim.drain_events():
			if event.type=="eat":
				legal_eats+=1; meal_points+=int(event.points)
			if event.type=="score":
				score_points+=int(event.delta); sum_points+=int(event.delta)
				check(event.source=="effective_food","every legal score event identifies actual food")
		if meal_points>0 or score_points>0: check(meal_points==score_points,"each legal score is backed by a same-step meal")
		max_stage=maxi(max_stage,int(sim.player.stage))
		if frame%30==0:
			check(sim.score==sum_points,"legal score is exactly the effective-food event ledger")
			check(sim.score>=previous_score,"survival time never decreases earned food score")
			previous_score=sim.score
			check(sim.chunks.size()==5 and sim.fish.size()<=60 and sim.events.size()<=128 and sim._chunk_memory.size()<=128,"long-run world/event/depletion bounds")
			check(sim.position_clear(sim.player.pos,sim.player.length*.5),"legal travel and growth remain outside reef collision")
		if not sim.alive:
			check(sim.score==sum_points,"death preserves the exact earned-food total")
			lives+=1; sim.restart(41+lives); sum_points=0; previous_score=0
	check(max_stage>=3 and legal_eats>=10,"unmodified legal play reaches at least stage three by real feeding")
	print("TIDE LEGAL RUN: %.0fs, %d lives, %d meals, highest stage %d" % [simulated,lives,legal_eats,max_stage])

func single_life_soak() -> void:
	# One uninterrupted ten-minute run using only legal steering. Staying near
	# the authored safe-origin nursery is intentional, not an immunity switch.
	# Active hunting/threat handling is covered by the separate multi-life run.
	var sim = Sim.new(); sim.start(8008)
	for second in 600:
		for step in 30:
			sim.command({"move":Vector2.ZERO,"target":Vector2.ZERO,"use_target":true})
			sim.tick(1.0/30.0)
		check(sim.alive,"single-life legal nursery soak stays alive")
		check(sim.chunks.size()==5 and sim.fish.size()<=60 and sim.events.size()<=128 and sim._chunk_memory.size()<=128,"uninterrupted long-game resources remain bounded even without draining events")
		if not sim.alive: break
	check(sim.elapsed>=599.99,"uninterrupted 600-second game completed without cheats/restart")
	print("TIDE SINGLE-LIFE SOAK: %.0fs, %d residents, %d chunks, %d pending events" % [sim.elapsed,sim.fish.size(),sim.chunks.size(),sim.events.size()])
