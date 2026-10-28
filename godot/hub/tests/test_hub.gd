extends SceneTree
var entries: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world=load("res://scenes/island.tscn").instantiate(); root.add_child(world)
	world.animated=false; world.set_process(false)
	var registry=load("res://app/game_registry.gd").new()
	var hub=load("res://hub/hub_interactions.gd").new(); world.add_child(hub)
	hub.setup(world,world.camera,registry.playable_games())
	hub.portal_requested.connect(func(id:String):entries.append(id))
	assert(hub.portals.size()==4,"Four real portals")
	for portal in hub.portals:
		assert(registry.is_available(portal.game_id),"Only playable games")
		assert(portal.effect.surfaces.size()==3 and portal.effect.motes.size()==34,"Approved rift layers retained")
		var energy_count:=0; var shadow_count:=0
		for part in portal.effect.get_children():
			if part is MeshInstance3D and part.material_override is ShaderMaterial:
				var path:String=part.material_override.shader.resource_path
				if path.ends_with("energy.gdshader"):
					assert(part.mesh is QuadMesh and part.mesh.size.y>=3.9,"Energy remains upright")
					energy_count+=1
				elif path.ends_with("soft_shadow.gdshader"):
					assert(part.mesh is ArrayMesh,"Shadow alone conforms to terrain"); shadow_count+=1
		assert(energy_count==3 and shadow_count==1)
		for code in portal.short_title.length():
			assert(portal.label.font.has_char(portal.short_title.unicode_at(code)),"Every hover title glyph present")
		hub._activate(portal)
	assert(entries.size()==4,"All current doors activate")
	var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=Vector2(100,100); hub._unhandled_input(click)
	var drag:=InputEventMouseMotion.new(); drag.position=Vector2(125,100); hub._unhandled_input(drag)
	assert(hub.dragged,"Drag detected")
	click.pressed=false; click.position=Vector2(100,100); hub._unhandled_input(click)
	assert(entries.size()==4,"Drag never launches")
	for i in 30: hub._play("click")
	assert(hub.voices.size()==8,"Bounded voice pool")
	hub.suspend(); hub._activate(hub.portals[0]); assert(entries.size()==4 and hub.suspended)
	for voice in hub.voices: assert(not voice.playing)
	hub.resume(); hub._activate(hub.portals[0]); assert(entries.size()==5)
	var fixed: Array=hub.selected_layout.duplicate()
	hub.set_portal_entries([{"id":"unimplemented","enabled":true},{"id":"future_unimplemented","enabled":true}])
	assert(hub.portals.is_empty(),"Unknown/planned entries do not become fake doors")
	hub.set_portal_entries([registry.find_game("volcano_escape")])
	assert(hub.portals.size()==1 and hub.selected_layout==fixed,"Small pool uses only one unchanged slot")
	for player in world.audio_players: player.stop(); player.stream=null
	world.queue_free(); await process_frame; await process_frame; await create_timer(.6).timeout
	print("HUB_TEST_PASS: four real assigned rifts, glyphs, bounded voices, drag rejection, suspend, small pools")
	quit()
