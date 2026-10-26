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

func _ready() -> void:
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
	active_game.start({"game_id":id,"save_root":"user://games/"+id+"/","schema_version":1})
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
