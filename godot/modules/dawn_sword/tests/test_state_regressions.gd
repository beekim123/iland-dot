extends SceneTree
## LOCAL STATE REGRESSIONS ONLY. Fixtures set local state to exercise restoration;
## these checks are not evidence of input-driven campaign completion.
const Rules = preload("res://modules/dawn_sword/scripts/rules.gd")
const Campaign = preload("res://modules/dawn_sword/data/campaign.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_campaign_configuration()
	_test_restore_and_retry()
	_test_completed_restore()
	print("Dawn Sword local state/config regressions: %d checks, %d failures; NOT campaign completion evidence" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _test_campaign_configuration() -> void:
	var names: Array = []
	var ordinary: Dictionary = {}
	var bosses: Array = []
	for chapter in range(5):
		for segment in range(4):
			var level: Dictionary = Campaign.level(chapter, segment)
			_check(not names.has(level.name), "unique segment name")
			names.append(level.name)
			_check(level.width > 0 and level.checkpoint_x >= 0 and level.exit_x < level.width and level.exit_x > level.checkpoint_x, "bounded checkpoint and exit")
			_check(not level.objective.is_empty() and not level.chapter_name.is_empty(), "segment has objective and chapter")
			_check(level.boss == (segment == 3), "fourth section boss marker")
			var boss_count := 0
			for enemy in level.enemies:
				_check(Campaign.ENEMY_STATS.has(enemy.kind), "enemy has rules stats")
				_check(enemy.x > 0 and enemy.x < level.width, "enemy spawn within level")
				if enemy.boss:
					boss_count += 1
					bosses.append(enemy.kind)
				else:
					ordinary[enemy.kind] = true
			_check(boss_count == (1 if segment == 3 else 0), "one regional/final boss at chapter end")
			for platform in level.platforms:
				_check(platform.x >= 0 and platform.w > 0 and platform.x + platform.w <= level.width, "platform bounds")
			for hazard in level.hazards:
				_check(hazard.x > level.checkpoint_x + 90 and hazard.x + hazard.w < level.exit_x, "safe checkpoint/exit outside hazards")
	_check(names.size() == 20, "all 20 configured sections")
	_check(ordinary.size() == 9, "nine distinct ordinary enemies")
	_check(bosses == ["axe_lord", "bridge_guard", "rock_lizard", "ash_knight", "dragon"], "four regional bosses and final dragon")

func _test_restore_and_retry() -> void:
	var saved := {"chapter": 2, "segment": 3, "difficulty": "story", "deaths": 7, "flags": {"dawn": true, "rescued": false, "completed": false, "memories": [0, 1], "shortcuts": ["bridge"]}}
	var rules := Rules.new()
	rules.restore(saved)
	_check(rules.chapter == 2 and rules.segment == 3 and rules.checkpoint == {"chapter":2,"segment":3}, "restore exact boss-door checkpoint")
	_check(rules.flags.dawn and rules.flags.memories == [0,1] and rules.flags.shortcuts == ["bridge"], "restore permanent progress")
	_check(rules.difficulty == "story" and rules.total_deaths == 7 and rules.hero.heals == 5, "restore difficulty and death count")
	_check(rules.hero.max_hp == 120 and rules.hero.hp == rules.hero.max_hp, "restore fully heals upgraded max HP")
	_check(rules.hero.charge == 100, "restore dawn charge")
	_check(rules.enemies.size() == 1 and rules.enemies[0].kind == "rock_lizard" and rules.enemies[0].hp == rules.enemies[0].max_hp, "boss restarts at full health")
	# A caller changing its loaded profile must not mutate a live rules instance.
	saved.flags.memories.append(4)
	_check(not rules.flags.memories.has(4), "restore owns deep copy of permanent progress")
	var profile: Dictionary = rules.profile()
	profile.flags.shortcuts.append("fixture")
	_check(not rules.flags.shortcuts.has("fixture"), "profile returns detached copy")
	# Local dirty-state fixture: death/retry must clear transient state and retain
	# progression. It is intentionally not an input-driven victory or route test.
	rules.projectiles.append({"x":500.0,"y":500.0,"vx":200.0,"life":3.0,"damage":5,"fire":false})
	rules.effects.append({"x":500.0,"y":500.0,"life":2.0,"type":"hit"})
	rules.crumbles["1560"] = 0.9
	rules.mechanism_progress = 1
	rules.hero.queued_attack = true
	rules.hero.guard_stress = 55.0
	rules.hero.combo = 3
	rules.hero.invuln = 0.0
	rules.hero.hp = 1.0
	rules.events.clear()
	rules._damage_hero(100, rules.hero.x + 80, true)
	_check(rules.mode == "dead" and rules.total_deaths == 8, "death records once")
	rules.tick({"attack_pressed":true}, 1.0/60)
	_check(rules.mode == "dead" and rules.total_deaths == 8, "dead tick cannot resume combat")
	rules.retry()
	_check(rules.mode == "play" and rules.chapter == 2 and rules.segment == 3, "retry restores checkpoint")
	_check(rules.projectiles.is_empty() and rules.effects.is_empty() and rules.crumbles.is_empty(), "retry clears projectiles effects and crumbles")
	_check(rules.mechanism_progress == 0, "retry clears local mechanisms")
	_check(rules.hero.action == "" and not rules.hero.get("queued_attack",false) and rules.hero.combo == 0 and rules.hero.guard_stress == 0, "retry clears attack guard combo state")
	_check(rules.hero.hp == rules.hero.max_hp and rules.hero.heals == 5, "retry fully restores upgraded health and story healing")
	_check(rules.flags.dawn and rules.flags.shortcuts.has("bridge") and rules.flags.memories.has(0), "retry retains permanent progress")
	_check(rules.enemies[0].state == "idle" and rules.enemies[0].phase == 1 and rules.enemies[0].hp == rules.enemies[0].max_hp, "retry resets enemy aggro health and phase")
	_check(rules.events.all(func(event): return event.type == "checkpoint"), "retry removes stale combat/death events")

func _test_completed_restore() -> void:
	var rules := Rules.new()
	rules.restore({"chapter":4,"segment":3,"difficulty":"adventure","flags":{"dawn":true,"rescued":true,"princess_safe":true,"dragon_defeated":true,"completed":true,"memories":[],"shortcuts":[]}})
	_check(rules.flags.completed and rules.flags.rescued, "completion and rescue restored")
	_check(rules.mode in ["epilogue", "ending"], "completed save restores post-dragon state, not mandatory rematch")
	_check(rules.enemies.all(func(enemy): return not enemy.boss or enemy.hp <= 0), "completed restore does not resurrect final boss")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)
