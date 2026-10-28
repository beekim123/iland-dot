extends Node
## The shell owns routing and recommendations only. All game profiles remain isolated.
const Registry = preload("res://app/game_registry.gd")
const Rotation = preload("res://app/portal_rotation.gd")
var registry := Registry.new()
var rotation := Rotation.new()
var island: Node3D
var hub: Node3D
var active_game: Node
var catalog: Control
var catalog_layer: CanvasLayer
var hub_menu: CanvasLayer
var catalog_open := false
var return_destination := "island"
var saved_hud_visible := true
var saved_process_mode := Node.PROCESS_MODE_INHERIT
var saved_audio_paused: Array[bool] = []
var _island_suspended := false
var application_closing := false
var previous_auto_accept_quit := true

func _ready() -> void:
	previous_auto_accept_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	island = preload("res://scenes/island.tscn").instantiate()
	add_child(island)
	rotation.load_profile()
	rotation.reconcile(registry.playable_games())
	rotation.save_profile()
	hub = load("res://hub/hub_interactions.gd").new()
	hub.name = "HubInteractions"
	island.add_child(hub)
	hub.setup(island,island.camera,_selected_entries())
	hub.portal_requested.connect(launch_game)
	hub_menu = load("res://hub/ui/hub_menu.gd").new()
	add_child(hub_menu)
	hub_menu.catalog_requested.connect(open_catalog)
	hub_menu.shuffle_requested.connect(shuffle_portals)
	catalog_layer = CanvasLayer.new(); catalog_layer.name = "GameCatalogLayer"; catalog_layer.layer = 30
	add_child(catalog_layer)
	catalog = load("res://hub/catalog/game_catalog.gd").new()
	catalog_layer.add_child(catalog)
	catalog.set_games(registry.list_games())
	catalog.game_requested.connect(launch_game_from_catalog)
	catalog.close_requested.connect(close_catalog)
	catalog.close_catalog()
	_update_shell_status()

func _selected_entries() -> Array:
	var entries: Array = []
	for id in rotation.selected:
		var game := registry.find_game(id)
		if not game.is_empty() and game.enabled: entries.append(game)
	return entries

func shuffle_portals() -> bool:
	if is_instance_valid(active_game) or catalog_open or application_closing: return false
	var pool := registry.playable_games()
	if pool.size() <= 4: return false
	rotation.shuffle(pool)
	rotation.save_profile()
	hub.set_portal_entries(_selected_entries())
	_update_shell_status()
	return true

func _update_shell_status() -> void:
	if is_instance_valid(hub_menu):
		hub_menu.set_status(rotation.status)
		hub_menu.set_shuffle_enabled(registry.playable_games().size()>4)
	if is_instance_valid(catalog):
		catalog.set_portal_games(rotation.selected)
		catalog.set_status(rotation.status)

func open_catalog() -> void:
	if is_instance_valid(active_game) or catalog_open or application_closing: return
	_suspend_island()
	catalog_open = true
	hub_menu.hide()
	catalog.set_games(registry.list_games())
	catalog.set_portal_games(rotation.selected)
	catalog.open_catalog()

func close_catalog() -> void:
	if not catalog_open or is_instance_valid(active_game): return
	catalog.close_catalog()
	catalog_open = false
	_restore_island()
	hub_menu.show()
	# No reallocation or reselection: the same four doors and orbit survive.

func launch_game_from_catalog(id: String) -> bool:
	if not catalog_open: return false
	return _launch(id,"catalog")

func launch_game(id: String) -> bool:
	if catalog_open: return false
	return _launch(id,"island")

func _launch(id: String, source: String) -> bool:
	if is_instance_valid(active_game) or application_closing: return false
	var game := registry.find_game(id)
	if game.is_empty() or not game.enabled: return false
	if not ResourceLoader.exists(game.scene_path):
		_remove_unavailable(id); return false
	var scene := ResourceLoader.load(game.scene_path) as PackedScene
	if scene == null or not scene.can_instantiate():
		_remove_unavailable(id); return false
	var candidate := scene.instantiate()
	if candidate == null or not candidate.has_signal("exit_requested") or not candidate.has_method("start"):
		if candidate != null: candidate.free()
		_remove_unavailable(id); return false
	return_destination = source
	active_game = candidate
	active_game.exit_requested.connect(return_to_island)
	_suspend_island()
	island.hide()
	if catalog_open: catalog.close_catalog()
	catalog_open = false
	hub_menu.hide()
	island.camera.current = false
	add_child(active_game)
	active_game.start({"game_id":id,"save_root":"user://games/"+id+"/","schema_version":1,"quit_handler":Callable(self,"request_application_quit")})
	return true

func _remove_unavailable(id: String) -> void:
	registry.mark_unavailable(id)
	rotation.reconcile(registry.playable_games()); rotation.save_profile()
	hub.set_portal_entries(_selected_entries())
	catalog.set_games(registry.list_games()); _update_shell_status()
	catalog.set_status("这个游戏暂不可用，已从传送门移除")

func _suspend_island() -> void:
	if _island_suspended: return
	_island_suspended = true
	saved_hud_visible = island.hud.visible
	saved_process_mode = island.process_mode
	saved_audio_paused.clear()
	hub.suspend()
	island.hud.hide()
	island.dragging = false
	for player in island.audio_players:
		saved_audio_paused.append(player.stream_paused)
		player.stream_paused = true
	island.process_mode = Node.PROCESS_MODE_DISABLED

func _restore_island() -> void:
	if not _island_suspended: return
	_island_suspended = false
	island.show()
	island.hud.visible = saved_hud_visible
	island.process_mode = saved_process_mode
	island.camera.make_current()
	island.dragging = false
	for i in island.audio_players.size():
		island.audio_players[i].stream_paused = saved_audio_paused[i]
	hub.resume()

func return_to_island() -> void:
	if not is_instance_valid(active_game): return
	# Detach immediately, free after signal dispatch. Callers must consume their
	# input BEFORE emitting exit_requested; they cannot access a detached viewport.
	active_game.process_mode = Node.PROCESS_MODE_DISABLED
	for kind in ["AudioStreamPlayer","AudioStreamPlayer2D","AudioStreamPlayer3D"]:
		for player in active_game.find_children("*",kind,true,false): player.stop()
	remove_child(active_game)
	active_game.queue_free()
	active_game = null
	_restore_island()
	hub_menu.show()
	if return_destination == "catalog": open_catalog()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: request_application_quit()

func request_application_quit() -> void:
	if application_closing: return
	application_closing = true
	for kind in ["AudioStreamPlayer","AudioStreamPlayer2D","AudioStreamPlayer3D"]:
		for player in find_children("*",kind,true,false): player.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(false); set_process_input(false); set_process_unhandled_input(false)
	var tree := get_tree()
	tree.create_timer(.5).timeout.connect(tree.quit)
	queue_free()

func _exit_tree() -> void:
	if get_tree(): get_tree().auto_accept_quit = previous_auto_accept_quit
