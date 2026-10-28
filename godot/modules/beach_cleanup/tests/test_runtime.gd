extends SceneTree
const Witness = preload("../data/witness.gd")
var failures: Array[String] = []
class Store extends RefCounted:
	var value: Variant = null
	func load_game(_id: String) -> Variant: return value
	func save_game(_id: String, data: Dictionary) -> void: value = data.duplicate(true)
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message); push_error(message)
func run() -> void:
	var original := auto_accept_quit
	var game = load("res://modules/beach_cleanup/main.tscn").instantiate()
	root.add_child(game)
	var store := Store.new()
	game.start({"save_service":store})
	game.set_process(false)
	check(game.running and not auto_accept_quit,"entry owns native close policy")
	check(game.trash_nodes.size() == 24 and game.sim.remaining.size() == 24,"full first map has 24 art-backed items")
	check(game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL,"true miniature 3D orthographic camera")
	check(game.camera.size == 16 and game.postcard_camera.size == 32,"readable follow camera separate from fixed postcard camera")
	game.grabbing = true
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false
	game._input(release)
	check(not game.grabbing,"global release clears gripper even over consumed UI")
	var before: Dictionary = game.sim.snapshot()
	game.set_paused(true)
	game.sim.command({"move":Vector2.ONE,"grab":true})
	game.sim.tick(1)
	check(game.sim.snapshot() == before,"pause freezes rules and clears held inputs")
	game.hud.handle_escape()
	check(not game.paused,"Esc resumes pause")
	check(Witness.collect_one(game.sim,game.sim.remaining[0]),"ordinary commands collect first item")
	game._update_presentation(0)
	check(not game.trash_nodes[game.sim.cargo[0]].visible,"collected model leaves ground")
	game.show_hint()
	check(game.hint_marker.visible,"optional residue marker points to actual remaining item")
	game.set_paused(true)
	game.hud._confirm("replay")
	game.hud.handle_escape()
	check(game.sim.cargo.size() == 1 and game.hud.modal_kind == "pause","cancel replay preserves cargo")
	game.set_paused(false)
	while not game.sim.remaining.is_empty():
		if not Witness.collect_one(game.sim,game.sim.nearest_hint().id):
			check(false,"ordinary commands collect final ground item")
			break
	check(game.sim.remaining.is_empty() and not game.sim.cargo.is_empty() and game.sim.phase == "cleaning","empty ground with final cargo remains unfinished")
	game._update_presentation(0)
	game.show_hint()
	var depot: Dictionary = game.sim.map_data.depots[0]
	check(game.hint_marker.visible and Vector2(game.hint_marker.position.x,game.hint_marker.position.z).is_equal_approx(depot.pos),"final-load hint points to real depot rather than empty trash set")
	check(game.hud.prompt.text.contains("卸") and not game.hud.prompt.text.contains("夹取"),"empty-ground HUD guides final unloading")
	game.save_data()
	game.start({"save_service":store}); game.set_process(false)
	game.show_hint()
	check(game.sim.remaining.is_empty() and game.hint_marker.visible and game.sim.phase == "cleaning","final-load hint survives saved boundary reentry")
	check(Witness.unload(game.sim) and game.sim.phase == "complete","ordinary final unload completes map")
	# A valid final-load snapshot fixture checks both real depots on map 3.
	var live_sim = game.sim
	var dual = preload("../sim.gd").new()
	dual.start(2,0)
	var final_load: Dictionary = dual.snapshot()
	final_load.cargo = [final_load.remaining.pop_back()]
	final_load.delivered = final_load.remaining.duplicate()
	final_load.remaining = []
	final_load.restored_zones = []
	for zone: Dictionary in dual.map_data.zones: final_load.restored_zones.append(zone.id)
	game.sim = dual
	for stop: Dictionary in dual.map_data.depots:
		final_load.pos = [stop.pos.x,stop.pos.y]
		check(dual.restore(final_load),"valid final-load dual-depot fixture")
		check(game._hint_target().id == stop.id,"final-load hint chooses nearest actual dual-bay depot")
	game.sim = live_sim
	game._record_result(); game._record_result()
	check(game.profile.results.size() == 1,"completion recorded exactly once")
	game._update_presentation(0)
	game._finish_postcard()
	check(game.hud.modal_kind == "completion","real completion opens postcard")
	game.set_paused(true)
	check(game.hud.modal_kind == "completion","focus/pause cannot discard earned postcard")
	game.next_beach()
	check(game.sim.map_id == 1 and game.sim.remaining.size() == 30,"next map directly enters 30-item beach")
	game.replay()
	check(game.sim.variant == 1 and game.profile.results.size() == 1,"confirmed replay advances bounded variant without duplicating records")
	var exits := [0]
	game.exit_requested.connect(func(): exits[0] += 1)
	game.leave_game(); game.leave_game()
	check(exits[0] == 1 and auto_accept_quit == original,"normal return emits once and restores native close policy")
	var retired: WeakRef = game.retired_audio
	await create_timer(0.5).timeout
	check(retired.get_ref() == null,"audio retires within bounded window even after detach")
	game.hud._completion = {"stale":true}
	game.hud.show_pause()
	game.start({"save_service":store}); game.set_process(false)
	check(game.hud._completion.is_empty() and game.hud.modal_kind.is_empty(),"reentry clears stale modal/result state")
	check(is_instance_valid(game.audio) and game.running,"same-node reentry creates fresh audio after retirement")
	var called := [0]
	game.quit_handler = func(): called[0] += 1
	game.request_application_quit(); game.request_application_quit()
	check(called[0] == 1 and not auto_accept_quit,"native close is idempotent and stays suppressed while pending")
	game.queue_free()
	await process_frame
	check(not auto_accept_quit,"exit_tree must not restore auto_accept_quit during pending shutdown")
	await create_timer(0.6).timeout
	auto_accept_quit = original
	print("BEACH RUNTIME ","PASS" if failures.is_empty() else "FAIL", " lifecycle, controls, confirmations, full-command completion, retirement")
	quit(0 if failures.is_empty() else 1)
