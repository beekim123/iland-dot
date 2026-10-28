extends SceneTree
const IDS=["gummy_bomber","bloom_skirmish","tide_gulp","beach_cleanup","volcano_escape","pelican_pedal","fruit_gummy_snake"]
const Rotation=preload("res://app/portal_rotation.gd")
var checks:=0
var failures:Array[String]=[]
class Probe extends Node:
 var events:=0
 func _unhandled_input(_event:InputEvent)->void:events+=1
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL: ",label)
func frames(n:=4)->void:
 for i in n:await process_frame
func key(code:Key,down:bool)->void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event)
func tap(code:Key)->void:key(code,true);key(code,false)
func click(point:Vector2)->void:
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event)
func sorted(values:Array)->Array:
 var result=values.duplicate();result.sort();return result
func run()->void:
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var sentinels:Dictionary={}
 for id in IDS.slice(0,6):
  var path="user://games/%s/profile.json"%id
  DirAccess.make_dir_recursive_absolute(path.get_base_dir())
  var f=FileAccess.open(path,FileAccess.WRITE);f.store_string("QA namespace sentinel "+id);f.close()
  sentinels[path]=FileAccess.get_file_as_bytes(path)
 var old="user://games/fruit_gummy_snake/profile.json"
 DirAccess.make_dir_recursive_absolute(old.get_base_dir())
 var oldf=FileAccess.open(old,FileAccess.WRITE);oldf.store_string("preserve legacy v1");oldf.close();sentinels[old]=FileAccess.get_file_as_bytes(old)
 var rotation=Rotation.new();rotation.rng.seed=20261028;rotation.reconcile(IDS)
 var seen:Dictionary={}
 for i in 100:
  var previous=sorted(rotation.selected)
  var offers:Array=rotation.shuffle(IDS)
  check(offers.size()==4,"seven-pool bounded four")
  var unique:Dictionary={}
  for id in offers:unique[id]=true;seen[id]=true;check(id in IDS,"only eligible seven")
  check(unique.size()==4,"seven-pool no duplicates")
  check(sorted(offers)!=previous,"refresh membership changes")
 check(seen.size()==7,"seeded sample covers seven; not universal fairness promise")
 var app=load("res://app/main.tscn").instantiate();root.add_child(app);await frames()
 check(app.registry.playable_games().size()==7,"production registry has seven actual ABI-valid playable modules")
 var actual:Array=[]
 for row in app.registry.playable_games():actual.append(row.id)
 check(sorted(actual)==sorted(IDS),"production playable membership exact")
 check(app.hub.portals.size()==4,"production world keeps four doors")
 var offers:Array=app.rotation.selected.duplicate()
 var camera:Transform3D=app.island.camera.transform
 var mode=Input.mouse_mode
 var quit_policy=auto_accept_quit
 var probe=Probe.new();root.add_child(probe)
 click(app.hub_menu.catalog_button.get_global_rect().get_center());await frames()
 tap(KEY_PAGEDOWN);await frames()
 check(app.catalog.current_page==1 and app.catalog.game_buttons.size()==1,"real second page contains one actual game")
 check(app.catalog.game_buttons.has("fruit_gummy_snake") and not app.catalog.game_buttons.fruit_gummy_snake.disabled,"actual second-page Snake is enabled")
 var orphan_baseline=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
 for mouse in [false,true]:
  app.catalog.close_button.grab_focus()
  var tabs:=0
  while root.gui_get_focus_owner()!=app.catalog.game_buttons.fruit_gummy_snake and tabs<25:
   tap(KEY_TAB);tabs+=1
  check(root.gui_get_focus_owner()==app.catalog.game_buttons.fruit_gummy_snake,"Tab reaches real page-two Snake")
  var navigation:Dictionary=app.catalog.get_navigation_state()
  probe.events=0
  if mouse:click(app.catalog.game_buttons.fruit_gummy_snake.get_global_rect().get_center())
  else:tap(KEY_ENTER)
  await frames()
  check(is_instance_valid(app.active_game),"real second-page entry starts game")
  if not is_instance_valid(app.active_game):break
  check(app.active_game.get_script().resource_path=="res://modules/fruit_gummy_snake/game.gd" and app.active_game.running,"actual new XYZ module running")
  check(probe.events==0,"catalog activation never leaks through synchronous hiding")
  check(not app.launch_game_from_catalog("fruit_gummy_snake"),"duplicate running entry rejected")
  check(app.active_game.store.allowed and app.active_game.profile.schema_version==2,"canonical host context loads writable underwater schema2")
  tap(KEY_ESCAPE);await frames()
  check(app.active_game.paused,"Escape opens genuine Snake pause")
  var button:Button=app.active_game.hud.exit_button
  check(root.get_visible_rect().encloses(button.get_global_rect()),"pause exit inside viewport")
  if mouse:click(button.get_global_rect().get_center())
  else:button.grab_focus();tap(KEY_ENTER)
  await frames()
  check(app.active_game.hud.confirmation,"first real exit input opens confirmation only")
  probe.events=0
  if mouse:click(button.get_global_rect().get_center())
  else:tap(KEY_ENTER)
  await frames();await create_timer(.7).timeout
  check(app.active_game==null and app.catalog_open,"confirmed exit returns catalogue not island")
  check(app.catalog.get_navigation_state()==navigation,"real page2/filter/selected/scroll survive game roundtrip")
  check(probe.events==0,"confirmation press/release cannot leak after synchronous unload")
  check(app.rotation.selected==offers and app.island.camera.transform.is_equal_approx(camera),"exit cannot change underlying offers/camera")
  check(Input.mouse_mode==mode and auto_accept_quit==quit_policy,"exit restores input mode and WM close policy")
  check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==orphan_baseline,"Snake UI lifecycle no orphan growth")
  var parser:=JSON.new();var path="user://games/fruit_gummy_snake/underwater_v2/profile.json"
  check(FileAccess.file_exists(path),"new underwater save exists at isolated v2 path")
  check(parser.parse(FileAccess.get_file_as_string(path))==OK and parser.data.schema_version==2,"saved profile is actual schema2")
  for other in sentinels:check(FileAccess.get_file_as_bytes(other)==sentinels[other],"unrelated/legacy namespace byte preserved: "+other)
 tap(KEY_ESCAPE);await frames()
 check(not app.catalog_open and not app.hub.suspended,"catalog Escape resumes island")
 app.queue_free();probe.queue_free();await frames();await create_timer(.7).timeout
 print("SEVEN GAME INCREMENTAL: %d checks; %s"%[checks,"PASS" if failures.is_empty() else JSON.stringify(failures)])
 quit(0 if failures.is_empty() else 1)
