extends SceneTree
var entries := 0
var requested_ids: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var camera := Camera3D.new(); world.add_child(camera); camera.position = Vector3(0,8,15); camera.look_at(Vector3(0,2,0)); camera.current = true
	var mesh := MeshInstance3D.new(); mesh.name = "ClickFlower"; mesh.mesh = SphereMesh.new(); world.add_child(mesh)
	var registry = load("res://app/game_registry.gd").new()
	var catalog: Array = registry.list_games()
	var hub = load("res://hub/hub_interactions.gd").new(); world.add_child(hub); hub.session_seed = 42; hub.setup(world,camera,catalog)
	hub.portal_requested.connect(func(id): entries += 1; requested_ids.append(id))
	assert(hub.portals.size() == 3,"Expected three safe portals")
	for portal in hub.portals:
		var energy_count := 0
		var shadow_count := 0
		for part in portal.effect.get_children():
			if part is MeshInstance3D and part.material_override is ShaderMaterial:
				var shader_path: String = part.material_override.shader.resource_path
				if shader_path.ends_with("energy.gdshader"):
					assert(part.mesh is QuadMesh, "Energy was deformed into ground mesh")
					assert(part.mesh.size.y >= 3.9, "Energy height collapsed")
					energy_count += 1
				elif shader_path.ends_with("soft_shadow.gdshader"):
					assert(part.mesh is ArrayMesh, "Shadow not terrain-conformed")
					shadow_count += 1
		assert(energy_count == 3 and shadow_count == 1,"Energy/shadow surface count incorrect")
	assert(hub.pickables.has(mesh),"Mesh registered")
	assert(hub.portals[1].game_id == "bloom_skirmish", "Second portal must be bloom")
	assert(hub.portals[1].short_title == "绒芽争园", "Second portal hover title")
	for index in hub.portals[1].short_title.length():
		assert(hub.portals[1].label.font.has_char(hub.portals[1].short_title.unicode_at(index)), "Bloom title font glyph missing")
	assert(hub.portals[1].tint.is_equal_approx(Color("23dcca")), "Second portal stays teal")
	assert(hub.portals[2].game_id == "tide_gulp" and hub.portals[2].short_title == "逐潮小鱼", "Third purple portal title and route")
	assert(hub.portals[2].tint.is_equal_approx(Color("9864ff")), "Third portal stays purple")
	for index in hub.portals[2].short_title.length():
		assert(hub.portals[2].label.font.has_char(hub.portals[2].short_title.unicode_at(index)), "Tide title font glyph missing")
	hub._activate(hub.portals[0]); assert(entries == 1,"Candy portal not entered")
	hub._activate(hub.portals[1]); assert(entries == 2,"Bloom portal not entered")
	hub._activate(hub.portals[2]); assert(entries == 3,"Tide portal not entered")
	assert(requested_ids == ["gummy_bomber", "bloom_skirmish", "tide_gulp"], "Correct module IDs emitted")
	var click := InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.pressed = true; click.position = Vector2(100,100); hub._unhandled_input(click)
	var drag := InputEventMouseMotion.new(); drag.position = Vector2(125,100); hub._unhandled_input(drag)
	assert(hub.dragged,"Drag threshold failed")
	click.pressed = false; click.position = Vector2(100,100); hub._unhandled_input(click)
	assert(entries == 3,"Drag generated entry")
	for p in hub.portals:
		for other in hub.portals: other.visible = other == p
		var screen: Vector2 = camera.unproject_position(p.global_position + Vector3.UP)
		assert(hub._pick(screen) == p,"Portal pick failed")
	for p in hub.portals: p.show()
	for i in range(30): hub._play("click")
	assert(hub.voices.size() == 8,"Voice pool unbounded")
	hub.pressed = true; hub.dragged = true
	hub.suspend()
	assert(hub.suspended and not hub.visible and not hub.pressed and not hub.dragged, "Suspend did not clear interaction state")
	hub._activate(hub.portals[0]); assert(entries == 3, "Suspended portal entered")
	for voice in hub.voices: assert(not voice.playing, "Suspended SFX still playing")
	hub.suspend(); hub.resume(); hub.resume()
	assert(not hub.suspended and hub.visible, "Resume did not restore visibility")
	hub._activate(hub.portals[1]); assert(entries == 4, "Resumed bloom portal failed")
	# A future/unknown catalog entry cannot enable itself with metadata.
	var locked = load("res://hub/hub_interactions.gd").new()
	world.add_child(locked)
	var future: Dictionary = catalog[3].duplicate(true)
	future.enabled = true
	locked.setup(world, camera, [future, {"id":"unimplemented","title":"UNKNOWN","enabled":true,"color":"9864ff"}])
	for portal in locked.portals: assert(not portal.enabled, "Unimplemented metadata bypassed host allowlist")
	await process_frame
	world.queue_free(); await process_frame; await process_frame
	await create_timer(.2).timeout
	print("HUB_TEST_PASS: 3 portals, candy+bloom+tide active and future slots locked, mesh picking, drag rejection, 8 bounded voices, teardown")
	quit()
