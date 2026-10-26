extends SceneTree
var failures: Array[String] = []
var report := {}
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func bounds(node: Node3D) -> AABB:
	var box := AABB()
	var started := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var b: AABB = mesh.global_transform * mesh.get_aabb()
		box = box.merge(b) if started else b
		started = true
	return box
func run() -> void:
	var packed := load("res://scenes/island.tscn") as PackedScene
	check(packed != null, "Main scene imports")
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.initialized, "Scene initialization")
	for species in ["environment", "turtle", "crab", "seagull", "tern", "dolphin"]:
		var actor := scene.get_node_or_null(species.capitalize()) as Node3D
		check(actor != null, "Required model "+species)
		if actor:
			var b := bounds(actor)
			check(b.size.length() > 0.1 and b.size.length() < 600.0, "Finite model bounds "+species)
			report[species] = {"minimum":str(b.position), "size":str(b.size), "mesh_instances":actor.find_children("*", "MeshInstance3D", true, false).size()}
	var colored_terrain := 0
	for mesh in scene.get_node("Environment").find_children("*","MeshInstance3D",true,false):
		if "terrain" in String(mesh.name).to_lower():
			check(mesh.get_meta("gltf_linear_color_encoded_for_compatibility",false), "Terrain linear to sRGB adapter")
			for surface in mesh.mesh.get_surface_count():
				var mat = mesh.get_active_material(surface)
				check(mat is StandardMaterial3D and mat.vertex_color_use_as_albedo, "Authored terrain COLOR_0 albedo enabled")
				colored_terrain += 1
	check(colored_terrain > 0, "Approved colored terrain found")
	check(scene.wildlife != null, "V4 bone wildlife module")
	check(scene.living_water != null, "V3 coast water module")
	check(scene.fish_school != null, "V4 bone fish school module")
	scene.animated = false
	scene.elapsed = 0.0
	scene._apply_motion()
	check(scene.fish_school.fish.size() == 16, "Two schools of eight authored fish")
	var fish_start: Vector3 = scene.fish_school.fish[0].body.global_position
	var turtle_start: Vector3 = scene.actors[0].global_position
	var crab_start: Vector3 = scene.actors[1].global_position
	var gull_start: Vector3 = scene.actors[2].global_position
	var tern_start: Vector3 = scene.actors[3].global_position
	var dolphin_start: Vector3 = scene.actors[4].global_position
	scene.elapsed = 4.0
	scene._apply_motion()
	check(scene.actors[0].global_position.distance_to(turtle_start) > 0.5, "Turtle genuinely swims along route")
	check(scene.actors[1].global_position.distance_to(crab_start) > 0.25, "Crab genuinely scuttles")
	check(scene.actors[2].global_position.distance_to(gull_start) > 2.0, "Gull genuinely flies along route")
	check(scene.actors[2].global_position.y > 5.0, "Gull airborne")
	check(scene.actors[3].global_position.distance_to(tern_start) > 2.0 and scene.actors[3].position.y > 5, "Second bird airborne and moving")
	check(scene.actors[4].global_position.distance_to(dolphin_start) > 1.0 and scene.actors[4].position.y < -0.1, "Dolphin swimming offshore")
	check(scene.actors[0].scale.x < 1.2 and scene.actors[1].scale.x < 1.201, "Turtle and crab reduced about 30 percent")
	check(scene.fish_school.fish[0].body.global_position.distance_to(fish_start) > 0.5, "Fish actually swim")
	check(scene.fish_school.fish[0].body.global_position.y < -0.1, "Fish below sea surface")
	check(is_equal_approx(scene.living_water.surface_material.get_shader_parameter("water_time"),4.0), "Water shader deterministic clock")
	check(scene.living_water.surface.mesh.get_surface_count() > 0, "Wave surface exists")
	check(scene.wildlife.rigs.size() == 5, "Five real wildlife armatures")
	for rig in scene.wildlife.rigs:
		check(rig.skeleton.get_bone_count() >= 10, "Real skeleton "+rig.actor.name)
		check(rig.player.get_animation_list().size() > 0, "Authored clips "+rig.actor.name)
	check(scene.fish_school.fish[0].rig.skeleton.get_bone_count() == 11, "Fish actual11bone rig")
	check(scene.find_children("*","Skeleton3D",true,false).size() == 21, "All21actors use real Skeleton3D")
	check(scene.find_children("*MotionJoint*","Node3D",true,false).is_empty(), "No obsolete synthetic mesh joints")
	report["v4_fish"] = {"count":scene.fish_school.fish.size(),"first_start":str(fish_start),"first_at_4s":str(scene.fish_school.fish[0].body.global_position)}
	report["v4_motion_samples"] = {"turtle_start":str(turtle_start),"turtle_at_4s":str(scene.actors[0].global_position),
		"crab_start":str(crab_start),"crab_at_4s":str(scene.actors[1].global_position),
		"gull_start":str(gull_start),"gull_at_4s":str(scene.actors[2].global_position)}
	scene.elapsed = 0.0
	scene._apply_motion()
	check(scene.audio_players.size() == 2, "Two audio loop resources")
	for player in scene.audio_players:
		check(absf(player.stream.get_length()-48.0)<0.01, "Audio length "+player.name)
		check(player.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Loop enabled "+player.name)
	var old_yaw: float = scene.yaw
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	scene._unhandled_input(press)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(25, 12)
	scene._unhandled_input(move)
	check(scene.yaw != old_yaw, "Drag changes orbit")
	var wheel := InputEventMouseButton.new()
	wheel.pressed = true
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	var old_distance: float = scene.distance
	scene._unhandled_input(wheel)
	check(scene.distance < old_distance, "Scroll zoom")
	scene.pitch = -100.0
	scene.distance = 1000.0
	scene._update_camera()
	check(scene.pitch >= 0.20 and scene.distance <= 49.0, "Camera clamps")
	scene.reset_view()
	check(is_equal_approx(scene.distance,30.0), "Reset view")
	scene._toggle_mute()
	check(AudioServer.is_bus_mute(0), "Mute master")
	scene._toggle_mute()
	check(not AudioServer.is_bus_mute(0), "Unmute master")
	report["failures"] = failures
	report["engine"] = Engine.get_version_info().string
	var f := FileAccess.open("res://../docs/runtime_checks.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report, "\t"))
	for player in scene.audio_players:
		player.stop()
		player.stream = null
	await create_timer(0.5).timeout
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
