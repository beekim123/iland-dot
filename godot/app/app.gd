extends Node
## Shell owns routing only. Keeping the island alive preserves its camera and layout.
const Registry = preload("res://app/game_registry.gd")
var registry := Registry.new()
var island: Node3D
var hub: Node3D
var active_game: Node
var saved_hud_visible := true
var saved_process_mode := Node.PROCESS_MODE_INHERIT
var saved_audio_paused: Array[bool] = []
var application_closing := false
var previous_auto_accept_quit := true

func _ready() -> void:
	previous_auto_accept_quit=get_tree().auto_accept_quit
	get_tree().auto_accept_quit=false
	island = preload("res://scenes/island.tscn").instantiate()
	add_child(island)
	hub = load("res://hub/hub_interactions.gd").new()
	hub.name = "HubInteractions"
	island.add_child(hub)
	hub.setup(island, island.camera, registry)
	hub.portal_requested.connect(launch_game)

func launch_game(id: String) -> bool:
	if is_instance_valid(active_game): return false
	var game := registry.find_game(id)
	if game.is_empty() or not game.enabled: return false
	if not ResourceLoader.exists(game.scene_path): return false
	var scene = load(game.scene_path) as PackedScene
	if scene == null: return false
	var candidate := scene.instantiate()
	if not candidate.has_signal("exit_requested") or not candidate.has_method("start"):
		candidate.free()
		return false
	active_game = candidate
	active_game.exit_requested.connect(return_to_island)
	saved_hud_visible = island.hud.visible
	saved_process_mode = island.process_mode
	saved_audio_paused.clear()
	hub.suspend()
	island.hide()
	island.hud.hide()
	island.dragging = false
	for player in island.audio_players:
		saved_audio_paused.append(player.stream_paused)
		player.stream_paused = true
	island.process_mode = Node.PROCESS_MODE_DISABLED
	island.camera.current = false
	add_child(active_game)
	active_game.start({"game_id":id,"save_root":"user://games/"+id+"/","schema_version":1,"quit_handler":Callable(self,"request_application_quit")})
	return true

func return_to_island() -> void:
	if not is_instance_valid(active_game): return
	# Immediately detach input/render/audio processing; destruction is safe after signal dispatch.
	active_game.process_mode = Node.PROCESS_MODE_DISABLED
	for player in active_game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
	remove_child(active_game)
	active_game.queue_free()
	active_game = null
	island.show()
	island.hud.visible = saved_hud_visible
	island.process_mode = saved_process_mode
	island.camera.make_current()
	island.dragging = false
	for i in island.audio_players.size():
		island.audio_players[i].stream_paused = saved_audio_paused[i]
	hub.resume()

func _notification(what:int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: request_application_quit()

func request_application_quit() -> void:
	if application_closing: return
	application_closing=true
	# Paused island music is still a live audio voice. Stop every owned player,
	# free all scenes, and allow the audio server to retire before exiting.
	for kind in ["AudioStreamPlayer","AudioStreamPlayer2D","AudioStreamPlayer3D"]:
		for player in find_children("*",kind,true,false): player.stop()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	set_process(false); set_process_input(false); set_process_unhandled_input(false)
	var tree:=get_tree()
	tree.create_timer(.5).timeout.connect(tree.quit)
	queue_free()

func _exit_tree() -> void:
	if get_tree(): get_tree().auto_accept_quit=previous_auto_accept_quit
