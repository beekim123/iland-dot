extends SceneTree
const Rules = preload("res://modules/dawn_sword/scripts/rules.gd")
## Local structural/transition fixtures. Positions/enemies are arranged solely to
## isolate mechanisms; this test is NOT input-only campaign completion evidence.
func _initialize() -> void:
	var count: int = 0
	for c in range(5):
		for s in range(3):
			var r = Rules.new()
			r.load_level(c,s)
			r.enemies.clear()
			for mechanism in r.level.get("mechanisms",[]):
				r.hero.x = mechanism.x
				r.hero.y = mechanism.y
				r.tick({"interact_pressed":true})
				assert(r.activated.get(mechanism.id,false))
				var restored = Rules.new()
				restored.restore(JSON.parse_string(JSON.stringify(r.profile())))
				assert(restored.activated.get(mechanism.id,false))
				var effect: String = mechanism.get("effect","flames" if mechanism.kind == "lever" else "")
				if effect == "flames":
					for hazard in restored.level.hazards: assert(hazard.kind == "pit")
				if effect == "bridge":
					for hazard in restored.level.hazards:
						if hazard.kind != "pit": continue
						var exists: bool = false
						for platform in restored.level.platforms:
							if platform.kind == "bridge" and platform.x == hazard.x: exists = true
						assert(exists)
				count += 1
	var memory = Rules.new()
	memory.restore({"flags":{"memories":[0.0,2.0]}})
	assert(memory.flags.memories.has(0) and memory.flags.memories.has(2))
	assert(memory.hero.max_hp == 120)
	# Standing on a ledge must not repeatedly snap the actor back to its edge.
	var ledge = Rules.new()
	ledge.hero.x = 768.0
	ledge.hero.y = 410.0
	ledge.hero.grounded = true
	for i in range(20): ledge.tick({"move":1.0})
	assert(ledge.hero.x>830)
	var coop = Rules.new()
	coop.flags.rescued = true
	coop.load_level(4,2)
	coop.enemies.clear()
	for plate in [1120.0,2420.0]:
		coop.hero.x = plate
		coop.hero.y = 620.0
		coop.hero.grounded = true
		coop.tick({"interact_pressed":true})
		for i in range(700): coop.tick({})
		print("COOP plate=",plate," progress=",coop.mechanism_progress," state=",coop.cooperation," hero=",coop.hero.x," princess=",coop.princess.x)
	assert(coop.mechanism_progress == 2)
	for i in range(100): coop.tick({"interact_pressed":true})
	assert(coop.mechanism_progress == 2)
	print("PASS ",count," authored mechanisms + JSON consequences, integer collectibles, ledge walking, two pressure gates; LOCAL fixtures only")
	quit()
