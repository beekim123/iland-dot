extends RefCounted
## Deterministic, fixed-step simulation. All attacks require explicit input edges.
const Build = preload("res://modules/apprentice_yokai_king/build_model.gd")
const BOUNDS = Rect2(80, 164, 1120, 554)
const BUDGETS = [[12,0,0,0,0,0,0],[12,4,0,0,0,0,0],[10,0,4,0,0,1,0],[10,4,0,4,0,0,0],[10,0,4,4,4,0,0],[0,0,0,0,0,0,1]]
const KINDS = ["grunt","shield","spring","bubble","sleeper","elite","boss"]
var rng = RandomNumberGenerator.new()
var build = Build.new()
var phase = "title"
var mode = "standard"
var player = Vector2(640,440)
var facing = Vector2.RIGHT
var hp = 5
var max_hp = 5
var shield = false
var wave = 0
var elapsed = 0.0
var wave_time = 0.0
var countdown = 0.0
var practice_time = 20.0
var enemies: Array = []
var projectiles: Array = []
var effects: Array = []
var pending: Array = []
var seen: Array = []
var events: Array = []
var next_id = 0
var attack_id = 0
var launch_id = 0
var charge = -1.0
var cooldown = 0.0
var dodge_cd = 0.0
var dodge_time = 0.0
var invulnerable = 0.0
var hit_chain = 0
var chain_timer = 0.0
var light_hits = 0
var attack: Dictionary = {}
var spawn_clock = 0.0
var spawned = 0
var defeated = 0
var total = 0
var result_reason = ""
var core_triggers = 0
var animation = "idle"
var animation_time = 0.0
var seed_value = 1
var accumulator = 0.0
var queued: Dictionary = {}
var charged_notified = false
var boss_reinforcements = 0
var attack_scheduler = 0.0
var last_heal = ""
var hurt_time = 0.0

func reset(seed_number: int, difficulty: String = "standard", practice: bool = true):
	seed_value = seed_number
	rng.seed = seed_number
	build.reset(seed_number ^ 8821)
	mode = difficulty
	phase = "practice" if practice else "countdown"
	player = Vector2(640,440)
	facing = Vector2.RIGHT
	hp = 5; max_hp = 5; shield = false; wave = 0; elapsed = 0; wave_time = 0
	practice_time = 20; countdown = 3; enemies.clear(); projectiles.clear(); effects.clear(); pending.clear(); seen.clear(); events.clear()
	next_id = 0; attack_id = 0; launch_id = 0; charge = -1; cooldown = 0; dodge_cd = 0; dodge_time = 0; invulnerable = 0; hit_chain = 0; chain_timer = 0; light_hits = 0; attack = {}; spawned = 0; defeated = 0; total = 0; result_reason = ""; accumulator = 0; queued = {}; boss_reinforcements = 0; core_triggers = 0; attack_scheduler = 0; animation_time = 0; animation = "idle"; last_heal = ""; charged_notified = false; hurt_time = 0
	if not practice: begin_wave()
	else: spawn_enemy("grunt",Vector2(865,420))

func limit() -> float:
	return (180.0 if wave == 6 else 120.0) * (1.5 if mode == "assist" else 1.0)

func advance(delta: float, input: Dictionary):
	if phase in ["title","paused","choice","won","lost"]: return
	for edge in ["press","release","dodge","skip"]:
		if input.get(edge,false): queued[edge] = true
	accumulator += minf(delta,0.1)
	while accumulator >= 1.0/120.0:
		var frame = input.duplicate()
		for edge in ["press","release","dodge","skip"]: frame[edge] = queued.get(edge,false)
		queued.clear()
		step(1.0/120.0,frame)
		accumulator -= 1.0/120.0

func begin_wave():
	wave += 1; wave_time = 0; spawned = 0; defeated = 0; spawn_clock = 0; boss_reinforcements = 0
	enemies.clear(); projectiles.clear(); pending.clear(); effects.clear(); attack = {}; charge = -1; cooldown = 0
	var budget = BUDGETS[wave-1]
	total = 0
	for k in range(7):
		for n in range(budget[k]):
			pending.append({"kind": KINDS[k], "at": 1.2 + floorf(total / 4.0) * 4.5, "pos": spawn_position()})
			total += 1
	phase = "countdown"; countdown = 3
	events.append("wave")

func spawn_position() -> Vector2:
	var side = rng.randi_range(0,3)
	match side:
		0: return Vector2(90,rng.randf_range(190,690))
		1: return Vector2(1190,rng.randf_range(190,690))
		2: return Vector2(rng.randf_range(100,1180),174)
	return Vector2(rng.randf_range(100,1180),708)

func spawn_enemy(kind: String, pos: Vector2):
	next_id += 1
	var health = {"grunt":3.0,"shield":5.0,"spring":4.0,"bubble":3.0,"sleeper":4.0,"elite":20.0,"boss":90.0}[kind]
	enemies.append({"id":next_id,"kind":kind,"pos":pos,"hp":health,"max_hp":health,"face":(player-pos).normalized(),"timer":0.5,"state":"move","target":pos,"vel":Vector2.ZERO,"launch":0,"collided":[],"stagger":0.0,"resist":0.0,"slow":0.0,"move":0,"stage":0,"rings":0})
	if not kind in seen: seen.append(kind)
	spawned += 1

func step(dt: float, input: Dictionary):
	if phase == "countdown":
		countdown -= dt
		if countdown <= 0: phase = "combat"
		return
	if not phase in ["combat","practice"]: return
	if phase == "practice":
		practice_time -= dt
		if input.get("skip",false) or practice_time <= 0:
			begin_wave(); return
	else:
		elapsed += dt; wave_time += dt; spawn_clock += dt
	animation_time += dt
	hurt_time = maxf(0,hurt_time-dt)
	cooldown = maxf(0,cooldown-dt); dodge_cd = maxf(0,dodge_cd-dt); dodge_time = maxf(0,dodge_time-dt); invulnerable = maxf(0,invulnerable-dt); chain_timer = maxf(0,chain_timer-dt); attack_scheduler = maxf(0,attack_scheduler-dt)
	if chain_timer <= 0: hit_chain = 0
	var aim: Vector2 = input.get("aim",facing)
	if aim.length() > 0.01: facing = aim.normalized()
	var movement: Vector2 = input.get("move",Vector2.ZERO)
	movement = movement.limit_length()
	if input.get("dodge",false) and dodge_cd <= 0 and (attack.is_empty() or attack.get("age",0.0) > 0.3):
		dodge_time = 0.24; dodge_cd = [1.1,1.0,0.9][build.level("ayk_roll")]; invulnerable = maxf(invulnerable,0.18); charge = -1
		if movement.length() > 0: facing = movement
		animation = "dodge"; animation_time = 0
	var speed = 225.0
	if charge >= 0: speed *= [0.65,0.8,0.9][build.level("ayk_wind_step")]
	player += (facing * 650.0 if dodge_time > 0 else movement * speed) * dt
	player = player.clamp(BOUNDS.position,BOUNDS.end)
	if input.get("press",false) and cooldown <= 0 and dodge_time <= 0:
		charge = 0; charged_notified = false; animation_time = 0
	if charge >= 0:
		charge += dt; animation = "charge"
		if charge >= 0.75 and not charged_notified: events.append("charge"); charged_notified = true
	if input.get("release",false) and charge >= 0:
		perform_attack(charge); charge = -1
	if not attack.is_empty():
		attack.age += dt
		if attack.age >= 0.12 and not attack.done:
			resolve_attack(); attack.done = true
		if attack.age >= cooldown + 0.45: attack.clear()
	if charge < 0 and cooldown <= 0 and dodge_time <= 0: animation = "move" if movement.length() > 0 else "idle"
	for effect in effects:
		effect.life -= dt
		if effect.get("delay",0.0) > 0:
			effect.delay -= dt
			if effect.delay <= 0: resolve_secondary(effect)
	effects = effects.filter(func(e): return e.life > 0)
	if phase == "practice":
		for dummy in enemies:
			if dummy.hp <= 0: dummy.hp = dummy.max_hp; dummy.pos = Vector2(865,420); events.append("hit")
		return
	for p in pending:
		if p.at <= spawn_clock and enemies.size() < 24 and p.pos.distance_to(player) > 160:
			spawn_enemy(p.kind,p.pos); p.at = INF
	pending = pending.filter(func(p): return p.at != INF)
	for e in enemies:
		if e.hp > 0 or (e.state == "windup" and e.timer <= dt): step_enemy(e,dt)
	for p in projectiles:
		p.pos += p.vel * dt; p.life -= dt
		if p.pos.distance_to(player) < 25: damage_player(); p.life = 0
	projectiles = projectiles.filter(func(p): return p.life > 0 and BOUNDS.grow(30).has_point(p.pos))
	var boss_dead = false
	for e in enemies:
		if e.hp <= 0:
			defeated += 1
			if e.kind == "boss": boss_dead = true
	enemies = enemies.filter(func(e): return e.hp > 0)
	if hp <= 0: finish(false,"体力耗尽 · 小妖王需要休息")
	elif boss_dead: finish(true,"鼓肚大王服气啦！")
	elif wave_time >= limit(): finish(false,"本波时间用尽")
	elif pending.is_empty() and enemies.is_empty() and wave < 6:
		var before = hp
		hp = mini(max_hp,hp + (2 if wave == 3 else 1))
		last_heal = "波间恢复 +%d 心%s" % [hp-before,"（含精英奖励）" if wave == 3 else ""]
		phase = "choice"; charge = -1; attack.clear(); projectiles.clear(); events.append("wave")

func perform_attack(held: float):
	attack_id += 1
	var heavy = held >= 0.45
	var power = clampf(held / 0.75,0,1)
	attack = {"id":attack_id,"age":0.0,"done":false,"heavy":heavy,"full":held >= 0.75,"power":power,"origin":player,"direction":facing}
	cooldown = 0.62 if heavy else 0.22 + 0.23 * [1.0,0.9,0.82][build.level("ayk_fast")]
	animation = "slam" if heavy else "light"; animation_time = 0
	events.append("swing")

func resolve_attack():
	var count = 0
	var origin: Vector2 = attack.origin
	var direction: Vector2 = attack.direction
	var center = origin + direction * 62
	for e in enemies:
		var offset: Vector2 = e.pos - origin
		var hit = e.pos.distance_to(center) <= 94 if attack.heavy else offset.length() <= 118 and (offset.length() < 1 or offset.normalized().dot(direction) >= cos(deg_to_rad(55)))
		if not hit or e.hp <= 0: continue
		count += 1
		var damage = 1.0 + 2.0 * attack.power if attack.heavy else 1.0
		if e.kind == "shield" and (origin-e.pos).normalized().dot(e.face) > 0.35: damage *= 0.3
		e.hp -= damage
		if e.kind in ["boss","elite"]:
			if attack.full and e.resist <= 0:
				e.stagger += 1
				if e.stagger >= 3: e.state = "stunned"; e.timer = 1; e.resist = 5; e.stagger = 0
		else:
			var launch = attack.full or (not attack.heavy and hit_chain % 3 == 2)
			e.vel = direction * ((470 if launch else 180) * [1.0,1.15,1.25][build.level("ayk_elastic")])
			if launch: launch_id += 1; e.launch = launch_id; e.collided = []
	if count > 0:
		hit_chain = 0 if attack.heavy else hit_chain + 1; chain_timer = 1.5; events.append("hit")
		if not attack.heavy: light_hits += 1
		if attack.full: trigger_core(center,direction)
	projectiles = projectiles.filter(func(p): return p.pos.distance_to(center) > 100)
	add_effect({"kind":"slam" if attack.heavy else "swing","pos":center if attack.heavy else origin,"radius":94.0 if attack.heavy else 118.0,"life":0.22,"direction":direction})

func trigger_core(center: Vector2, direction: Vector2):
	var core = build.core
	if core == "": return
	core_triggers += 1
	var effect = {"kind":core,"pos":center,"direction":direction,"life":0.65,"delay":0.28,"damage":1.0,"radius":140.0,"cap":6}
	if core == "ayk_core_wind":
		effect.cap = 3; effect.radius = 240
		if build.level("ayk_wind_return") > 0:
			var echo = effect.duplicate(); echo.delay = 0.5; echo.life = 0.8; echo.damage = 0.5 + 0.5 * build.level("ayk_wind_return"); add_effect(echo)
	elif core == "ayk_core_thunder":
		effect.cap = 3 + build.level("ayk_thunder_chain"); effect.radius = 115
		var threshold = 2 if build.level("ayk_thunder_charge") == 2 else 3
		if build.level("ayk_thunder_charge") > 0 and light_hits >= threshold: effect.damage = 3; light_hits = 0
	elif build.level("ayk_quake_echo") > 0:
		var echo = effect.duplicate(); echo.delay = 0.52; echo.life = 0.8; echo.damage = 0.5 if build.level("ayk_quake_echo") == 1 else 0.75; add_effect(echo)
	add_effect(effect)

func resolve_secondary(effect: Dictionary):
	var hit = 0
	for e in enemies:
		var offset: Vector2 = e.pos-effect.pos
		var inside = offset.length() <= effect.radius
		if effect.kind == "ayk_core_wind": inside = offset.dot(effect.direction) >= -25 and offset.dot(effect.direction) <= 240 and absf(offset.cross(effect.direction)) < 42
		if inside and hit < effect.cap and e.hp > 0:
			e.hp -= effect.damage; hit += 1
			if effect.kind == "ayk_core_quake" and not e.kind in ["boss","elite"]:
				e.vel = offset.normalized()*210; e.launch = 0
				if build.level("ayk_quake_slow") > 0: e.slow = 1

func add_effect(effect: Dictionary):
	if effects.size() < 80: effects.append(effect)
	elif effect.has("delay"):
		# Gameplay telegraphs retain their timing; evict only cosmetic feedback.
		for i in range(effects.size()):
			if not effects[i].has("delay"):
				effects.remove_at(i); effects.append(effect); return
		# At most 2 secondary effects per manual attack; this branch is unreachable
		# with the attack recovery budget, and never resolves damage early.
		effects.append(effect)

func damage_player():
	if invulnerable > 0: return
	if shield: shield = false
	else: hp -= 1
	invulnerable = 1.0; hurt_time = 0.25
	var push = -facing
	var nearest = INF
	for enemy in enemies:
		if player.distance_to(enemy.pos) < nearest:
			nearest = player.distance_to(enemy.pos); push = (player-enemy.pos).normalized()
	player = (player+push*24).clamp(BOUNDS.position,BOUNDS.end)
	events.append("hurt")

func step_enemy(e: Dictionary, dt: float):
	e.resist = maxf(0,e.resist-dt); e.slow = maxf(0,e.slow-dt)
	if e.vel.length() > 8:
		e.pos += e.vel*dt; e.vel = e.vel.move_toward(Vector2.ZERO,720*dt)
		e.pos = e.pos.clamp(BOUNDS.position,BOUNDS.end)
		if e.launch > 0:
			for target in enemies:
				if target.id != e.id and target.hp > 0 and e.collided.size() < 3 and not target.id in e.collided and e.pos.distance_to(target.pos) < 40:
					target.hp -= 1; e.collided.append(target.id)
		return
	e.launch = 0
	e.timer -= dt
	var offset: Vector2 = player-e.pos
	var distance = offset.length()
	if e.state == "stunned":
		if e.timer <= 0: e.state = "move"; e.timer = 1
		return
	if e.kind == "boss":
		step_boss(e,dt,offset); return
	if e.state == "windup":
		if e.timer <= 0:
			if e.kind == "bubble":
				if projectiles.size() < 12: projectiles.append({"pos":e.pos,"vel":(e.target-e.pos).normalized()*150,"life":5.0})
			elif e.kind in ["spring","sleeper"]:
				e.pos = e.target
				if player.distance_to(e.target) < 65: damage_player()
			elif distance < (95 if e.kind == "elite" else 64) and offset.normalized().dot(e.face) > 0.25: damage_player()
			e.state = "recover"; e.timer = 0.8
		return
	if e.state == "recover":
		if e.timer <= 0:
			if e.kind == "elite" and e.move == 0: e.move = 1; e.state = "windup"; e.timer = 0.45; e.face = offset.normalized()
			else: e.move = 0; e.state = "move"; e.timer = 0.2
		return
	e.face = e.face.slerp(offset.normalized(),minf(1,dt*2.5)) if e.kind == "shield" else offset.normalized()
	var reach = 290 if e.kind == "bubble" else (210 if e.kind in ["spring","sleeper"] else 58)
	if distance <= reach and e.timer <= 0 and attack_scheduler <= 0:
		e.state = "windup"; e.timer = 0.85 if e.kind in ["spring","sleeper"] else (0.65 if e.kind == "bubble" else 0.45); e.target = player
		attack_scheduler = 0.2
	else:
		var speed = {"grunt":70,"shield":52,"spring":65,"bubble":58,"sleeper":50,"elite":60}[e.kind]
		if e.slow > 0: speed *= 0.7 if build.level("ayk_quake_slow") == 2 else 0.8
		var move_direction = offset.normalized()
		if e.kind == "bubble" and distance < 190: move_direction *= -1
		if distance > 44 or e.kind == "bubble": e.pos = (e.pos+move_direction*speed*dt).clamp(BOUNDS.position,BOUNDS.end)

func step_boss(e: Dictionary, dt: float, offset: Vector2):
	var ratio = e.hp/e.max_hp
	var wanted = 2 if ratio <= 0.3 else (1 if ratio <= 0.6 else 0)
	if wanted > boss_reinforcements and e.state == "move":
		boss_reinforcements += 1
		for n in range(6): pending.append({"kind":"grunt","at":spawn_clock+1.2+n*0.6,"pos":spawn_position()}); total += 1
		e.state = "recover"; e.timer = 1.4; return
	if e.state == "recover":
		if e.timer <= 0: e.state = "move"; e.timer = 0.5
		return
	if e.state == "windup":
		if e.timer > 0: return
		match e.move % 3:
			0:
				if offset.length() < 155 and offset.normalized().dot(e.face) > 0.1: damage_player()
				e.rings += 1
				if e.rings < 2: e.timer = 0.7; return
			1: e.state = "slide"; e.timer = 0.65; return
			2:
				var radius = 90 + e.rings*65
				if absf(offset.length()-radius) < 28: damage_player()
				e.rings += 1
				if e.rings < 3: e.timer = 0.8; return
		e.state = "recover"; e.timer = 1.2; e.move += 1; return
	if e.state == "slide":
		e.pos = (e.pos + e.face*620*dt).clamp(BOUNDS.position,BOUNDS.end)
		if player.distance_to(e.pos) < 62: damage_player()
		if e.timer <= 0: e.state = "recover"; e.timer = 1.5; e.move += 1
		return
	if offset.length() > 125: e.pos += offset.normalized()*65*dt
	if e.timer <= 0:
		e.state = "windup"; e.timer = 1.05; e.face = offset.normalized(); e.target = player; e.rings = 0; events.append("warning")

func select_card(id: String) -> bool:
	if phase != "choice" or not build.choose(id): return false
	if id == "ayk_recovery":
		if hp < max_hp: hp = mini(max_hp,hp+2)
		elif max_hp < 7: max_hp += 1; hp += 1
		else: shield = true
	begin_wave(); return true

func finish(won: bool, reason: String):
	if phase in ["won","lost"]: return
	animation_time = 0
	phase = "won" if won else "lost"; result_reason = reason; charge = -1; attack.clear(); projectiles.clear(); events.append("result")
	if won: enemies.clear(); pending.clear()
