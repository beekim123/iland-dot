extends SceneTree
const Factory = preload("res://modules/gummy_bomber/art/candy_factory.gd")
func _initialize() -> void:
	for item in [Factory.make_player(),Factory.make_enemy(0),Factory.make_enemy(1),Factory.make_bomb(),Factory.make_wall(),Factory.make_crate(),Factory.make_floor(),Factory.make_pickup("range"),Factory.make_pickup("capacity"),Factory.make_pickup("speed"),Factory.make_blast()]:
		assert(item is Node3D)
		assert(item.get_child_count() > 0)
		item.free()
	print("GUMMY ART PASS: 11 factory variants instantiated")
	quit()
