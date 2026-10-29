extends SceneTree
## Focused eleven-entry host routing/navigation. Not complete gameplay or native input QA.
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
 if not ok: failures.append(label); printerr("FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var app = load("res://app/main.tscn").instantiate()
 root.add_child(app)
 await process_frame
 var ids: Array = []
 for entry in app.registry.list_games(): ids.append(entry.id)
 check(ids.size()==11 and ids.slice(8)==["dawn_sword","apprentice_yokai_king","woodland_duel"],"eleven entries, original order preserved")
 var catalog_font: Font=load("res://hub/catalog/catalog-sans.otf")
 for entry in app.registry.list_games():
  var visible_text: String=entry.title+entry.description+entry.category_label
  for code in visible_text.length():
   check(catalog_font.has_char(visible_text.unicode_at(code)),"catalogue title/description glyph exists: "+visible_text[code])
 check(app.rotation.selected.size()==4,"four recommendations only")
 var unique: Dictionary = {}
 for id in app.rotation.selected:
  unique[id]=true
  check(app.registry.is_available(id),"recommended game available")
 check(unique.size()==4,"recommendations distinct")
 # Cover admission deterministically: a random initial draw might omit the new title.
 var hub_ids: Array = app.hub.IMPLEMENTED_GAME_IDS.duplicate()
 hub_ids.sort(); var registry_ids: Array = ids.duplicate(); registry_ids.sort()
 check(hub_ids==registry_ids,"hub defense allowlist matches current registry")
 var forced: Array[String] = ["woodland_duel","gummy_bomber","bloom_skirmish","tide_gulp"]
 app.rotation.selected=forced.duplicate()
 app.hub.set_portal_entries(app._selected_entries())
 check(app.hub.portals.size()==4 and app.hub.portals[0].game_id=="woodland_duel","new game occupies a real recommendation door")
 var new_door: Node3D=app.hub.portals[0]
 for code in new_door.short_title.length():
  check(new_door.label.font.has_char(new_door.short_title.unicode_at(code)),"card-game hover title glyph exists")
 var screen: Vector2=app.island.camera.unproject_position(new_door.global_position+Vector3(0,1.85,0))
 for down in [true,false]:
  var click:=InputEventMouseButton.new();click.position=screen;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down
  app.hub._unhandled_input(click)
 await process_frame
 check(is_instance_valid(app.active_game),"real new-door click enters card game")
 if is_instance_valid(app.active_game):
  check(app.active_game.get_script().resource_path=="res://modules/woodland_duel/main.gd","new-door click routed the correct module")
  app.active_game.request_exit(true)
  for attempt in 100:
   if not is_instance_valid(app.active_game):break
   await create_timer(.02).timeout
  await process_frame;await process_frame
 check(app.active_game==null and app.rotation.selected==forced and app.hub.portals.size()==4,"card-door return preserves the same four recommendations")
 app.open_catalog()
 await process_frame
 check(app.catalog.game_buttons.size()==6,"page one six entries")
 var key:=InputEventKey.new();key.keycode=KEY_RIGHT;key.pressed=true
 app.catalog._input(key)
 await process_frame
 check(app.catalog.current_page==1 and app.catalog.game_buttons.size()==5,"right key reaches five-entry second page")
 key.echo=true;app.catalog._input(key)
 check(app.catalog.current_page==1,"held echo does not turn page")
 for id in ["fruit_gummy_snake","monkey_vine","dawn_sword","apprentice_yokai_king","woodland_duel"]:
  app.catalog.selected_id=id
  check(app.launch_game_from_catalog(id),"launch from page two "+id)
  await process_frame
  var game: Node=app.active_game
  check(game!=null and not app.catalog.visible and app.island.process_mode==Node.PROCESS_MODE_DISABLED,"host suspended")
  check(not app.launch_game_from_catalog(id),"duplicate entry rejected")
  # Hidden catalogue must not consume gameplay navigation or mutate saved page.
  key.keycode=KEY_LEFT;key.echo=false;app.catalog._input(key)
  check(app.catalog.current_page==1,"hidden catalogue ignores game key")
  if id=="woodland_duel":
   game.request_exit()
   check(game.modal=="exit" and app.active_game==game,"card-game exit asks before detaching")
   game.cancel_exit()
   check(game.modal=="" and game.running and app.active_game==game,"cancel exit keeps the same game")
   game.request_exit()
   game.confirm_exit()
  elif game.has_method("request_exit"):game.request_exit()
  elif game.has_method("exit_game"):game.exit_game()
  else:game.leave_game()
  if id=="woodland_duel":
   game.request_exit(true)
   check(game.exiting,"repeated card-game exit stays idempotent")
  for attempt in 100:
   if not is_instance_valid(app.active_game):break
   await create_timer(.02).timeout
  await process_frame;await process_frame
  check(app.active_game==null and app.catalog_open,"exit restores catalogue")
  check(app.catalog.current_page==1 and app.catalog.selected_id==id,"exit restores page and selected game")
  check(app.catalog.game_buttons.size()==5 and app.catalog.game_buttons[id].has_focus(),"restored selection focused")
 app.close_catalog()
 for player in app.island.audio_players:player.stop();player.stream=null
 app.queue_free();await process_frame;await process_frame;await create_timer(.6).timeout
 print("ELEVEN_GAME_ADMISSION: ","PASS" if failures.is_empty() else failures)
 quit(0 if failures.is_empty() else 1)
