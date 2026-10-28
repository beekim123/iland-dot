extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var visual = load("res://modules/monkey_vine/art/character/monkey.tscn").instantiate()
	root.add_child(visual)
	await process_frame
	check(visual.skeleton != null, "Skeleton missing")
	check(visual.skeleton.get_bone_count() == 22, "22 bones expected")
	var meshes: Array[MeshInstance3D] = []
	collect_meshes(visual, meshes)
	var skin_count := 0
	for mesh in meshes:
		if mesh.skin != null: skin_count += 1
	check(skin_count > 0, "No true Skin resource")
	var max_error := 0.0
	var clips := {}
	for clip in ["idle", "run", "grab", "swing", "air", "land", "fall"]:
		visual.play_pose(clip)
		check(not visual._key(clip).is_empty(), "Missing " + clip)
		var length: float = visual.player.get_animation(visual._key(clip)).length
		var first: Transform3D
		var delta := 0.0
		for i in range(9):
			visual.player.seek(length * float(i) / 8.0, true)
			visual.skeleton.force_update_all_bone_transforms()
			await process_frame
			var pose: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("tail3"))
			if i == 0: first = pose
			delta = maxf(delta, pose.origin.distance_to(first.origin) + (pose.basis.x - first.basis.x).length())
			if clip in ["grab", "swing"]: max_error = maxf(max_error, visual.get_grip_error())
		check(delta > 0.001, clip + " no animated bone displacement")
		clips[clip] = {"seconds": length, "bone_delta": delta}
	check(max_error < 0.001, "Grip exceeds 1 mm")
	visual.set_pose({"facing": -1, "vine_id": "test", "player_pos": Vector2(3, 4), "grip_pos": Vector2(3, 4.45)})
	visual.player.advance(0.1)
	await process_frame
	check(visual.get_grip_error() < 0.001, "Left-facing grip drift")
	root.remove_child(visual)
	visual.free()
	await process_frame
	print(JSON.stringify({"test": "monkey_skin_clips_grip_detach", "skins":skin_count, "max_grip_error_m": max_error, "clips":clips, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
func collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D: meshes.append(node)
	for child in node.get_children(): collect_meshes(child, meshes)
