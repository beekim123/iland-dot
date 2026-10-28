extends SceneTree
const Storage = preload("res://modules/dawn_sword/scripts/storage.gd")
const Rules = preload("res://modules/dawn_sword/scripts/rules.gd")
func _initialize() -> void:
	var resume_each: bool = OS.get_cmdline_user_args().has("--resume-each-section")
	var collect_all: bool = OS.get_cmdline_user_args().has("--collect")
	if resume_each and not "dawn-route" in OS.get_environment("XDG_DATA_HOME"):
		push_error("Save/restore route requires isolated dawn-route XDG directory")
		quit(2)
		return
	var storage = Storage.new()
	var r = Rules.new()
	r.difficulty = "adventure" if OS.get_cmdline_user_args().has("--normal") else "story"
	var transitions: Array = []
	var phases: Array = []
	var last: String = ""
	var deaths: int = 0
	for frame in range(250000):
		var key: String = "%d:%d" % [r.chapter,r.segment]
		if key != last:
			transitions.append(key)
			last = key
			print("ROUTE ",key," frame=",frame," hp=",r.hero.hp)
			if resume_each:
				assert(storage.save_profile(r.profile()))
				var loaded: Dictionary = storage.load_profile()
				assert(loaded.ok)
				r = Rules.new()
				r.restore(loaded.data)
		if r.mode == "dead":
			deaths += 1
			if deaths>20: break
			r.retry()
		var input: Dictionary = {"move":1.0,"jump":true,"interact_pressed":frame%10 == 0}
		for mechanism in r.level.get("mechanisms",[]):
			if not r.activated.get(mechanism.id,false):
				input.move = signf(mechanism.x-r.hero.x) if absf(mechanism.x-r.hero.x)>15 else 0.0
				if absf(mechanism.x-r.hero.x)<30 and r.hero.y>mechanism.y+30: input.up = true
				break
		var nearest: Dictionary = {}
		var dist: float = 99999
		for e in r.enemies:
			if e.hp>0 and absf(e.x-r.hero.x)<dist:
				dist = absf(e.x-r.hero.x)
				nearest = e
			if e.kind == "dragon" and not phases.has(e.phase): phases.append(e.phase)
		if not nearest.is_empty() and dist<330 and r.mode == "play":
			input.move = signf(nearest.x-r.hero.x)
			if r.hero.y < nearest.y-85 and r.hero.grounded:
				input.down = true
				input.jump_pressed = true
			elif dist<87:
				input.attack_pressed = frame%12 == 0
				if nearest.state == "windup" and nearest.timer<0.35:
					input.roll_pressed = true
					input.jump_pressed = true
				if nearest.kind in ["shield","bridge_guard"] and nearest.state != "recover": input.jump_pressed = frame%45 == 0
			if r.flags.dawn and r.hero.charge>=50 and dist<150: input.dawn_pressed = frame%20 == 0
		if r.hero.hp<55 and r.hero.heals>0 and r.hero.action == "" and (dist>150 or nearest.state == "recover"):
			input.heal_pressed = true
		for h in r.level.hazards:
			if r.hero.x>h.x-65 and r.hero.x<h.x+h.w and r.hero.grounded:
				input.jump_pressed = true
				input.down = false
				input.attack_pressed = false
				input.move = 1.0
		if r.hero.x>r.level.exit_x-100:
			input.interact_pressed = true
			if r.chapter == 4 and r.segment == 1 and not r.flags.get("seal_broken",false): input.dawn_pressed = true
		if r.chapter == 4 and r.segment == 2 and r.mechanism_progress<2:
			var plate_x: float = 1120.0 if r.mechanism_progress == 0 else 2420.0
			if r.hero.x>plate_x-150 and (nearest.is_empty() or dist>120):
				input.move = signf(plate_x-r.hero.x) if absf(plate_x-r.hero.x)>10 else 0.0
				input.interact_pressed = true
				input.jump_pressed = false
		if collect_all and r.segment == 0 and not r.flags.memories.has(r.chapter) and r.hero.x<1000:
			input = {"move":1.0,"jump":true}
			if r.hero.grounded and ((r.hero.y>600 and r.hero.x>340 and r.hero.x<410) or (r.hero.y<550 and r.hero.x>610)): input.jump_pressed = true
		r.tick(input)
		if r.mode == "ending":
			assert(transitions.size() == 20)
			assert(phases == [1,2,3])
			assert(r.flags.rescued and r.flags.completed and r.flags.princess_safe and r.flags.homecoming)
			if collect_all: assert(r.flags.memories.size() == 5)
			print("PASS INPUT-ONLY campaign 20 sections, 5 bosses, dragon phases ",phases," frames=",frame," deaths=",deaths," all_collectibles=",collect_all," checkpoint_resume=",resume_each)
			quit()
			return
	print("FAIL route stopped ",last," hero=",r.hero," enemies=",r.enemies)
	quit(1)
