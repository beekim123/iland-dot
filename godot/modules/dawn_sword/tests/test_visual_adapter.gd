extends SceneTree
const Game = preload("res://modules/dawn_sword/scripts/game.gd")
## Presentation-only fixtures: no combat/progression modification or clear claims.
func _initialize() -> void:
	var game = Game.new()
	game.manifest = {"actors":{}}
	var cases: Array = [["axe_lord","jump_slam",1,2],["bridge_guard","shockwave",1,2],["rock_lizard","charge",1,1],["ash_knight","heavy_slash",2,1],["dragon","pounce",3,1]]
	for sample in cases:
		game.manifest.actors[sample[0]] = {"animations":{sample[1]:{},"attack":{},"land":{}}}
		var actor: Dictionary = {"id":0,"kind":sample[0],"animation":"attack","state":"attack","phase":sample[2],"attack_count":sample[3],"anim_time":0.2}
		assert(game._enemy_visual(actor).name == sample[1])
	game.landing_visual_times[0] = 0.25
	assert(game._enemy_visual({"id":0,"kind":"dragon","animation":"stagger","state":"stagger","phase":2,"attack_count":2,"anim_time":0.1}).name == "land")
	game.keys.interact = KEY_R
	game.keys.heal = KEY_Q
	assert(game._hint("interact") == "R" and game._hint("heal") == "Q")
	game.last_device = "gamepad"
	assert(game._hint("interact") == "右肩")
	game.free()
	print("PASS presentation-only special attack/landing selection and dynamic keyboard/gamepad hints")
	quit()
