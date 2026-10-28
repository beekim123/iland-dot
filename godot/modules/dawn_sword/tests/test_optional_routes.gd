extends SceneTree
const Rules = preload("res://modules/dawn_sword/scripts/rules.gd")
## Each chapter starts a separate local route fixture. These are NOT a continuous
## campaign witness. Only normal movement/jump input is used after level creation.
func _initialize() -> void:
	for chapter in range(5):
		var rules = Rules.new()
		rules.load_level(chapter,0)
		var collected: bool = false
		for frame in range(1500):
			var input: Dictionary = {"move":1.0,"jump":true}
			if rules.hero.grounded and ((rules.hero.y>600 and rules.hero.x>340 and rules.hero.x<410) or (rules.hero.y<550 and rules.hero.x>610)): input.jump_pressed = true
			rules.tick(input)
			if rules.flags.memories.has(chapter):
				collected = true
				assert(rules.hero.max_hp == 110)
				print("Optional chapter ",chapter+1," reached via movement/jump after ",frame," frames")
				break
		if not collected:
			push_error("Optional high route inaccessible to this input trace in chapter "+str(chapter))
			quit(1)
			return
	print("PASS all five optional high-route life fragments via normal inputs; local chapter fixtures, not full playthrough")
	quit()
