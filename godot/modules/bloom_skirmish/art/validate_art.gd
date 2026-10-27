extends SceneTree
## Geometry/API smoke test, not subjective art or Web performance acceptance.
const Art = preload("res://modules/bloom_skirmish/art/bloom_art.gd")
var triangles: int = 0
var surfaces: int = 0
var weighted_meshes: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	for species: String in ["otter","rabbit","fox","raccoon"]:
		for team in 2:
			var actor := Art.make_animal(species,team)
			assert(actor != null,"Missing final rigged animal")
			root.add_child(actor)
			assert(actor.get_meta("skinned") == true)
			assert(actor.get_meta("visual_generation") == "cartoon-animal-skinned-v1")
			var skeleton: Skeleton3D = actor.get_meta("skeleton")
			var player: AnimationPlayer = actor.get_meta("animation_player")
			assert(skeleton.get_bone_count() >= 20)
			assert(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL)
			for clip in ["idle","run","spray","dash","hit","pod","respawn","celebration","defeat"]:
				assert(player.has_animation(clip),"Missing actual bone clip " + clip)
			for marker in ["Weapon/Muzzle","Weapon/GunGrip","Weapon/AimNozzle"]:
				assert(actor.has_node(marker),"Missing animal anchor " + marker)
			var thigh := skeleton.find_bone("Thigh.L")
			assert(thigh >= 0)
			Art.animate_gardener(actor,.1,1.0,false,false)
			var first := skeleton.get_bone_global_pose(thigh)
			Art.animate_gardener(actor,.3,1.0,false,false)
			assert(not first.is_equal_approx(skeleton.get_bone_global_pose(thigh)),"Run must deform through real bones")
			for state in [[.2,.7,true,false],[.9,1.0,true,true],[1.5,0.0,false,false]]:
				Art.animate_gardener(actor,state[0],state[1],state[2],state[3])
				var grip: Transform3D = actor.get_node("Weapon/GunGrip").global_transform
				for pitch in [-.75,0.0,.70]:
					Art.apply_gardener_aim_pitch(actor,pitch)
					var nozzle: Vector3 = actor.get_node("Weapon/Muzzle").global_position
					assert((nozzle*1.3+Vector3(0,.04,0)).distance_to(Vector3(.403,.884,-1.04)) < .00001,"Physical muzzle drift")
					assert(actor.get_node("Weapon/GunGrip").global_transform.is_equal_approx(grip),"Pitch must not pull the animal grip")
					var head := skeleton.find_bone("Head")
					var head_pose := skeleton.get_bone_pose_rotation(head)
					Art.apply_gardener_aim_pitch(actor,pitch)
					assert(head_pose.is_equal_approx(skeleton.get_bone_pose_rotation(head)),"Head aim must not accumulate")
			var paused_head := skeleton.get_bone_pose_rotation(skeleton.find_bone("Head"))
			Art.animate_gardener(actor,1.5,0.0,false,false)
			assert(paused_head.is_equal_approx(skeleton.get_bone_pose_rotation(skeleton.find_bone("Head"))),"Repeated clip+aim must not accumulate head pitch")
			Art.react_gardener(actor,"hit")
			Art.animate_gardener(actor,1.6,0.0,false,false)
			assert(actor.get_meta("animation_clip") == "hit")
			var paused := skeleton.get_bone_global_pose(thigh)
			Art.animate_gardener(actor,1.6,0.0,false,false)
			assert(paused.is_equal_approx(skeleton.get_bone_global_pose(thigh)),"Paused reaction drift")
			Art.react_gardener(actor,"respawn")
			Art.animate_gardener(actor,1.61,0.0,false,false)
			assert(actor.get_meta("animation_clip") == "respawn")
			Art.react_gardener(actor,"clear")
			assert(not actor.has_meta("reaction"))
			var weighted_before := weighted_meshes
			_check(actor)
			assert(weighted_meshes > weighted_before,"Animal must have bound skin meshes")
			actor.free()
	for team in 2:
		for kind in ["seed","bloom","pot","crate","fence","chime","flower","seed_pod"]:
			var prop: Node3D = Art.make_seed(team) if kind == "seed" else Art.make_bloom(team) if kind == "bloom" else Art.make_prop(kind,team)
			_check(prop)
			prop.free()
	print("BLOOM ART PASS: 8 skinned animal variants; 9 bone clips each; %d bound meshes; %d surfaces; %d triangles; finite normals/UV; exact muzzle; independent pitched nozzle; manual pause-safe motion." % [weighted_meshes,surfaces,triangles])
	quit()
func _check(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh
		assert(mesh != null)
		if node.skin:
			weighted_meshes += 1
			assert(node.skin.get_bind_count() > 0)
		for s in mesh.get_surface_count():
			surfaces += 1
			var data := mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
			assert(verts.size()>0 and norms.size() == verts.size())
			for v in verts: assert(v.is_finite())
			for n in norms: assert(n.is_finite() and n.length() > 0.9)
			if data[Mesh.ARRAY_COLOR] != null:
				var colors: PackedColorArray = data[Mesh.ARRAY_COLOR]
				assert(colors.is_empty() or colors.size() == verts.size())
			if data[Mesh.ARRAY_TEX_UV] != null:
				for uv: Vector2 in data[Mesh.ARRAY_TEX_UV]: assert(uv.is_finite())
			if node.skin:
				assert(data[Mesh.ARRAY_WEIGHTS] != null and not data[Mesh.ARRAY_WEIGHTS].is_empty())
				for weight: float in data[Mesh.ARRAY_WEIGHTS]: assert(is_finite(weight) and weight >= 0)
			var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
			triangles += indices.size()/3
			assert(mesh.surface_get_material(s) is StandardMaterial3D)
	for child in node.get_children(): _check(child)
