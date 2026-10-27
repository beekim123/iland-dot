extends RefCounted
const Factory = preload("res://modules/tide_gulp/art/tide_art_factory.gd")
static func make_fish(species: String, is_player: bool = false) -> Node3D:
	return Factory.new().make_fish("moonfish" if is_player else species, 0)
static func animate_fish(node: Node3D, state: Dictionary, time: float, dt: float) -> void:
	node.set_stage(int(state.get("stage", 0)))
	node.set_motion(float(state.get("speed", 0.0)), float(state.get("turn", 0.0)), float(state.get("mouth", 0.0)), float(state.get("hit", 0.0)), state.get("dash", false))
	node.tick_pose(dt, time)
static func make_chunk(chunk_data: Dictionary) -> Node3D:
	var biome: int = ["shallow", "kelp", "ruins"].find(chunk_data.get("biome", "shallow"))
	return Factory.new().make_environment(maxi(0, biome), chunk_data.get("rect", Rect2(-12,-7,24,14)), chunk_data.get("obstacles", []))
static func animate_environment(node: Node3D, time: float, current: float = 0.0) -> void:
	var path := "res://modules/tide_gulp/art/tide_environment.gd"
	if ResourceLoader.exists(path): load(path).animate_environment(node, time, current)
