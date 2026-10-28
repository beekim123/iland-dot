extends SceneTree
const Rules = preload("res://modules/dawn_sword/scripts/rules.gd")
func _initialize() -> void:
	var rules = Rules.new()
	assert(rules.level.name == "火焰划开的庆典")
	for i in range(60): rules.tick({"move":1.0})
	assert(rules.hero.x>400)
	rules.tick({"jump_pressed":true,"jump":true})
	assert(rules.hero.vy<0)
	for i in range(60): rules.tick({})
	assert(rules.hero.grounded)
	for c in range(5):
		for s in range(4):
			var level: Dictionary = Rules.Campaign.level(c,s)
			assert(level.width>=1800 and not level.enemies.is_empty())
	print("PASS basic rules, authored 20 sections, movement/jump; not a full campaign playthrough")
	quit()
