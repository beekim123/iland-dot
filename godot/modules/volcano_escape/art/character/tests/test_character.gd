extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var hero := load("res://modules/volcano_escape/art/character/otter.tscn").instantiate() as Node3D
	root.add_child(hero)
	await process_frame
	var skeleton := hero.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := hero.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(skeleton != null and player != null)
	assert(skeleton.get_bone_count() == 14)
	var meshes := hero.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 1 and meshes[0].skin != null)
	var changed := 0
	var mesh_instance := meshes[0] as MeshInstance3D
	for key in player.get_animation_list():
		if key == "RESET": continue
		player.play(key)
		player.seek(0.0, true)
		var first_vertices := deformed_vertices(mesh_instance, skeleton)
		var first: Array[Transform3D] = []
		for i in skeleton.get_bone_count(): first.append(skeleton.get_bone_pose(i))
		player.seek(player.get_animation(key).length * 0.27, true)
		var moving := 0
		for i in skeleton.get_bone_count():
			if not first[i].is_equal_approx(skeleton.get_bone_pose(i)): moving += 1
		assert(moving >= 3, str(key) + " lacks articulated motion")
		var second_vertices := deformed_vertices(mesh_instance, skeleton)
		var vertex_changes := 0
		for v in first_vertices.size():
			if first_vertices[v].distance_to(second_vertices[v]) > 0.0001: vertex_changes += 1
		assert(vertex_changes >= 100, str(key) + " no actual skin deformation")
		print("OTTER_DEFORMATION ", key, " moved_vertices=", vertex_changes)
		changed += moving
		print("OTTER_CLIP ", key, " changing_bones=", moving)
	hero.set_state("shelter")
	assert(player.current_animation.ends_with("shelter"))
	hero.set_state("idle")
	hero.set_motion(2.8, 0.1)
	assert(player.current_animation.ends_with("walk"))
	print("OTTER_SKIN_RUNTIME PASS bones=14 meshes=1 changing_bone_checks=",changed)
	quit()

func deformed_vertices(instance: MeshInstance3D, skeleton: Skeleton3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	var skin := instance.skin
	var transforms: Array[Transform3D] = []
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0: bone = skeleton.find_bone(skin.get_bind_name(i))
		assert(bone >= 0)
		transforms.append(skeleton.get_bone_global_pose(bone) * skin.get_bind_pose(i))
	for surface in instance.mesh.get_surface_count():
		var arrays := instance.mesh.surface_get_arrays(surface)
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for i in positions.size():
			var p := Vector3.ZERO
			for j in 4: p += (transforms[bones[i*4+j]] * positions[i]) * weights[i*4+j]
			result.append(p)
	return result
