extends SceneTree
## Independent catalogue boundary suite. Fixture rows reference a real scene;
## they test listing/navigation only, not fake gameplay or registry admission.
const Catalog=preload("res://hub/catalog/game_catalog.gd")
var checks:=0
var failures:Array[String]=[]
var requests:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok and failures.size()<45:failures.append(label);printerr("FAIL: ",label)
func frames(n:=3)->void:
 for index in n:await process_frame
func key(code:Key)->void:
 for down in [true,false]:
  var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event)
func click(point:Vector2)->void:
 for down in [true,false]:
  var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=point;event.pressed=down;root.push_input(event)
func fixtures(n:int,disabled:=false)->Array:
 var rows:Array=[]
 for index in n:
  rows.append({"id":"fixture_%02d"%index,"title":"游戏 %02d"%index,"enabled":not disabled,"scene_path":"res://modules/gummy_bomber/main.tscn","category":"action","color":Color.from_hsv(float(index)/maxi(n,1),.65,.9),"status_label":"筹备中"})
 return rows
func page(catalog:Control)->int:return int(catalog.get_navigation_state().get("page",-1))
func visible_ids(catalog:Control)->Array:
 return catalog.game_buttons.keys()
func expected_ids(n:int,p:int)->Array:
 var result:Array=[]
 for index in range(p*6,mini(n,(p+1)*6)):result.append("fixture_%02d"%index)
 return result
func run()->void:
 root.content_scale_size=Vector2i(1280,800);root.size=Vector2i(1280,800)
 for n in [0,1,6,7,12,13]:
  var catalog=Catalog.new();root.add_child(catalog);catalog.set_games(fixtures(n));catalog.open_catalog();await frames()
  catalog.game_requested.connect(func(id:String):requests.append(id))
  var pages:=maxi(1,int(ceil(float(n)/6.0)))
  check(page(catalog)==0,"initial page zero for count %d"%n)
  check(catalog.get_page_count()==pages,"page count matches ceil division and empty-state convention")
  check(catalog.previous_button.disabled,"previous is disabled on first page")
  check(catalog.next_button.disabled==(pages==1),"next is disabled exactly when no later page")
  for p in pages:
   check(page(catalog)==p,"next page is contiguous for count %d page %d"%[n,p])
   check(visible_ids(catalog)==expected_ids(n,p),"exact page membership; no skipped/duplicated card at count %d page %d"%[n,p])
   check(catalog.game_buttons.size()<=6,"never displays more than six portals on one page")
   if p<pages-1:key(KEY_PAGEDOWN);await frames()
  key(KEY_PAGEDOWN);await frames()
  check(page(catalog)==pages-1,"PageDown clamps at last page, never empty accidental extra page")
  for p in range(pages-2,-1,-1):
   key(KEY_PAGEUP);await frames();check(page(catalog)==p,"PageUp returns prior page")
  key(KEY_PAGEUP);await frames();check(page(catalog)==0,"PageUp clamps at first page")
  if pages>1:
   key(KEY_RIGHT);await frames();check(page(catalog)==1,"Right advances catalogue page")
   key(KEY_LEFT);await frames();check(page(catalog)==0,"Left returns catalogue page")
   click(catalog.next_button.get_global_rect().get_center());await frames();check(page(catalog)==1,"visible next button advances")
   click(catalog.previous_button.get_global_rect().get_center());await frames();check(page(catalog)==0,"visible previous button returns")
  check(requests.is_empty(),"navigation keys do not accidentally launch games")
  # Invalid restored page must clamp after bounds change, not show a blank page.
  catalog.restore_navigation_state({"filter":"all","selected_id":"gone","page":999,"scroll_y":0});await frames()
  check(page(catalog)==pages-1,"restore out-of-range page clamps to actual last page")
  catalog.set_games(fixtures(1));await frames()
  check(page(catalog)==0 and visible_ids(catalog)==["fixture_00"],"registry shrink clamps page and displays surviving entry")
  catalog.set_games([]);await frames()
  check(page(catalog)==0 and catalog.game_buttons.is_empty(),"empty registry has safe empty first page")
  catalog.queue_free();await frames()
 # Page state survives closing/reopening, including selected row on second page.
 var catalog=Catalog.new();root.add_child(catalog);catalog.set_games(fixtures(13));catalog.open_catalog();await frames()
 key(KEY_PAGEDOWN);await frames()
 catalog.game_buttons.fixture_08.grab_focus();await frames()
 var saved:Dictionary=catalog.get_navigation_state()
 check(saved.page==1 and saved.selected_id=="fixture_08","page and focused game recorded")
 catalog.close_catalog();catalog.open_catalog();await frames()
 check(catalog.get_navigation_state()==saved,"same catalogue resumes exact page/selected game")
 # GUI filter clicks recompute page bounds; disabled rows remain unreachable.
 var mixed:=fixtures(13)
 for i in range(3,13):mixed[i].enabled=false
 catalog.set_games(mixed);await frames()
 click(catalog.filter_buttons.ready.get_global_rect().get_center());await frames()
 check(page(catalog)==0 and catalog.game_buttons.size()==3,"filter resets/clamps from second page to available results")
 check(visible_ids(catalog)==["fixture_00","fixture_01","fixture_02"],"ready filter excludes unavailable entries")
 click(catalog.filter_buttons.soon.get_global_rect().get_center());await frames()
 check(catalog.game_buttons.size()==6 and page(catalog)==0,"unavailable filter paginates its own ten rows")
 for button in catalog.game_buttons.values():
  check(button.disabled and button.focus_mode==Control.FOCUS_NONE,"unavailable portal cannot receive playable focus")
  click(button.get_global_rect().get_center())
 check(requests.is_empty(),"clicking unavailable visible portals cannot launch")
 key(KEY_PAGEDOWN);await frames()
 check(page(catalog)==1 and catalog.game_buttons.size()==4,"last filtered page has exactly remaining four")
 catalog.set_games(fixtures(0));await frames()
 check(page(catalog)==0 and catalog.game_buttons.is_empty(),"dynamic registry clears stale filtered last page")
 catalog.queue_free();await frames()
 print("FOUR PORTAL INDEPENDENT PAGINATION: %d checks; %s"%[checks,"PASS" if failures.is_empty() else JSON.stringify(failures)])
 quit(0 if failures.is_empty() else 1)
