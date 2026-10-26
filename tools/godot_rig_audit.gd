extends SceneTree
## Independent read-only imported-rig check. Run with --headless --path godot --script ../tools/godot_rig_audit.gd.
var failures: Array[String] = []
var report: Dictionary = {"engine": Engine.get_version_info(), "assets": [], "failures": failures}

func _initialize() -> void:
	call_deferred("run")

func require(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func snapshot(s: Skeleton3D) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for i in s.get_bone_count():
		poses.append(s.get_bone_pose(i))
	return poses

func delta(a: Transform3D, b: Transform3D) -> float:
	return a.origin.distance_to(b.origin) + a.basis.x.distance_to(b.basis.x) + a.basis.y.distance_to(b.basis.y) + a.basis.z.distance_to(b.basis.z)

func run() -> void:
	for species in ["turtle", "fish", "seagull", "crab"]:
		var path: String = "res://resources/models/%s.glb" % species
		var packed := load(path) as PackedScene
		require(packed != null, species + ": GLB load")
		if packed == null: continue
		var instance := packed.instantiate()
		root.add_child(instance)
		var skeletons := instance.find_children("*", "Skeleton3D", true, false)
		var players := instance.find_children("*", "AnimationPlayer", true, false)
		require(skeletons.size() == 1, species + ": exactly one Skeleton3D")
		require(players.size() == 1, species + ": exactly one AnimationPlayer")
		if skeletons.is_empty() or players.is_empty():
			instance.free()
			continue
		var skeleton: Skeleton3D = skeletons[0]
		var player: AnimationPlayer = players[0]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var item: Dictionary = {"species": species, "bones": skeleton.get_bone_count(), "skinned_meshes": 0, "skinned_vertices": 0, "mixed_weight_vertices": 0, "animations": []}
		for mesh: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin == null: continue
			item.skinned_meshes += 1
			require(mesh.get_node_or_null(mesh.skeleton) == skeleton, species + ": mesh skeleton resolves " + mesh.name)
			require(mesh.skin.get_bind_count() > 0, species + ": nonempty skin " + mesh.name)
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				require(arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null, species + ": vertex skin arrays " + mesh.name)
				item.skinned_vertices += arrays[Mesh.ARRAY_VERTEX].size()
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var stride: int = weights.size() / arrays[Mesh.ARRAY_VERTEX].size()
				for vertex in arrays[Mesh.ARRAY_VERTEX].size():
					var weight_sum := 0.0
					var count := 0
					for influence in stride:
						var weight := weights[vertex * stride + influence]
						weight_sum += weight
						if weight > 0.00001: count += 1
					if count > 1: item.mixed_weight_vertices += 1
					require(absf(weight_sum - 1.0) < 0.001, species + ": normalized imported vertex weights")
		require(item.skinned_meshes > 0, species + ": skinned mesh exists")
		for name in player.get_animation_list():
			if name == "RESET": continue
			var animation := player.get_animation(name)
			var clip: Dictionary = {"name": name, "duration": animation.length, "authored_start": 1.0 / 24.0, "first_key": 999.0, "last_key": 0.0, "loop_mode_before_clip_test": animation.loop_mode, "bone_tracks": 0, "changed_bones": 0, "frame_step_changed_bones": 0, "max_pose_delta": 0.0, "loop_endpoint_delta": 0.0}
			for track in animation.get_track_count():
				for key in animation.track_get_key_count(track):
					clip.first_key = minf(clip.first_key, animation.track_get_key_time(track, key))
					clip.last_key = maxf(clip.last_key, animation.track_get_key_time(track, key))
				var target := animation.track_get_path(track)
				if target.get_subname_count() > 0 and skeleton.find_bone(String(target.get_subname(0))) >= 0:
					clip.bone_tracks += 1
			player.play(name)
			player.seek(0.0, true)
			var start := snapshot(skeleton)
			player.seek(animation.length / (4.0 * 24.0), true)
			var step := snapshot(skeleton)
			player.seek(animation.length * 0.23, true)
			var middle := snapshot(skeleton)
			player.seek(clip.last_key, true)
			var end := snapshot(skeleton)
			for i in skeleton.get_bone_count():
				var moved := delta(start[i], middle[i])
				if moved > 0.000001: clip.changed_bones += 1
				if delta(start[i], step[i]) > 0.000001: clip.frame_step_changed_bones += 1
				clip.max_pose_delta = maxf(clip.max_pose_delta, moved)
				clip.loop_endpoint_delta = maxf(clip.loop_endpoint_delta, delta(start[i], end[i]))
			require(clip.bone_tracks > 0, species + ": bone tracks " + name)
			require(clip.changed_bones > 1, species + ": actual pose changes " + name)
			require(clip.frame_step_changed_bones > 0, species + ": 24fps sample changes " + name)
			require(absf(clip.last_key - clip.authored_start - 4.0) < 0.00001, species + ": 4s duration " + name)
			require(clip.loop_endpoint_delta < 0.001, species + ": loop closes " + name)
			# Test the real integration adapter, not only direct AnimationPlayer seeks.
			var adapter = load("res://scripts/bone_actor.gd")
			var rig: Dictionary = adapter.bind_actor(instance, String(name))
			adapter.sample(rig, String(name), 0.0)
			var runtime_start := snapshot(skeleton)
			adapter.sample(rig, String(name), 1.0 / 24.0)
			var runtime_next := snapshot(skeleton)
			adapter.sample(rig, String(name), 4.0)
			var runtime_loop := snapshot(skeleton)
			clip.runtime_changed_bones = 0
			clip.runtime_loop_delta = 0.0
			for i in skeleton.get_bone_count():
				if delta(runtime_start[i], runtime_next[i]) > 0.000001: clip.runtime_changed_bones += 1
				clip.runtime_loop_delta = maxf(clip.runtime_loop_delta, delta(runtime_start[i], runtime_loop[i]))
			require(clip.runtime_changed_bones > 1, species + ": actual adapter advances bone poses " + name)
			require(clip.runtime_loop_delta < 0.000001, species + ": adapter exact 4-second closure " + name)
			require(animation.loop_mode == Animation.LOOP_LINEAR, species + ": adapter enables loop " + name)
			var quarter_poses: Array = []
			for t in [0.0, 1.0, 2.0, 3.0]:
				adapter.sample(rig, String(name), t)
				quarter_poses.append(snapshot(skeleton))
			clip.quarter_pose_pair_deltas = []
			for q in range(1, 4):
				var difference := 0.0
				for i in skeleton.get_bone_count():
					difference = maxf(difference, delta(quarter_poses[q - 1][i], quarter_poses[q][i]))
				clip.quarter_pose_pair_deltas.append(difference)
			adapter.sample(rig, String(name), 4.0 - 0.0001)
			var before_wrap := snapshot(skeleton)
			adapter.sample(rig, String(name), 4.0 + 0.0001)
			var after_wrap := snapshot(skeleton)
			clip.wrap_epsilon_delta = 0.0
			for i in skeleton.get_bone_count():
				clip.wrap_epsilon_delta = maxf(clip.wrap_epsilon_delta, delta(before_wrap[i], after_wrap[i]))
			require(clip.wrap_epsilon_delta < 0.01, species + ": near-wrap continuity " + name)
			item.animations.append(clip)
		report.assets.append(item)
		instance.free()
	var world := (load("res://scenes/island.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	world.animated = false
	world.elapsed = 0.0
	world._apply_motion()
	var live_skeletons := world.find_children("*", "Skeleton3D", true, false)
	var live_start: Array = []
	for sk: Skeleton3D in live_skeletons: live_start.append(snapshot(sk))
	world.elapsed = 1.0 / 24.0
	world._apply_motion()
	var live_changed := 0
	for n in live_skeletons.size():
		var sk: Skeleton3D = live_skeletons[n]
		var moved := false
		for bone in sk.get_bone_count():
			if delta(live_start[n][bone], sk.get_bone_pose(bone)) > 0.000001: moved = true
		if moved: live_changed += 1
	var old_pivots := world.find_children("*MotionJoint*", "", true, false).size() + world.find_children("*TailPivot*", "", true, false).size() + world.find_children("*FinPivot*", "", true, false).size()
	report.runtime_scene = {"skeletons": live_skeletons.size(), "advancing_skeletons": live_changed, "old_manual_pivots": old_pivots}
	require(live_skeletons.size() == 19, "Runtime scene has3animals and16fish real skeletons")
	require(live_changed == 19, "Every runtime skeleton changes at24fps")
	require(old_pivots == 0, "No old manual animation pivots")
	world.free()
	var output := ProjectSettings.globalize_path("res://../docs/godot-rigging-audit.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("GODOT_RIG_AUDIT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
