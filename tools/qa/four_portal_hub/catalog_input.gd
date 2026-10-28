extends SceneTree
## UI fixture only; gameplay routing is tested against actual App separately.
const Catalog = preload("res://hub/catalog/game_catalog.gd")
class UnhandledProbe extends Node:
	var events := 0
	func _unhandled_input(_event: InputEvent) -> void: events += 1
var checks := 0
var failures: Array[String] = []
var launches: Array[String] = []
var closes := 0
var handled_during_signal := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok and failures.size()<30: failures.append(label); printerr("FAIL: ",label)
func key(code: Key, down := true) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.pressed=down; root.push_input(event)
func click(point: Vector2) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new(); event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=point; root.push_input(event)
func entries() -> Array:
	var result: Array = []
	for id in ["gummy_bomber","bloom_skirmish","tide_gulp","beach_cleanup","volcano_escape"]:
		result.append({"id":id,"title":id,"enabled":true,"scene_path":"res://modules/"+id+"/main.tscn","description":"A real implemented game"})
	result.append({"id":"disabled","title":"Not ready","enabled":false,"scene_path":"res://modules/gummy_bomber/main.tscn","status_label":"重做中"})
	result.append({"id":"missing","title":"Missing scene","enabled":true,"scene_path":"res://no-such-game.tscn"})
	return result
func frames(count: int = 3) -> void:
	for index in count: await process_frame
func run() -> void:
	var probe := UnhandledProbe.new(); root.add_child(probe)
	for viewport in [Vector2i(1280,800),Vector2i(1024,768),Vector2i(800,600),Vector2i(640,480)]:
		root.content_scale_size=viewport; root.size=viewport
		var shell := Node.new(); root.add_child(shell)
		var catalog = Catalog.new(); shell.add_child(catalog)
		catalog.set_games(entries()); catalog.set_portal_games(["gummy_bomber","tide_gulp"]); catalog.open_catalog()
		await frames()
		check(catalog.game_buttons.size()==6 and catalog.get_page_count()==2, "six portals per page with seventh reachable on second page")
		check(catalog.game_buttons.disabled.disabled, "disabled resource cannot launch")
		check(catalog.game_buttons.disabled.focus_mode==Control.FOCUS_NONE, "unavailable item not keyboard launch target")
		key(KEY_PAGEDOWN);key(KEY_PAGEDOWN,false);await frames()
		check(catalog.game_buttons.size()==1 and catalog.game_buttons.missing.disabled,"missing resource is shown disabled on next page")
		key(KEY_PAGEUP);key(KEY_PAGEUP,false);await frames()
		for id in catalog.game_buttons:
			var rect: Rect2 = catalog.game_buttons[id].get_global_rect()
			check(rect.position.x>=0 and rect.end.x<=viewport.x+1, "card horizontally inside viewport: %s/%s" % [viewport,id])
			var title:Label=catalog.game_buttons[id].get_parent().get_child(1).get_child(0)
			check(not title.text.is_empty() and title.size.x>=80 and title.size.y>=20,"game title has visible allocated area, not zero-width ellipsis label")
		check(catalog.close_button.get_global_rect().end.x<=viewport.x+1, "return control remains visible")
		# Use normal GUI tab focus, not a direct _activate call.
		catalog.close_button.grab_focus()
		var tabs := 0
		while root.gui_get_focus_owner()!=catalog.game_buttons.gummy_bomber and tabs<25:
			key(KEY_TAB); tabs+=1
		check(root.gui_get_focus_owner()==catalog.game_buttons.gummy_bomber, "Tab can reach first playable card")
		catalog.game_requested.connect(func(id: String):
			handled_during_signal=root.is_input_handled(); launches.append(id); root.remove_child(shell))
		handled_during_signal=false; probe.events=0
		key(KEY_ENTER);key(KEY_ENTER,false)
		check(not shell.is_inside_tree() and launches.back()=="gummy_bomber", "Enter routes selected game and supports synchronous shell detach")
		check(handled_during_signal and probe.events==0, "Enter handled before route callback; no unhandled-host leakage")
		shell.free(); await frames()
		# Mouse release can also synchronously detach the UI owner.
		shell=Node.new(); root.add_child(shell); catalog=Catalog.new(); shell.add_child(catalog)
		catalog.set_games(entries());catalog.open_catalog();await frames()
		catalog.game_requested.connect(func(id: String):
			handled_during_signal=root.is_input_handled();launches.append(id);root.remove_child(shell))
		handled_during_signal=false;probe.events=0
		click(catalog.game_buttons.gummy_bomber.get_global_rect().get_center())
		check(not shell.is_inside_tree() and launches.back()=="gummy_bomber", "real mouse press/release routes intended card")
		check(handled_during_signal and probe.events==0,"mouse handled before synchronous routing; no host input leak")
		shell.free();await frames()
		# The visible Start label is itself a real actionable button.
		shell=Node.new();root.add_child(shell);catalog=Catalog.new();shell.add_child(catalog)
		catalog.set_games(entries());catalog.open_catalog();await frames()
		catalog.game_requested.connect(func(id: String):
			handled_during_signal=root.is_input_handled();launches.append(id);root.remove_child(shell))
		var start_button:Button=catalog.game_buttons.gummy_bomber.get_parent().get_child(1).get_child(1)
		handled_during_signal=false;probe.events=0
		click(start_button.get_global_rect().get_center())
		check(not shell.is_inside_tree() and launches.back()=="gummy_bomber", "visible Start button really launches rather than decorative text")
		check(handled_during_signal and probe.events==0, "Start button callback consumes input before detaching")
		shell.free();await frames()
		# Closed overlay must not eat future input; open Escape must not leak.
		shell=Node.new();root.add_child(shell);catalog=Catalog.new();shell.add_child(catalog)
		catalog.set_games(entries());catalog.open_catalog();await frames()
		catalog.close_requested.connect(func():handled_during_signal=root.is_input_handled();closes+=1;root.remove_child(shell))
		probe.events=0;handled_during_signal=false;key(KEY_ESCAPE)
		check(not shell.is_inside_tree() and handled_during_signal and probe.events==0,"Escape closes with no teardown error/event leakage")
		shell.free();await frames()
	# Public navigation roundtrip through a realistically long catalogue.
	root.content_scale_size=Vector2i(800,600);root.size=Vector2i(800,600)
	var catalog=Catalog.new();root.add_child(catalog)
	var many:=entries()
	for index in 15: many.append({"id":"extra_%d"%index,"title":"Extra game %d"%index,"enabled":true,"scene_path":"res://modules/gummy_bomber/main.tscn"})
	catalog.set_games(many);catalog.restore_navigation_state({"filter":"ready","page":2,"selected_id":"extra_10","scroll_y":120});catalog.open_catalog();await frames(5)
	var navigation:Dictionary=catalog.get_navigation_state()
	check(navigation.filter=="ready" and navigation.selected_id=="extra_10" and navigation.page==2 and navigation.scroll_y>=0,"filter, page and selected game are restorable with bounded per-page scroll")
	catalog.close_catalog();catalog.open_catalog();await frames(5)
	check(catalog.get_navigation_state()==navigation,"close/reopen retains complete catalogue location")
	catalog.restore_navigation_state({"filter":"invented","selected_id":"removed","scroll_y":-20});await frames()
	check(catalog.current_filter=="all" and catalog.scroll.scroll_vertical==0,"invalid navigation repaired safely")
	catalog.queue_free();probe.queue_free();await frames()
	print("FOUR PORTAL INDEPENDENT CATALOG: %d checks; %s"%[checks,"PASS" if failures.is_empty() else JSON.stringify(failures)])
	quit(0 if failures.is_empty() else 1)
