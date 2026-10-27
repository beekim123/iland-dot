extends RefCounted
const Fish = preload("res://modules/tide_gulp/art/tide_fish.gd")

func make_fish(species_id: String, stage: int = 0) -> Node3D:
	var fish := Node3D.new()
	fish.set_script(Fish)
	fish.name = "Watercolor_" + species_id
	fish.setup(species_id, stage)
	return fish

func make_environment(biome: int, bounds: Rect2, obstacles: Array = []) -> Node3D:
	var script_path := "res://modules/tide_gulp/art/tide_environment.gd"
	if ResourceLoader.exists(script_path):
		var env_script = load(script_path)
		return env_script.make_environment(biome, bounds, obstacles)
	return Node3D.new()
