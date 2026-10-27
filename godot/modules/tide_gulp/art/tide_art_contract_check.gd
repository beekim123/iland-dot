extends SceneTree
const Factory = preload("res://modules/tide_gulp/art/tide_art_factory.gd")
var errors: Array[String] = []
func require(condition: bool, message: String) -> void:
	if not condition: errors.append(message)
func _initialize() -> void:
	var factory := Factory.new()
	var species := ["moonfish", "silver", "fan", "leaf", "ribbon", "lantern", "parrot", "sailjaw", "whalejaw"]
	for id in species:
		var fish: Node3D = factory.make_fish(id, 0)
		root.add_child(fish)
		require(fish.skeleton != null, id + " no Skeleton3D")
		require(fish.skeleton.get_bone_count() == 8, id + " bone count")
		var skin_found := false
		for node in fish.find_children("*", "MeshInstance3D", true, false):
			if node.skin != null:
				skin_found = true
				require(node.skin.get_bind_count() >= 8, id + " missing Skin bindings")
				require(node.mesh.get_surface_count() == 1, id + " material budget")
		require(skin_found, id + " no real Skin resource")
		fish.set_motion(5.0, .4, .9, .2, true)
		fish.tick_pose(.1, 1.0)
		fish.skeleton.force_update_all_bone_transforms()
		var posed_bounds := skinned_bounds(fish)
		require(posed_bounds.size.x > posed_bounds.size.y * 1.1, id + " posed fish is not horizontal")
		require(posed_bounds.size.x < 1.8 and posed_bounds.size.y < 1.2, id + " skin exploded beyond design dimensions")
		var head_index: int = fish.skeleton.find_bone("head")
		var head_pose: Quaternion = fish.skeleton.get_bone_pose_rotation(head_index)
		var head_deviation: float = head_pose.angle_to(fish.skeleton.get_bone_rest(head_index).basis.get_rotation_quaternion())
		require(head_deviation < .2, id + " animation clobbered the imported rest orientation")
		var tail_pose: Quaternion = fish.skeleton.get_bone_pose_rotation(fish.skeleton.find_bone("tail"))
		require(not head_pose.is_equal_approx(tail_pose), id + " rigid instead of traveling pose")
		if id == "moonfish":
			var children_before := fish.get_child_count()
			for s in range(6):
				fish.set_stage(s)
				for sample in range(16):
					fish.set_motion(7.0, sin(float(sample)) * 1.3, .8, .1, true)
					fish.tick_pose(.07, float(sample) * .07)
					fish.skeleton.force_update_all_bone_transforms()
					var stage_bounds := skinned_bounds(fish)
					require(stage_bounds.size.x > stage_bounds.size.y, "growth stage %d pose %d direction" % [s, sample])
					require(stage_bounds.size.y < 1.2, "growth stage %d pose %d deformation" % [s, sample])
				require(fish.get_child_count() == children_before, "growth must reuse prepared meshes")
			print("TIDE_SKELETON_REST head=", fish.skeleton.get_bone_rest(0), " tail=", fish.skeleton.get_bone_rest(4))
		for yaw in [0.0, PI * .25, PI * .5, PI * .75, PI]:
			var requested := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 1.7), Vector3(12, 3, 0))
			fish.transform = requested
			fish.tick_pose(.016, 3.0)
			require(fish.transform.is_equal_approx(requested), id + " art changed authoritative root transform")
			require(fish.transform.basis.determinant() > 0.0, id + " mirrored turning transform")
		fish.free()
	for biome in range(3):
		var bounds := Rect2(-12,-7,24,14)
		var obstacles: Array = [Rect2(-2,-7,2,2), Rect2(4,3,2,4)]
		var env := factory.make_environment(biome,bounds,obstacles)
		root.add_child(env)
		require(env.get_child_count() > 0, "empty biome " + str(biome))
		env.free()
	print("TIDE_ART_CONTRACT: ", "PASS" if errors.is_empty() else "FAIL", " species=9 skins=9 growth_stages=6 environments=3 errors=", errors)
	quit(0 if errors.is_empty() else 1)

func skinned_bounds(fish: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node: MeshInstance3D in fish.model.find_children("*", "MeshInstance3D", true, false):
		var arrays: Array = node.mesh.surface_get_arrays(0)
		var transforms: Array[Transform3D] = []
		for binding in node.skin.get_bind_count():
			var bone: int = node.skin.get_bind_bone(binding)
			if bone < 0: bone = fish.skeleton.find_bone(node.skin.get_bind_name(binding))
			transforms.append(fish.skeleton.get_bone_global_pose(bone) * node.skin.get_bind_pose(binding))
		for i in arrays[Mesh.ARRAY_VERTEX].size():
			var point := Vector3.ZERO
			for j in range(4):
				var binding: int = arrays[Mesh.ARRAY_BONES][i * 4 + j]
				var weight: float = arrays[Mesh.ARRAY_WEIGHTS][i * 4 + j]
				point += (transforms[binding] * arrays[Mesh.ARRAY_VERTEX][i]) * weight
			require(point.is_finite(), "non-finite skinned vertex")
			if first:
				result = AABB(point, Vector3.ZERO)
				first = false
			else: result = result.expand(point)
	return result
