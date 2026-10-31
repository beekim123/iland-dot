extends SceneTree
## Current catalogue/portal admission; historical eleven-entry probe is preserved.
const NEW_IDS := ["tide_lantern", "moon_post", "whale_bento"]
const ORIGINAL_IDS := ["gummy_bomber", "bloom_skirmish", "tide_gulp", "beach_cleanup", "volcano_escape", "pelican_pedal", "fruit_gummy_snake", "monkey_vine", "dawn_sword", "apprentice_yokai_king", "woodland_duel"]
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
 if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func leave(app: Node) -> void:
 var game: Node = app.active_game
 if game.has_method("request_exit"):
  if game.get_script().resource_path.contains("woodland_duel"):
   game.request_exit()
   check(game.modal=="exit" and app.active_game==game,"existing card-game exit confirmation preserved")
   game.cancel_exit()
   check(game.modal=="" and game.running and app.active_game==game,"cancel keeps existing card game alive")
   game.request_exit(true)
  else: game.request_exit()
 elif game.has_method("exit_game"): game.exit_game()
 else: game.leave_game()
 for attempt in 100:
  if not is_instance_valid(app.active_game): break
  await create_timer(.02).timeout
 await process_frame; await process_frame
func run() -> void:
 var app = load("res://app/main.tscn").instantiate()
 root.add_child(app); await process_frame
 var ids: Array = []
 for entry in app.registry.list_games(): ids.append(entry.id)
 check(ids==ORIGINAL_IDS+NEW_IDS,"original order intact, three original demos appended")
 var hub_ids: Array = app.hub.IMPLEMENTED_GAME_IDS.duplicate(); hub_ids.sort()
 var registry_ids: Array = ids.duplicate(); registry_ids.sort()
 check(hub_ids==registry_ids,"hub defense allowlist matches registry")
 var font: Font=load("res://hub/catalog/catalog-sans.otf")
 for entry in app.registry.list_games():
  var text: String=entry.title+entry.description+entry.category_label
  for n in text.length(): check(font.has_char(text.unicode_at(n)),"catalogue glyph: "+text[n])
 var original_island: int = app.island.get_instance_id()
 for id in NEW_IDS:
  var forced: Array[String] = [id,"gummy_bomber","bloom_skirmish","tide_gulp"]
  app.rotation.selected=forced.duplicate(); app.hub.set_portal_entries(app._selected_entries())
  check(app.hub.portals.size()==4 and app.hub.portals[0].game_id==id,"new demo in existing four-door system")
  var door: Node3D=app.hub.portals[0]
  for n in door.short_title.length(): check(door.label.font.has_char(door.short_title.unicode_at(n)),"door title glyph: "+door.short_title[n])
  var screen: Vector2=app.island.camera.unproject_position(door.global_position+Vector3(0,1.85,0))
  for down in [true,false]:
   var click:=InputEventMouseButton.new();click.position=screen;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
   app.hub._unhandled_input(click)
  await process_frame
  check(is_instance_valid(app.active_game),"real door click launches "+id)
  if is_instance_valid(app.active_game):
   check(app.active_game.get_script().resource_path.begins_with("res://modules/"+id+"/"),"door routes correct module")
   await leave(app)
  check(app.active_game==null and app.rotation.selected==forced and app.island.get_instance_id()==original_island,"door return retains island and recommendations")
 app.open_catalog();await process_frame
 check(app.catalog.get_page_count()==ceili(float(ids.size())/app.catalog.PAGE_SIZE),"page count follows registry")
 var key:=InputEventKey.new();key.keycode=KEY_RIGHT;key.pressed=true
 for page in app.catalog.get_page_count():
  if page>0: app.catalog._input(key);await process_frame
  var expected: Array=ids.slice(page*app.catalog.PAGE_SIZE,(page+1)*app.catalog.PAGE_SIZE)
  check(app.catalog.game_buttons.keys()==expected,"page entries in registry order")
  key.echo=true;app.catalog._input(key);key.echo=false
  check(app.catalog.current_page==page,"held key does not skip page")
  for id in expected:
   app.catalog.selected_id=id
   check(app.launch_game_from_catalog(id),"catalogue launches "+id);await process_frame
   if not is_instance_valid(app.active_game): continue
   check(not app.launch_game_from_catalog(id),"repeated activation rejected")
   key.keycode=KEY_LEFT;app.catalog._input(key);key.keycode=KEY_RIGHT
   check(app.catalog.current_page==page,"hidden catalogue ignores keys")
   await leave(app)
   check(app.catalog_open and app.catalog.current_page==page and app.catalog.selected_id==id,"page and selection restored")
   check(app.catalog.game_buttons[id].has_focus(),"returned entry has keyboard focus")
 app.close_catalog()
 for player in app.island.audio_players:player.stop();player.stream=null
 app.queue_free();await process_frame;await process_frame;await create_timer(.6).timeout
 print("CURRENT_GAME_ADMISSION: ","PASS" if failures.is_empty() else failures)
 quit(0 if failures.is_empty() else 1)
