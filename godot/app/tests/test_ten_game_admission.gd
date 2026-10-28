extends SceneTree
## Focused ten-entry host routing/navigation. Not complete gameplay or native input QA.
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
 check(ids.size()==10 and ids.slice(8)==["dawn_sword","apprentice_yokai_king"],"ten entries, hero before yokai")
 check(app.rotation.selected.size()==4,"four recommendations only")
 var unique: Dictionary = {}
 for id in app.rotation.selected:
  unique[id]=true
  check(app.registry.is_available(id),"recommended game available")
 check(unique.size()==4,"recommendations distinct")
 app.open_catalog()
 await process_frame
 check(app.catalog.game_buttons.size()==6,"page one six entries")
 var key:=InputEventKey.new();key.keycode=KEY_RIGHT;key.pressed=true
 app.catalog._input(key)
 await process_frame
 check(app.catalog.current_page==1 and app.catalog.game_buttons.size()==4,"right key reaches four-entry second page")
 key.echo=true;app.catalog._input(key)
 check(app.catalog.current_page==1,"held echo does not turn page")
 for id in ["dawn_sword","apprentice_yokai_king"]:
  app.catalog.selected_id=id
  check(app.launch_game_from_catalog(id),"launch from page two "+id)
  await process_frame
  var game: Node=app.active_game
  check(game!=null and not app.catalog.visible and app.island.process_mode==Node.PROCESS_MODE_DISABLED,"host suspended")
  check(not app.launch_game_from_catalog(id),"duplicate entry rejected")
  # Hidden catalogue must not consume gameplay navigation or mutate saved page.
  key.keycode=KEY_LEFT;key.echo=false;app.catalog._input(key)
  check(app.catalog.current_page==1,"hidden catalogue ignores game key")
  if game.has_method("request_exit"):game.request_exit()
  elif game.has_method("exit_game"):game.exit_game()
  else:game.leave_game()
  for attempt in 100:
   if not is_instance_valid(app.active_game):break
   await create_timer(.02).timeout
  await process_frame;await process_frame
  check(app.active_game==null and app.catalog_open,"exit restores catalogue")
  check(app.catalog.current_page==1 and app.catalog.selected_id==id,"exit restores page and selected game")
  check(app.catalog.game_buttons.size()==4 and app.catalog.game_buttons[id].has_focus(),"restored selection focused")
 app.close_catalog()
 for player in app.island.audio_players:player.stop();player.stream=null
 app.queue_free();await process_frame;await process_frame;await create_timer(.6).timeout
 print("TEN_GAME_ADMISSION: ","PASS" if failures.is_empty() else failures)
 quit(0 if failures.is_empty() else 1)
