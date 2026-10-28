extends SceneTree
const HUD = preload("res://modules/volcano_escape/ui/rescue_hud.gd")
const SIM = preload("res://modules/volcano_escape/sim.gd")
func key(code: Key, echo := false) -> void:
	var e := InputEventKey.new(); e.keycode=code; e.pressed=true; e.echo=echo
	root.push_input(e)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sim := SIM.new(); sim.start()
	var hud := HUD.new(); root.add_child(hud)
	for viewport in [Vector2i(1280,720),Vector2i(1024,768),Vector2i(960,540),Vector2i(640,360)]:
		root.content_scale_size=viewport; root.size=viewport; hud.reset()
		var state := sim.snapshot()
		var before := var_to_str(state)
		assert(state.map.nodes.size()==12 and state.roads.size()==18 and state.shelters.size()==6 and state.exits.size()==3)
		hud.update_snapshot(state); await process_frame
		assert(not hud.map_visible)
		key(KEY_M); await process_frame; assert(hud.map_visible)
		key(KEY_M,true); assert(hud.map_visible)
		key(KEY_ESCAPE); await process_frame
		assert(hud.overlay=="pause" and hud.map_visible)
		key(KEY_M); assert(hud.map_visible)
		key(KEY_ESCAPE); await process_frame; assert(hud.overlay=="" and hud.map_visible)
		for i in 10: key(KEY_M)
		assert(hud.map_visible)
		key(KEY_M); assert(not hud.map_visible)
		# Public warning/closed/expired states render; no mutations to the input snapshot.
		state.roads[0].state="warning"; state.roads[1].state="closed"
		state.shelters[0].state="warning"; state.shelters[1].state="expired"
		state.position=Vector2.ZERO
		state.rocks[0].state="warning"; state.rocks[0].position=Vector2(3,4)
		state.rocks[1].state="warning"; state.rocks[1].position=Vector2(30,0)
		before=var_to_str(state)
		hud.update_snapshot(state); key(KEY_M); await process_frame
		assert(var_to_str(state)==before)
		var warning_text := var_to_str(hud.snapshot_data.warnings)
		assert(warning_text.contains("附近落石 · 5米"))
		assert(warning_text.contains("远处落石 · 30米"))
		assert(warning_text.contains("A站防护失效"))
		assert(not warning_text.contains("rock_") and not warning_text.contains("shelter_"))
		hud.reset(); assert(not hud.map_visible)
	hud.queue_free(); await process_frame
	print("PASS route map: actual 12-node/18-road/6-shelter/3-exit snapshot, four sizes, real M/echo/repeat/pause/resume/reentry inputs, public state overlays, no source mutation")
	quit()
