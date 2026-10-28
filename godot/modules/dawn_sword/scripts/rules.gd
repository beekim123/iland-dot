extends RefCounted
const Campaign = preload("res://modules/dawn_sword/data/campaign.gd")
const STEP = 1.0 / 60.0
var chapter: int = 0
var segment: int = 0
var level: Dictionary
var hero: Dictionary
var enemies: Array = []
var projectiles: Array = []
var effects: Array = []
var events: Array = []
var flags: Dictionary = {"rescued":false,"dawn":false,"completed":false,"memories":[],"shortcuts":[]}
var mode: String = "play"
var story: String = "王都庆典被龙火划开。艾琳为保护居民被掳。莱恩：我一定会带你回家。"
var time: float = 0.0
var difficulty: String = "adventure"
var checkpoint: Dictionary = {"chapter":0,"segment":0}
var total_deaths: int = 0
var attack_serial: int = 0
var crumbles: Dictionary = {}
var mechanism_progress: int = 0
var story_timer: float = 7.0

func _init() -> void:
	load_level(0,0)

func load_level(c: int, s: int) -> void:
	chapter = clampi(c,0,4)
	segment = clampi(s,0,3)
	level = Campaign.level(chapter,segment)
	checkpoint = {"chapter":chapter,"segment":segment}
	events.clear()
	hero = {"x":180.0,"y":620.0,"vx":0.0,"vy":0.0,"facing":1,"hp":100.0+flags.memories.size()*10.0,"max_hp":100.0+flags.memories.size()*10.0,"animation":"idle","anim_time":0.0,"grounded":true,"guard":false,"charge":100.0 if flags.dawn else 0.0,"heals":5 if difficulty == "story" else 3,"action":"","action_time":0.0,"invuln":0.0,"cooldown":0.0,"combo":0,"combo_window":0.0,"jump_buffer":0.0,"coyote":0.12,"safe_x":180.0,"safe_y":620.0,"guard_time":0.0,"guard_stress":0.0,"hit_ids":[],"drop":0.0}
	enemies.clear()
	for spec in level.enemies:
		var stats: Array = Campaign.ENEMY_STATS[spec.kind]
		enemies.append({"id":enemies.size(),"kind":spec.kind,"x":spec.x,"y":spec.y,"home_x":spec.x,"hp":float(stats[0]),"max_hp":float(stats[0]),"speed":stats[1],"damage":stats[2],"windup":stats[3],"reach":stats[4],"facing":-1,"state":"idle","timer":0.0,"animation":"idle","anim_time":0.0,"boss":spec.boss,"phase":1,"attack_count":0,"stun":0.0,"hit":false})
	projectiles.clear()
	crumbles.clear()
	mechanism_progress = 0
	effects.clear()
	mode = "play"
	events.append({"type":"checkpoint"})

func snapshot() -> Dictionary:
	return {"chapter":chapter,"segment":segment,"level":level,"hero":hero,"enemies":enemies,"projectiles":projectiles,"effects":effects,"flags":flags,"story":story,"mode":mode,"time":time}

func profile() -> Dictionary:
	return {"chapter":checkpoint.chapter,"segment":checkpoint.segment,"flags":flags.duplicate(true),"difficulty":difficulty,"deaths":total_deaths}

func restore(data: Dictionary) -> void:
	flags.merge(data.get("flags",{}).duplicate(true),true)
	difficulty = data.get("difficulty","adventure")
	total_deaths = int(data.get("deaths",0))
	load_level(int(data.get("chapter",0)),int(data.get("segment",0)))
	if flags.completed and chapter == 4 and segment == 3:
		mode = "epilogue"
		for e in enemies:
			if e.kind == "dragon":
				e.hp = 0.0
				e.animation = "death"
	story = "篝火仍然温暖。继续前进吧。"
	story_timer = 4.0

func tick(input: Dictionary, dt: float = STEP) -> void:
	if mode != "play" and mode != "epilogue": return
	time += dt
	story_timer = maxf(0.0,story_timer-dt)
	if story_timer <= 0: story = ""
	for key in ["invuln","cooldown","combo_window","jump_buffer","coyote","drop"]:
		hero[key] = maxf(0.0,float(hero[key])-dt)
	hero.anim_time += dt
	if hero.grounded: hero.coyote = 0.12
	if input.get("jump_pressed",false): hero.jump_buffer = 0.15
	var axis: float = clampf(float(input.get("move",0)), -1,1)
	var old_guard: bool = hero.guard
	hero.guard = input.get("guard",false) and hero.action == "" and hero.grounded
	if hero.guard:
		hero.guard_time = hero.guard_time+dt if old_guard else 0.0
	else:
		hero.guard_stress = maxf(0.0,hero.guard_stress-dt*28)
	if hero.action != "":
		_step_action(input,dt)
	else:
		if absf(axis)>0.1: hero.facing = 1 if axis>0 else -1
		hero.vx = axis*(100.0 if hero.guard else 245.0)
		if input.get("roll_pressed",false) and hero.cooldown <= 0:
			_action("roll",0.48)
			hero.invuln = 0.25
			hero.cooldown = 0.72
		elif input.get("attack_pressed",false):
			hero.combo = (int(hero.combo)%3)+1 if hero.combo_window>0 else 1
			_action("attack"+str(hero.combo) if hero.grounded else "air_attack",0.48 if hero.combo<3 else 0.64)
			hero.hit_ids = []
			attack_serial += 1
		elif input.get("dawn_pressed",false) and flags.dawn and hero.charge>=50:
			hero.charge -= 50
			_action("dawn",0.8)
			hero.hit_ids = []
			events.append({"type":"dawn"})
		elif input.get("heal_pressed",false) and hero.heals>0 and hero.hp<hero.max_hp:
			_action("heal",0.9)
	if hero.jump_buffer>0 and hero.coyote>0 and hero.action not in ["heal","hurt","death"]:
		hero.vy = -570.0
		hero.grounded = false
		hero.coyote = 0.0
		hero.jump_buffer = 0.0
		events.append({"type":"jump"})
	if input.get("down",false) and input.get("jump_pressed",false) and hero.y<610:
		hero.drop = 0.25
		hero.y += 8
		hero.vy = 80
	var climbing: bool = false
	for ladder in level.ladders:
		if absf(hero.x-ladder.x)<30 and hero.y>=ladder.top and input.get("up",false):
			hero.y = maxf(ladder.top,hero.y-170*dt)
			hero.vy = 0.0
			climbing = true
	var prev_y: float = hero.y
	hero.x = clampf(hero.x+hero.vx*dt,25.0,level.width-25.0)
	if chapter == 4 and segment == 2 and mechanism_progress<2:
		hero.x = minf(hero.x,1260.0 if mechanism_progress == 0 else 2560.0)
	if not climbing:
		hero.vy += (1050.0 if input.get("jump",false) and hero.vy<0 else 1650.0)*dt
		hero.y += hero.vy*dt
	hero.grounded = false
	for platform in level.platforms:
		var py: float = platform.y
		if platform.kind == "crumble" and crumbles.get(str(platform.x),0.0)>0.65: continue
		if platform.kind == "moving": py += sin(time*1.3)*42
		if platform.kind == "ground" and _over_pit(hero.x): continue
		if platform.kind != "ground" and hero.drop>0: continue
		if hero.x>=platform.x-8 and hero.x<=platform.x+platform.w+8 and prev_y<=py+3 and hero.y>=py and hero.vy>=0:
			hero.y = py
			hero.vy = 0.0
			hero.grounded = true
			if platform.kind == "crumble": crumbles[str(platform.x)] = crumbles.get(str(platform.x),0.0)+dt
			if platform.kind != "crumble":
				hero.safe_x = hero.x
				hero.safe_y = hero.y
	if hero.y>850:
		_damage_hero(10,0,true)
		hero.x = hero.safe_x-35*hero.facing
		hero.y = hero.safe_y
		hero.vy = 0.0
	for hazard in level.hazards:
		if hazard.kind != "pit" and fmod(time, hazard.period)>1.7 and hero.x>hazard.x and hero.x<hazard.x+hazard.w and hero.y>560:
			_damage_hero(14,0,true)
	if mode == "play":
		_step_enemies(dt)
		_step_projectiles(dt)
	if hero.action == "":
		_set_anim("climb" if climbing else ("guard" if hero.guard else ("jump" if hero.vy<0 and not hero.grounded else ("fall" if not hero.grounded else ("run" if absf(hero.vx)>5 else "idle")))))
	if input.get("interact_pressed",false): _interact()
	if hero.x>780 and hero.x<1000 and hero.y<435:
		var memory: int = chapter
		if not flags.memories.has(memory):
			flags.memories.append(memory)
			hero.max_hp += 10
			hero.hp = minf(hero.max_hp,hero.hp+20)
			_tell("找到王国记忆：愿晨曦永远照耀归乡的人。",4)
			events.append({"type":"checkpoint"})
	for effect in effects: effect.life -= dt
	effects = effects.filter(func(e): return e.life>0)

func _over_pit(x: float) -> bool:
	for hazard in level.hazards:
		if hazard.kind == "pit" and x>hazard.x and x<hazard.x+hazard.w: return true
	return false

func _action(name: String, duration: float) -> void:
	if name.begins_with("attack") or name == "air_attack": events.append({"type":"swing"})
	if name == "roll": events.append({"type":"roll"})
	hero.action = name
	hero.action_time = duration
	_set_anim(name)
	hero.anim_time = 0.0

func _set_anim(name: String) -> void:
	if hero.animation != name:
		hero.animation = name
		hero.anim_time = 0.0

func _step_action(input: Dictionary, dt: float) -> void:
	hero.action_time -= dt
	var action: String = hero.action
	hero.vx = hero.facing*410.0 if action == "roll" else hero.vx*0.72
	if action.begins_with("attack") or action in ["air_attack","dawn"]:
		var reach: float = 155.0 if action == "dawn" else 92.0
		if hero.anim_time>=0.12 and hero.anim_time<=0.34:
			for enemy in enemies:
				if enemy.hp<=0 or hero.hit_ids.has(enemy.id): continue
				if absf(enemy.y-hero.y)<110 and (enemy.x-hero.x)*hero.facing>-18 and (enemy.x-hero.x)*hero.facing<reach:
					hero.hit_ids.append(enemy.id)
					var damage: float = 52.0 if action == "dawn" else (28.0 if hero.combo == 3 else 18.0)
					var blocked: bool = enemy.kind in ["shield","bridge_guard"] and enemy.state not in ["recover","stagger"] and (hero.x-enemy.x)*enemy.facing>0 and action != "dawn"
					if blocked: damage = 3.0
					enemy.hp = maxf(0,enemy.hp-damage)
					hero.charge = minf(100,hero.charge+10)
					enemy.stun = 0.16 if not enemy.boss else 0.0
					if action == "dawn" and enemy.state == "windup":
						enemy.state = "stagger"
						enemy.timer = 2.0
					effects.append({"x":enemy.x,"y":enemy.y-50,"life":0.18,"type":"hit"})
					events.append({"type":"block" if blocked else "hit"})
					if enemy.hp<=0: _enemy_defeated(enemy)
			if action == "dawn" and chapter == 4 and segment == 1 and hero.x>level.exit_x-180:
				flags["seal_broken"] = true
				_tell("暗焰封印碎裂了。艾琳就在门后！",4)
		if input.get("attack_pressed",false) and hero.action_time<0.22: hero["queued_attack"] = true
	if hero.action_time<=0:
		if action == "heal":
			hero.heals -= 1
			hero.hp = minf(hero.max_hp,hero.hp+45)
			events.append({"type":"heal"})
		hero.action = ""
		if action.begins_with("attack"): hero.combo_window = 0.4
		if hero.get("queued_attack",false):
			hero.queued_attack = false
			if absf(float(input.get("move",0)))>0.1: hero.facing = 1 if input.move>0 else -1
			hero.combo = int(hero.combo)%3+1
			hero.hit_ids = []
			_action("attack"+str(hero.combo),0.64 if hero.combo == 3 else 0.48)

func _damage_hero(amount: float, source_x: float, unblockable: bool = false) -> void:
	if hero.invuln>0 or mode not in ["play","epilogue"]: return
	if hero.guard and not unblockable and (source_x-hero.x)*hero.facing>=0:
		hero.guard_stress += amount
		hero.x -= hero.facing*12
		events.append({"type":"block"})
		if hero.guard_time<0.16:
			for e in enemies:
				if absf(e.x-source_x)<5 and not e.boss:
					e.state = "stagger"
					e.timer = 1.0
		if hero.guard_stress<60: return
		hero.guard = false
		hero.guard_stress = 0.0
	hero.hp -= amount*(0.55 if difficulty == "story" else 1.0)
	hero.invuln = 0.7
	hero.queued_attack = false
	_action("hurt",0.28)
	events.append({"type":"hurt"})
	if hero.hp<=0:
		hero.hp = 0
		mode = "dead"
		_set_anim("death")
		total_deaths += 1
		events.append({"type":"death"})

func _step_enemies(dt: float) -> void:
	for e in enemies:
		if e.hp<=0:
			e.animation = "death"
			e.anim_time += dt
			continue
		e.anim_time += dt
		e.stun = maxf(0,e.stun-dt)
		if e.stun>0:
			e.animation = "hurt"
			continue
		var distance: float = absf(hero.x-e.x)
		if distance>650 and e.state == "idle": continue
		if e.state in ["idle","approach"]:
			e.facing = 1 if hero.x>e.x else -1
			if distance>e.reach*0.82:
				e.x += e.facing*e.speed*dt
				e.animation = "run"
			else:
				e.state = "windup"
				e.timer = e.windup*(0.82 if e.phase == 3 else 1.0)
				e.attack_count += 1
				e.animation = "windup"
				e.anim_time = 0.0
				e.hit = false
				events.append({"type":"warning"})
		elif e.state == "windup":
			e.timer -= dt
			if e.timer<=0:
				e.state = "attack"
				e.timer = 1.6 if e.kind == "rock_lizard" else 0.38
				e.animation = "attack"
				e.anim_time = 0.0
				if e.kind == "bridge_guard" and e.attack_count%2 == 0:
					projectiles.append({"x":e.x,"y":605.0,"vx":e.facing*240.0,"damage":18,"life":2.0,"fire":true})
				if e.kind in ["archer","slinger","mage","salamander"]:
					projectiles.append({"x":e.x,"y":e.y-40,"vx":e.facing*290.0,"damage":e.damage,"life":3.0,"fire":e.kind in ["mage","salamander"]})
				if e.kind == "dragon" and e.phase>=2 and e.attack_count%3 == 0:
					e.state = "flight" if e.phase == 2 and e.attack_count%6 == 0 else "breath"
					e.timer = 3.0 if e.state == "flight" else 2.2
					e.animation = "breath"
					_tell("艾琳：躲到两端的石柱后！晨光能打断蓄力龙息！",3)
		elif e.state == "flight":
			e.timer -= dt
			e.y = 400.0
			e.animation = "fly"
			e.x = 900.0+sin(e.timer*1.7)*420.0
			if fmod(e.timer,0.5)<dt:
				projectiles.append({"x":e.x,"y":430.0,"vx":0.0,"vy":230.0,"damage":20,"life":2.0,"fire":true})
			if e.timer<=0:
				e.y = 620.0
				e.state = "stagger"
				e.timer = 2.4
				e.animation = "stagger"
		elif e.state == "attack":
			e.timer -= dt
			if e.kind == "axe_lord" and e.attack_count%2 == 0:
				e.x += e.facing*210*dt
				e.y = 620-sin((0.38-e.timer)/0.38*PI)*95
			if e.kind in ["wolf","rock_lizard"] or (e.kind == "dragon" and e.phase == 3):
				e.x = clampf(e.x+e.facing*370*dt,80,level.width-80)
			if e.kind not in ["archer","slinger","mage","salamander"] and not e.hit and absf(hero.x-e.x)<e.reach+15 and absf(hero.y-e.y)<78:
				e.hit = true
				_damage_hero(e.damage,e.x,e.boss and e.attack_count%3 == 0)
			if e.timer<=0:
				e.y = 620.0
				e.state = "recover"
				e.timer = (2.4 if e.kind == "rock_lizard" else 1.25) if e.boss else 0.85
				e.animation = "idle"
		elif e.state == "breath":
			e.timer -= dt
			if e.timer<1.1 and hero.x>300 and hero.x<level.width-300 and hero.y>540:
				_damage_hero(23,e.x,true)
			if e.timer<=0:
				e.state = "stagger"
				e.timer = 2.4
				e.animation = "stagger"
		else:
			e.timer -= dt
			if e.timer<=0: e.state = "approach"
		if e.kind == "dragon":
			var next_phase: int = 3 if e.hp<=e.max_hp/3 else (2 if e.hp<=e.max_hp*2/3 else 1)
			if next_phase>e.phase:
				e.phase = next_phase
				e.state = "stagger"
				e.timer = 2.0
				hero.charge = 100.0
				_tell("恶龙阶段 %d / 3：%s" % [e.phase,"烈焰封场" if e.phase == 2 else "最后一剑"],4)
		elif e.kind == "ash_knight":
			e.phase = 2 if e.hp<e.max_hp/2 else 1
			e.speed = 150.0 if e.phase == 2 else 115.0

func _step_projectiles(dt: float) -> void:
	for p in projectiles:
		p.x += p.vx*dt
		p.y += p.get("vy",0.0)*dt
		p.life -= dt
		if absf(p.x-hero.x)<22 and absf(p.y-(hero.y-38))<35:
			_damage_hero(p.damage,p.x-p.vx*0.1,p.fire)
			p.life = 0
	projectiles = projectiles.filter(func(p): return p.life>0)

func _enemy_defeated(e: Dictionary) -> void:
	e.animation = "death"
	e.anim_time = 0.0
	events.append({"type":"enemy_down"})
	if e.boss:
		_tell("道路已经打开。走向金色路标，继续营救。",5)
		if e.kind == "dragon":
			flags["dragon_defeated"] = true
			flags.completed = true
			mode = "epilogue"
			_tell("格拉姆倒下了。艾琳：你真的来了。莱恩：我们回家吧。向右走，共迎黎明。",12)
			events.append({"type":"checkpoint"})

func _interact() -> void:
	if mode == "epilogue" and hero.x>level.exit_x-80:
		mode = "ending"
		events.append({"type":"ending"})
		return
	if absf(hero.x-level.checkpoint_x)<90:
		hero.hp = hero.max_hp
		hero.heals = 5 if difficulty == "story" else 3
		hero.charge = 100 if flags.dawn else 0
		events.append({"type":"checkpoint"})
		_tell("篝火：冒险已保存。生命与药剂已补满。",3)
		return
	if chapter == 4 and segment == 2:
		var gate_x: float = 1200.0 if mechanism_progress == 0 else 2500.0
		if absf(hero.x-gate_x)<100 and mechanism_progress<2:
			mechanism_progress += 1
			_tell("艾琳接住机关！第%d道防护门已打开。" % mechanism_progress,4)
			return
	if hero.x<level.exit_x-95: return
	if chapter == 4 and segment == 2 and mechanism_progress<2:
		_tell("需要与艾琳开启两道机关。寻找沿途的金色双环标记。",4)
		return
	if level.boss:
		for e in enemies:
			if e.boss and e.hp>0:
				_tell("必须先战胜守路的敌人。",3)
				return
	if chapter == 3 and segment == 2:
		flags.dawn = true
		_tell("晨光铭文回应了你的勇气。晨光斩已觉醒！近战命中充能，U 释放。",7)
	if chapter == 4 and segment == 1:
		if not flags.get("seal_broken",false):
			hero.charge = maxf(hero.charge,50.0)
			_tell("囚室前的晨光石补充了力量。用 U 击破暗焰封印。",4)
			return
		flags.rescued = true
		_tell("莱恩打开囚门。艾琳：我找到通往防护厅的机关，我们一起走！",7)
	if chapter == 4 and segment == 2:
		flags["princess_safe"] = true
		_tell("艾琳开启古代防护机关。公主已安全，去结束恶龙的暴行。",7)
	if chapter == 1 and segment == 2: flags.shortcuts.append("bridge")
	if segment<3:
		load_level(chapter,segment+1)
	elif chapter<4:
		load_level(chapter+1,0)
		events.append({"type":"chapter"})

func _tell(text: String, duration: float) -> void:
	story = text
	story_timer = duration

func retry() -> void:
	load_level(checkpoint.chapter,checkpoint.segment)
	story = "从篝火重新出发。观察前摇，留出反击的时间。"
	story_timer = 4.0
