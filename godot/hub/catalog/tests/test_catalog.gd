extends SceneTree
const Catalog=preload("../game_catalog.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var catalog:=Catalog.new();root.add_child(catalog)
 var games:Array=[]
 for i in 7:
  games.append({"id":"game_%d"%i,"title":"游戏 %d"%i,"description":"清晰的说明","enabled":i<5,"available":i<5,"scene_path":"res://modules/gummy_bomber/main.tscn" if i<5 else "","status_label":"筹备中"})
 catalog.set_games(games);catalog.open_catalog()
 await process_frame
 check(catalog.game_buttons.size()==6 and catalog.get_page_count()==2,"six items per page with remainder retained")
 var original_button:Button=catalog.game_buttons.game_0
 catalog.set_games(games)
 check(catalog.game_buttons.game_0==original_button,"unchanged registry keeps live controls and focus")
 catalog.set_portal_games(["game_0"])
 original_button=catalog.game_buttons.game_0
 catalog.set_portal_games(["game_0"])
 check(catalog.game_buttons.game_0==original_button,"unchanged portal selection does not rebuild")
 check(catalog.game_buttons.game_5.disabled,"planned entry cannot be launched")
 var launched:Array=[]
 catalog.game_requested.connect(func(id):launched.append(id))
 catalog._change_page(1)
 check(catalog.game_buttons.size()==1 and catalog.game_buttons.has("game_6"),"seventh entry visible on second page")
 catalog._activate("game_6");check(launched.is_empty(),"disabled activation defense")
 catalog._change_page(-1)
 catalog._activate("game_0");check(launched==["game_0"],"available game routes exactly once")
 catalog._set_filter("ready");check(catalog.game_buttons.size()==5,"ready filter")
 catalog._set_filter("soon");check(catalog.game_buttons.size()==2,"planned filter")
 catalog._set_filter("all")
 for dimensions in [Vector2i(1280,800),Vector2i(960,600),Vector2i(640,480),Vector2i(1440,900)]:
  root.size=dimensions;catalog.size=Vector2(dimensions);catalog._layout()
  await process_frame;await process_frame
  check(catalog.grid.columns==(3 if dimensions.x>=1050 else 2),"responsive columns %s"%dimensions)
  check(catalog.scroll.get_global_rect().end.x<=dimensions.x+1,"scroll stays inside viewport %s"%dimensions)
  check(catalog.close_button.get_global_rect().end.x<=dimensions.x+1,"return stays inside viewport %s"%dimensions)
 catalog.selected_id="game_3";catalog.scroll.scroll_vertical=95
 var state:Dictionary=catalog.get_navigation_state()
 catalog.close_catalog();catalog.open_catalog()
 await process_frame
 check(catalog.selected_id=="game_3","selection preserved across game return")
 catalog.restore_navigation_state(state)
 await process_frame
 check(catalog.get_navigation_state().filter==state.filter,"filter restored")
 catalog._change_page(1)
 state=catalog.get_navigation_state()
 catalog.close_catalog();catalog.open_catalog()
 await process_frame
 check(catalog.current_page==1,"page survives close and reopen")
 catalog._set_filter("ready")
 check(catalog.current_page==0 and catalog.get_page_count()==1,"filter resets and clamps pages")
 catalog.restore_navigation_state({"filter":"all","selected_id":"game_0","scroll_y":0})
 check(catalog.current_page==0,"legacy navigation defaults to page zero")
 catalog.set_games([])
 check(catalog.get_page_count()==1 and catalog.current_page==0 and catalog.empty_label.visible,"empty pool has stable empty page")
 var closed:Array=[]
 catalog.close_requested.connect(func():closed.append(true);root.remove_child(catalog))
 catalog._request_close()
 check(closed.size()==1 and not catalog.is_inside_tree(),"synchronous detach during close is safe")
 catalog.free()
 print("CATALOG QA %d checks, %d failures"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
