extends SceneTree
## Real host, real modules, real Viewport input. No simulation position/time edits.
const IDS := ["gummy_bomber","bloom_skirmish","tide_gulp","beach_cleanup","volcano_escape","pelican_pedal"]
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok and failures.size()<35: failures.append(label);printerr("FAIL: ",label)
func frames(count: int = 3) -> void:
	for index in count: await process_frame
func key(code: Key, down := true) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event)
func click(point: Vector2) -> void:
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=point;root.push_input(event)
func positions(hub: Node) -> Array:
	var result: Array=[]
	for portal in hub.portals:result.append(portal.position)
	return result
func names(hub: Node) -> Array:
	var result: Array=[]
	for portal in hub.portals:result.append(portal.game_id)
	return result
func healthy_game(app: Node,id: String) -> void:
	check(is_instance_valid(app.active_game),"real game exists: "+id)
	if not is_instance_valid(app.active_game):return
	check(app.active_game.get_script().resource_path=="res://modules/"+id+"/game.gd","actual requested scene loaded: "+id)
	check(app.active_game.running,"game actually entered running state: "+id)
	check(not app.island.visible and app.hub.suspended and not app.hub_menu.visible,"island input/HUD hidden during game")
	check(not app.catalog.is_open and not app.catalog_open,"catalog not left live behind game")
	check(not app.launch_game(id) and not app.launch_game_from_catalog(id),"duplicate routes rejected while active")
	check(not app.shuffle_portals(),"in-game cannot shuffle background offers")
	if id=="pelican_pedal":
		check(app.active_game.store.allowed,"Pelican canonical save namespace accepted")
		check(app.active_game.profile.game_id==id,"Pelican profile belongs to its isolated namespace")
	if id in ["beach_cleanup","volcano_escape"]:
		check(app.active_game.context_valid,"canonical host save_root accepted: "+id)
		check(app.active_game.save_write_allowed,"valid fresh host save is writable: "+id)
func pelican_ui_exit(app: Node) -> void:
	key(KEY_ESCAPE);key(KEY_ESCAPE,false);await frames()
	check(app.active_game.paused and app.active_game.hud.menu_kind=="pause","Pelican Escape opens actual pause UI")
	var home:Button=null
	for child in app.active_game.hud.actions.get_children():
		if child is Button and child.text=="回到海岛":home=child
	check(home!=null,"Pelican pause offers genuine home button")
	if home:
		check(root.get_visible_rect().encloses(home.get_global_rect()),"Pelican exit button inside viewport")
		click(home.get_global_rect().get_center())
func run() -> void:
	root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
	var app=load("res://app/main.tscn").instantiate();root.add_child(app);await frames(5)
	check(app.registry.playable_games().size()==6,"six actually instantiated ABI-valid modules, no unfinished projects")
	for id in ["unknown","cloud_hop","fruit_gummy_snake"]:check(not app.launch_game(id),"unknown/planned route rejected: "+id)
	check(app.hub.portals.size()==4 and app.rotation.selected.size()==4,"exactly four actual offers in six-game pool")
	for button in [app.hub_menu.catalog_button,app.hub_menu.shuffle_button]:
		check(root.get_visible_rect().encloses(button.get_global_rect()),"shell menu button inside viewport and actually reachable")
	var first: Array=names(app.hub)
	check(first==app.rotation.selected,"world doors reflect saved recommendation order")
	var fixed_positions:=positions(app.hub)
	var camera_transform:Transform3D=app.island.camera.transform
	var island_id:int=app.island.get_instance_id()
	var expected_mode:int=app.island.process_mode
	var expected_mouse:int=Input.mouse_mode
	var expected_quit:bool=auto_accept_quit
	var baseline_orphans:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	# Every displayed door uses actual projected screen coordinates and actual input.
	for slot in app.hub.portals.size():
		var portal:Node3D=app.hub.portals[slot]
		var id:String=portal.game_id
		var point:Vector2=app.island.camera.unproject_position(portal.global_position+Vector3(0,1.85,0))
		check(root.get_visible_rect().has_point(point),"door center on screen")
		var clickable: Array[Vector2] = []
		for offset in [Vector3(0,1.85,0),Vector3(-.55,1,0),Vector3(.55,1,0),Vector3(-.55,2.7,0),Vector3(.55,2.7,0)]:
			var sample:Vector2=app.island.camera.unproject_position(portal.global_position+offset)
			var picked:Node3D=app.hub._pick(sample)
			if picked==portal:clickable.append(sample)
			elif picked:print("OCCLUSION actual ",id," / ",picked.get_path())
		check(not clickable.is_empty(),"actual picker exposes a usable door region despite genuine animated wildlife occlusion")
		if clickable.is_empty():continue
		click(clickable[0]);await frames()
		healthy_game(app,id)
		if is_instance_valid(app.active_game):app.active_game.leave_game()
		await frames();await create_timer(.65).timeout
		check(app.active_game==null and not app.catalog_open,"door-origin return goes to island")
		check(app.island.get_instance_id()==island_id and app.island.visible,"same live island retained")
		check(positions(app.hub)==fixed_positions and names(app.hub)==first,"game return never rerolls or moves portals")
		check(app.island.camera.transform.is_equal_approx(camera_transform),"portal return preserves camera")
		check(app.island.process_mode==expected_mode and not app.hub.suspended,"island processing restored")
		check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline_orphans,"portal return has no orphan growth")
	# Visible explicit shuffle button uses genuine GUI click, not direct model call.
	var sampled:Dictionary={}
	for id in first:sampled[id]=true
	for refresh in 18:
		var previous:Array=names(app.hub);previous.sort()
		click(app.hub_menu.shuffle_button.get_global_rect().get_center());await frames()
		var current:Array=names(app.hub);current.sort()
		for id in current:sampled[id]=true
		check(current!=previous,"visible shuffle replaces at least one actual game")
		check(positions(app.hub)==fixed_positions,"shuffle never moves world door anchors")
	check(sampled.size()==6,"all six playable games observed in actual UI shuffle sample; not universal fairness proof")
	first=names(app.hub)
	# Enter the all-games screen through its actual shell button.
	click(app.hub_menu.catalog_button.get_global_rect().get_center());await frames(5)
	check(app.catalog_open and app.catalog.is_open and app.hub.suspended,"all-games button opens blocking catalog")
	if not app.catalog_open:
		app.queue_free();await frames();await create_timer(.65).timeout
		printerr("Cannot test catalogue routes until real shell entry succeeds; stopping to avoid cascaded invalid tests")
		quit(1);return
	check(not app.hub_menu.visible and not app.island.hud.visible,"catalog owns input without leftover shell buttons")
	check(not app.launch_game(IDS[0]) and not app.shuffle_portals(),"hidden hub actions rejected while catalog owns focus")
	for cycle in IDS.size()*2:
		var id:String=IDS[cycle%IDS.size()]
		app.catalog.close_button.grab_focus()
		var tabs:=0
		while root.gui_get_focus_owner()!=app.catalog.game_buttons[id] and tabs<30:
			key(KEY_TAB);key(KEY_TAB,false);tabs+=1
		check(root.gui_get_focus_owner()==app.catalog.game_buttons[id],"real Tab navigation reaches requested module "+id)
		var before:Dictionary=app.catalog.get_navigation_state()
		key(KEY_ENTER);key(KEY_ENTER,false);await frames()
		healthy_game(app,id)
		if is_instance_valid(app.active_game):
			if id=="pelican_pedal":await pelican_ui_exit(app)
			else:app.active_game.leave_game()
		await frames(5);await create_timer(.65).timeout
		check(app.active_game==null and app.catalog_open and app.catalog.is_open,"catalog-origin game returns to same catalogue")
		check(Input.mouse_mode==expected_mouse and auto_accept_quit==expected_quit,"game return restores mouse and close policy: "+id)
		check(app.catalog.get_navigation_state()==before,"catalog return preserves filter/selection/scroll exactly")
		check(names(app.hub)==first and positions(app.hub)==fixed_positions,"catalog game return preserves offers/anchors")
		check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline_orphans,"catalog lifecycle no orphan growth")
	# Actual Volcano pause-confirm keyboard route, not exit signal substitution.
	app.catalog.game_buttons.volcano_escape.grab_focus();key(KEY_ENTER);key(KEY_ENTER,false);await frames()
	if is_instance_valid(app.active_game):
		key(KEY_ESCAPE);await frames();key(KEY_DOWN);key(KEY_DOWN);key(KEY_ENTER);await frames();key(KEY_DOWN);key(KEY_ENTER);await frames(5)
	check(app.active_game==null and app.catalog_open,"actual Volcano pause/confirm UI returns to original catalogue")
	await create_timer(.65).timeout
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==baseline_orphans,"real confirmation leaves no orphaned game")
	key(KEY_ESCAPE);await frames(5)
	check(not app.catalog_open and app.island.visible and not app.hub.suspended,"Escape returns from catalog to original island")
	check(app.island.camera.transform.is_equal_approx(camera_transform),"catalog close retains original orbit")
	check(names(app.hub)==first and positions(app.hub)==fixed_positions,"closing catalogue does not reroll")
	var saved_selection:Array=app.rotation.selected.duplicate()
	app.queue_free();await frames();await create_timer(.65).timeout
	app=load("res://app/main.tscn").instantiate();root.add_child(app);await frames(5)
	check(app.rotation.selected==saved_selection and names(app.hub)==saved_selection,"fresh host reads disk and preserves recommended games/slots")
	check(positions(app.hub)==fixed_positions,"fresh host selects same geometry anchors")
	app.queue_free();await frames();await create_timer(.65).timeout
	print("FOUR PORTAL INDEPENDENT HOST: %d checks; %s"%[checks,"PASS" if failures.is_empty() else JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
