extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,800)
	var scene = load("res://scenes/island.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.animated = false
	var outside: Array = []
	var minimum_margin := 10000.0
	for i in range(120):
		scene.elapsed = float(i)/12.0
		scene._apply_motion()
		scene._set_capture_camera(scene.elapsed)
		var bodies: Array = []
		if scene.elapsed < 2.0 or scene.elapsed >= 8.0:
			bodies = scene.actors.duplicate()
			for entry in scene.fish_school.fish: bodies.append(entry.body)
		elif scene.elapsed < 6.0:
			bodies = [scene.actors[0],scene.actors[1]]
			for entry in scene.fish_school.fish:
				if entry.school == 0: bodies.append(entry.body)
		else:
			bodies = [scene.actors[2]]
		for body in bodies:
			for mesh in body.find_children("*","MeshInstance3D",true,false):
				var box: AABB = mesh.get_aabb()
				for corner in range(8):
					var p: Vector3 = mesh.global_transform*box.get_endpoint(corner)
					var screen: Vector2 = scene.camera.unproject_position(p)
					var margin: float = minf(minf(screen.x,1280.0-screen.x),minf(screen.y,800.0-screen.y))
					minimum_margin = minf(minimum_margin,margin)
					if margin < 0:
						outside.append({"frame":i,"actor":String(body.name)})
						break
	var report := {"frames":120,"wide_subjects":19,"shot_selection":"wide19; swimmer+crab+leftschool10; gull1","limitation":"Mesh import bounds do not include full skeletal deformation; visual checks still required","outside_projected_mesh_bounds":outside,
		"minimum_edge_margin_px_at_1280x800":minimum_margin}
	var file := FileAccess.open("res://../docs/capture_bounds_checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	for player in scene.audio_players:
		player.stop()
		player.stream = null
	await create_timer(0.5).timeout
	scene.queue_free()
	await process_frame
	quit(0 if outside.is_empty() else 1)
