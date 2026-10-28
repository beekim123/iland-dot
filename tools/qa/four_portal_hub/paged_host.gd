extends SceneTree
## A future-catalogue metadata fixture puts REAL existing games on page two.
## Game scenes/routing/input/simulation are unchanged; no fake wins or teleports.
const RealRegistry=preload("res://app/game_registry.gd")
class ExpandedCatalog extends "res://app/game_registry.gd":
 var base=RealRegistry.new()
 func list_games()->Array:
  var rows:Array=[]
  for index in 3:rows.append({"id":"qa_planned_%d"%index,"title":"未来入口 %d"%index,"enabled":false,"scene_path":"","color":Color("887799"),"status_label":"未开放"})
  rows.append_array(base.list_games());return rows
 func playable_games()->Array:return base.playable_games()
 func find_game(id:String)->Dictionary:return base.find_game(id)
 func mark_unavailable(id:String)->void:base.mark_unavailable(id)
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok and failures.size()<35:failures.append(label);printerr("FAIL: ",label)
func frames(n:=4)->void:
 for index in n:await process_frame
func key(code:Key,down:=true)->void:
 var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event)
func tap(code:Key)->void:key(code);key(code,false)
func click(point:Vector2)->void:
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=down;root.push_input(event)
func positions(app:Node)->Array:
 var result:Array=[]
 for portal in app.hub.portals:result.append(portal.position)
 return result
func run()->void:
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 var app=load("res://app/main.tscn").instantiate();root.add_child(app);await frames(5)
 var chosen:Array=app.rotation.selected.duplicate()
 var fixed:=positions(app)
 var camera:Transform3D=app.island.camera.transform
 var yaw:float=app.island.yaw
 var distance:float=app.island.distance
 var last_effect=app.hub.last_effect
 click(app.hub_menu.catalog_button.get_global_rect().get_center());await frames()
 check(app.catalog_open and app.catalog.get_page_count()==2,"actual seven-row catalogue opens with two pages")
 check(app.island.visible and app.hub.suspended,"transparent UI leaves actual island visible but noninteractive")
 tap(KEY_PAGEDOWN);await frames()
 check(app.catalog.current_page==1 and app.catalog.game_buttons.size()==1,"real seventh game is isolated on second page")
 for button in app.catalog.game_buttons.values():
  check(button.disabled,"actual unfinished seventh game cannot launch")
  click(button.get_global_rect().get_center())
 check(app.active_game==null,"disabled seventh gate never creates game")
 # Mouse drag, scroll and navigation are actual viewport input while transparent.
 var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=Vector2(500,400);root.push_input(press)
 var motion:=InputEventMouseMotion.new();motion.position=Vector2(700,500);motion.relative=Vector2(200,100);root.push_input(motion)
 press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=false;press.position=Vector2(700,500);root.push_input(press)
 for down in [true,false]:
  var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.position=Vector2(450,430);wheel.pressed=down;root.push_input(wheel)
 tap(KEY_LEFT);tap(KEY_RIGHT);await frames()
 check(app.island.yaw==yaw and app.island.distance==distance and app.island.camera.transform.is_equal_approx(camera),"transparent pagination/drag/wheel never rotates or zooms island behind")
 check(not app.hub.pressed and app.hub.last_effect==last_effect,"page interactions do not activate island objects")
 click(app.catalog.close_button.get_global_rect().get_center());await frames()
 check(not app.catalog_open and app.active_game==null,"actual mouse close returns only to island")
 check(not app.hub.pressed and app.hub.last_effect==last_effect,"close release does not leak into underlying island picker")
 check(app.rotation.selected==chosen and positions(app)==fixed,"catalogue browsing never changes recommendations or anchors")
 # Controlled future metadata: add three DISABLED rows before the actual registry.
 # This is necessary because today's real second page contains only an unfinished game.
 app.registry=ExpandedCatalog.new()
 click(app.hub_menu.catalog_button.get_global_rect().get_center());await frames()
 if app.catalog.current_page==0:tap(KEY_PAGEDOWN);await frames()
 check(app.catalog.current_page==1 and app.catalog.game_buttons.has("volcano_escape"),"future list places a real available game on second page")
 app.catalog.close_button.grab_focus()
 var tabs:=0
 while root.gui_get_focus_owner()!=app.catalog.game_buttons.volcano_escape and tabs<30:
  tap(KEY_TAB);tabs+=1
 check(root.gui_get_focus_owner()==app.catalog.game_buttons.volcano_escape,"Tab reaches actual game on current second page")
 var before:Dictionary=app.catalog.get_navigation_state()
 tap(KEY_ENTER);await frames()
 check(is_instance_valid(app.active_game),"second-page Enter launches real module")
 if is_instance_valid(app.active_game):
  check(app.active_game.get_script().resource_path=="res://modules/volcano_escape/game.gd","correct actual Volcano script loaded")
  check(not app.launch_game_from_catalog("volcano_escape") and not app.launch_game("beach_cleanup"),"duplicate entry is rejected during running game")
  # Genuine game pause/confirm route exits to source page.
  tap(KEY_ESCAPE);await frames();tap(KEY_DOWN);tap(KEY_DOWN);tap(KEY_ENTER);await frames();tap(KEY_DOWN);tap(KEY_ENTER);await frames(6)
 check(app.active_game==null and app.catalog_open,"game's real confirmation returns to catalogue")
 check(app.catalog.get_navigation_state()==before,"return restores second page, selected game and navigation state")
 check(app.catalog.current_page==1,"no implicit first-page reset on return")
 key(KEY_ESCAPE);await frames()
 check(not app.catalog_open and not app.hub.pressed,"Escape closes source page without activating underlying door")
 check(app.rotation.selected==chosen and positions(app)==fixed,"future metadata fixture did not mutate actual recommendations")
 app.queue_free();await frames();await create_timer(.7).timeout
 print("FOUR PORTAL INDEPENDENT PAGED HOST: %d checks; %s"%[checks,"PASS" if failures.is_empty() else JSON.stringify(failures)])
 quit(0 if failures.is_empty() else 1)
