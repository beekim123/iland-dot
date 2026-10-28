extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	var app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.hub.portals.size() == 4, "Four playable magic portals placed")
	check(app.registry.playable_games().size() == 7, "All seven implemented games are available")
	for i in app.hub.portals.size():
		var portal = app.hub.portals[i]
		check(portal.tint.is_equal_approx(app.registry.find_game(portal.game_id).color), "Approved magic-rift palette")
		check(portal.enabled, "All four recommendations enabled")
		check(is_instance_valid(portal.effect) and portal.effect.surfaces.size() == 3, "Magic rift layers instantiated")
		var energy_count := 0
		var shadow_count := 0
		var array_mesh_count := 0
		for mesh in portal.effect.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh is ArrayMesh: array_mesh_count += 1
			var material = mesh.material_override as ShaderMaterial
			if material == null or material.shader == null: continue
			if material.shader.resource_path.ends_with("energy.gdshader"):
				energy_count += 1
				check(mesh.mesh is QuadMesh and mesh.mesh.get_aabb().size.y >= 3.89, "Energy remains upright QuadMesh, never terrain-conformed")
			if material.shader.resource_path.ends_with("soft_shadow.gdshader"):
				shadow_count += 1
				check(mesh.mesh is ArrayMesh, "Only ground shadow uses terrain-conformed mesh")
		check(energy_count == 3 and shadow_count == 1 and array_mesh_count == 1, "Exactly three vertical energy layers and one shadow")
		check(portal.effect.motes.size() == 34, "34 magic spark motes preserved")
		for mote in portal.effect.motes:
			check(mote.mesh is QuadMesh and mote.mesh.get_aabb().size.y > .1, "Spark quad not terrain-conformed")
	app.island.hud.beach_requested.emit()
	check(app.island.distance < 30.0, "New HUD beach button routed")
	app.island.hud.reset_requested.emit()
	check(is_equal_approx(app.island.distance, 30.0), "New HUD reset button routed")
	app.island.hud.mute_requested.emit()
	check(AudioServer.is_bus_mute(0), "New HUD mute button routed")
	app.island.hud.mute_requested.emit()
	check(not AudioServer.is_bus_mute(0), "New HUD unmute routed")
	app.island.hud.volume_changed.emit(.5)
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(.5)), "New HUD volume routed")
	app.island.animated = false
	var original = app.island.get_instance_id()
	app.island.yaw = .77
	app.island.distance = 24.0
	app.island._update_camera()
	var camera_transform: Transform3D = app.island.camera.transform
	var portal_positions: Array = []
	for portal in app.hub.portals: portal_positions.append(portal.position)
	var baseline := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for id in ["unknown", "snake", "reef_memory", "cloud_hop"]:
		check(not app.launch_game(id), "Locked route rejected: " + id)
	for cycle in 42:
		app.island.hud.visible = cycle % 2 == 0
		var expected_hud: bool = app.island.hud.visible
		var expected_audio_pause := cycle % 3 == 1
		for player in app.island.audio_players: player.stream_paused = expected_audio_pause
		app.island.dragging = true
		var game_id: String = ["gummy_bomber", "bloom_skirmish", "tide_gulp", "beach_cleanup", "volcano_escape", "pelican_pedal", "fruit_gummy_snake"][cycle % 7]
		check(app.launch_game(game_id), "Launch " + game_id + " " + str(cycle))
		if not is_instance_valid(app.active_game): continue
		check(app.active_game.get_script().resource_path.begins_with("res://modules/" + game_id + "/"), "Requested module scene actually loaded")
		check(not app.launch_game("gummy_bomber"), "Duplicate or cross-game candy launch rejected")
		check(not app.launch_game("bloom_skirmish"), "Duplicate or cross-game bloom launch rejected")
		check(not app.launch_game("tide_gulp"), "Duplicate or cross-game tide launch rejected")
		await process_frame
		check(not app.island.visible and not app.island.hud.visible, "Island and CanvasLayer hidden")
		check(app.hub.suspended and not app.hub.pressed and not app.island.dragging, "Hub gestures suspended")
		check(app.island.process_mode == Node.PROCESS_MODE_DISABLED, "Island processing disabled")
		for player in app.island.audio_players: check(player.stream_paused, "Island audio paused")
		check(app.active_game.find_children("*","WorldEnvironment",true,false).is_empty(), "Game uses camera-local environment")
		app.active_game.exit_requested.emit()
		await process_frame
		await process_frame
		check(app.active_game == null and app.get_child_count() == 3, "Game detached on exit")
		check(app.island.get_instance_id() == original, "Same island instance retained")
		check(app.island.visible and app.island.hud.visible == expected_hud, "Original HUD visibility restored")
		check(app.island.camera.current and app.island.camera.transform.is_equal_approx(camera_transform), "Original camera restored")
		check(not app.hub.suspended and not app.island.dragging, "Hub cursor/input resumed")
		for i in app.hub.portals.size(): check(app.hub.portals[i].position == portal_positions[i], "Portal placement retained")
		for player in app.island.audio_players: check(player.stream_paused == expected_audio_pause, "Island music prior pause state restored")
		check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == baseline, "No orphan growth cycle " + str(cycle))
	# Each catalogue entry uses the same real module while preserving the
	# existing catalogue node and restoring its origin on exit.
	var catalog_instance: int = app.catalog.get_instance_id()
	var chosen: Array = app.rotation.selected.duplicate()
	for game_id in ["gummy_bomber","bloom_skirmish","tide_gulp","beach_cleanup","volcano_escape","pelican_pedal","fruit_gummy_snake"]:
		app.open_catalog()
		check(app.catalog_open and app.hub.suspended and not app.hub_menu.visible, "Catalogue suspends island gestures")
		check(not app.shuffle_portals(), "Hidden refresh cannot change offered games")
		check(app.launch_game_from_catalog(game_id), "Catalogue launch " + game_id)
		await process_frame
		check(not app.catalog_open and not app.catalog.visible, "Catalogue hidden during game")
		app.active_game.exit_requested.emit()
		await process_frame; await process_frame
		check(app.catalog_open and app.catalog.visible and app.catalog.get_instance_id()==catalog_instance, "Returns to same catalogue instance")
		check(app.rotation.selected==chosen, "Entering and returning never reshuffles")
		app.close_catalog()
		check(not app.catalog_open and app.hub_menu.visible and not app.hub.suspended, "Close catalogue restores island")
	app.hub.suspend()
	for player in app.island.audio_players:
		player.stop()
		player.stream = null
	await create_timer(.5).timeout
	app.queue_free()
	await process_frame
	await process_frame
	print("APP_LIFECYCLE_42_SEVEN_GAMES: ", "PASS" if failures.is_empty() else JSON.stringify(failures))
	quit(0 if failures.is_empty() else 1)
