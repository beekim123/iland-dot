extends Control
## Transparent portal atlas. Host keeps the real island rendering behind this overlay.
signal game_requested(game_id:String)
signal close_requested
const Cover=preload("portal_cover.gd")
const FACE=preload("catalog-sans.otf")
const PAGE_SIZE:=6
const COVERS:={"gummy_bomber":"res://hub/catalog/covers/gummy_bomber.png","bloom_skirmish":"res://hub/catalog/covers/bloom_skirmish.png","tide_gulp":"res://hub/catalog/covers/tide_gulp.png","beach_cleanup":"res://hub/catalog/covers/beach_cleanup.png","volcano_escape":"res://hub/catalog/covers/volcano_escape.png"}
var entries:Array=[]
var portal_ids:Array=[]
var current_filter:="all"
var current_page:=0
var selected_id:=""
var scroll_y:=0
var scroll:ScrollContainer
var grid:GridContainer
var header_count:Label
var status:Label
var close_button:Button
var previous_button:Button
var next_button:Button
var page_label:Label
var help_label:Label
var empty_label:Label
var filter_buttons:Dictionary={}
var game_buttons:Dictionary={}
var shell:MarginContainer
var is_open:=false
func _ready()->void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=MOUSE_FILTER_STOP
 var t:=Theme.new();t.default_font=FACE;t.default_font_size=17;theme=t
 var veil:=ColorRect.new();veil.color=Color(.015,.10,.17,.66);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.mouse_filter=MOUSE_FILTER_IGNORE;add_child(veil)
 shell=MarginContainer.new();shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(shell)
 for side in ["left","right"]:shell.add_theme_constant_override("margin_"+side,48)
 shell.add_theme_constant_override("margin_top",20);shell.add_theme_constant_override("margin_bottom",15)
 var column:=VBoxContainer.new();column.add_theme_constant_override("separation",8);shell.add_child(column)
 var top:=HBoxContainer.new();column.add_child(top)
 var titles:=VBoxContainer.new();titles.add_theme_constant_override("separation",0);titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(titles)
 titles.add_child(_label("全部小游戏",31,Color("fff5dc")))
 titles.add_child(_label("SUNNY SHELL  ·  PORTAL ATLAS",11,Color("acdcd7")))
 close_button=_button("回到海岛  ×",Color(.08,.2,.25,.55));close_button.custom_minimum_size=Vector2(155,43);close_button.pressed.connect(_request_close);top.add_child(close_button)
 var filters:=HBoxContainer.new();filters.add_theme_constant_override("separation",10);column.add_child(filters)
 for pair in [["all","全部游戏"],["ready","现在就玩"],["calm","轻松休闲"],["soon","新作筹备"]]:
  var b:=_button(pair[1],Color(.07,.18,.24,.32));b.toggle_mode=true;b.pressed.connect(_set_filter.bind(pair[0]));filters.add_child(b);filter_buttons[pair[0]]=b
 var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(spacer)
 header_count=_label("",13,Color("b3d8d2"));filters.add_child(header_count)
 scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;column.add_child(scroll)
 var content:=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(content)
 empty_label=_label("暂时没有符合条件的传送门",20,Color("d3e9e2"));empty_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;empty_label.custom_minimum_size.y=120;content.add_child(empty_label)
 grid=GridContainer.new();grid.columns=3;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",36);grid.add_theme_constant_override("v_separation",10);content.add_child(grid)
 var paging:=HBoxContainer.new();paging.alignment=BoxContainer.ALIGNMENT_CENTER;paging.add_theme_constant_override("separation",18);column.add_child(paging)
 previous_button=_button("‹  上一页",Color(.06,.16,.23,.5));previous_button.pressed.connect(_change_page.bind(-1));paging.add_child(previous_button)
 page_label=_label("1 / 1",18,Color("fff0d6"));page_label.custom_minimum_size.x=80;page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;paging.add_child(page_label)
 next_button=_button("下一页  ›",Color(.06,.16,.23,.5));next_button.pressed.connect(_change_page.bind(1));paging.add_child(next_button)
 var footer:=HBoxContainer.new();column.add_child(footer)
 status=_label("选择传送门，开始新的冒险。",13,Color("b3d8d2"));status.size_flags_horizontal=Control.SIZE_EXPAND_FILL;status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;footer.add_child(status)
 help_label=_label("← → 翻页  ·  Tab 选择  ·  Enter 进入  ·  Esc 返回",11,Color("b3d8d2"));footer.add_child(help_label)
 resized.connect(_layout);_rebuild();_layout();visible=is_open
func set_games(games:Array)->void:
 if entries==games:return
 if scroll and is_open:scroll_y=scroll.scroll_vertical
 entries=games.duplicate(true)
 if is_node_ready():_rebuild()
func setup(games:Array)->void:set_games(games)
func set_portal_games(ids:Array)->void:
 if portal_ids==ids:return
 if scroll and is_open:scroll_y=scroll.scroll_vertical
 portal_ids=ids.duplicate()
 if is_node_ready():_rebuild()
func set_status(text:String)->void:
 if status:status.text=text
func open_catalog()->void:
 is_open=true;show()
 if is_node_ready():_layout();call_deferred("_restore_focus")
func close_catalog()->void:
 if scroll:scroll_y=scroll.scroll_vertical
 is_open=false;hide()
func get_page_count()->int:
 return maxi(1,ceili(float(_filtered().size())/PAGE_SIZE))
func get_navigation_state()->Dictionary:
 return {"filter":current_filter,"page":current_page,"selected_id":selected_id,"scroll_y":scroll.scroll_vertical if scroll else scroll_y}
func restore_navigation_state(state:Dictionary)->void:
 current_filter=str(state.get("filter","all"))
 if current_filter not in ["all","ready","calm","soon"]:current_filter="all"
 current_page=clampi(int(state.get("page",0)),0,get_page_count()-1)
 selected_id=str(state.get("selected_id",""));scroll_y=maxi(0,int(state.get("scroll_y",0)))
 if is_node_ready():_rebuild();call_deferred("_restore_focus")
func _input(event:InputEvent)->void:
 if not is_open or not visible:return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_ESCAPE:
   _consume();_request_close()
  elif event.keycode in [KEY_LEFT,KEY_PAGEUP]:
   _consume();_change_page(-1)
  elif event.keycode in [KEY_RIGHT,KEY_PAGEDOWN]:
   _consume();_change_page(1)
func _unhandled_key_input(_event:InputEvent)->void:_consume_background_input()
func _unhandled_input(_event:InputEvent)->void:_consume_background_input()
func _consume()->void:
 var vp:=get_viewport()
 if vp:vp.set_input_as_handled()
func _consume_background_input()->void:
 if is_open and visible:_consume()
func _request_close()->void:
 _consume();close_catalog();close_requested.emit()
func _available(entry:Dictionary)->bool:
 return bool(entry.get("enabled",false)) and bool(entry.get("available",true)) and not str(entry.get("scene_path","")).is_empty() and ResourceLoader.exists(str(entry.get("scene_path","")))
func _set_filter(value:String)->void:
 current_filter=value;current_page=0;scroll_y=0;_rebuild();scroll.set_deferred("scroll_vertical",0)
func _matches(entry:Dictionary)->bool:
 if current_filter=="ready":return _available(entry)
 if current_filter=="soon":return not _available(entry)
 if current_filter=="calm":return str(entry.get("category","")) in ["relax","casual"] or str(entry.get("id","")) in ["tide_gulp","beach_cleanup","fruit_gummy_snake"]
 return true
func _filtered()->Array:
 var result:Array=[]
 for entry in entries:
  if entry is Dictionary and _matches(entry):result.append(entry)
 return result
func _change_page(delta:int)->void:
 _consume()
 var next_page:=clampi(current_page+delta,0,get_page_count()-1)
 if next_page==current_page:return
 current_page=next_page;scroll_y=0;_rebuild();call_deferred("_restore_focus")
func _rebuild()->void:
 if not grid:return
 for child in grid.get_children():grid.remove_child(child);child.queue_free()
 game_buttons.clear()
 var filtered:=_filtered();current_page=clampi(current_page,0,get_page_count()-1)
 var first:=current_page*PAGE_SIZE
 for i in range(first,mini(first+PAGE_SIZE,filtered.size())):_add_game(filtered[i])
 empty_label.visible=filtered.is_empty()
 header_count.text="%02d 个目的地"%filtered.size()
 page_label.text="%d / %d"%[current_page+1,get_page_count()]
 previous_button.disabled=current_page==0;next_button.disabled=current_page>=get_page_count()-1
 for key in filter_buttons:filter_buttons[key].set_pressed_no_signal(key==current_filter)
 _layout()
func _add_game(entry:Dictionary)->void:
 var id:=str(entry.get("id",""));var enabled:=_available(entry)
 var card:=VBoxContainer.new();card.add_theme_constant_override("separation",0);card.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_child(card)
 var button:=Button.new();button.custom_minimum_size=Vector2(220,200);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.disabled=not enabled;button.focus_mode=Control.FOCUS_ALL if enabled else Control.FOCUS_NONE;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
 for state in ["normal","hover","pressed","disabled","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
 card.add_child(button);game_buttons[id]=button
 var portal:=Cover.new();portal.game_id=id;portal.portal_color=entry.get("color",Color("7cceba"));portal.available=enabled
 if COVERS.has(id) and ResourceLoader.exists(COVERS[id]):portal.portrait=load(COVERS[id])
 portal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);button.add_child(portal)
 button.mouse_entered.connect(func():portal.set_emphasized(true));button.mouse_exited.connect(func():portal.set_emphasized(button.has_focus()));button.focus_entered.connect(func():selected_id=id;portal.set_emphasized(true));button.focus_exited.connect(func():portal.set_emphasized(false))
 var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",8);card.add_child(row)
 var title:=_label(str(entry.get("title",id)),19,Color("fff5dc") if enabled else Color("bccdc8"));title.custom_minimum_size=Vector2(160,28);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;row.add_child(title)
 if enabled:
  var start:=_button("进入",Color(.08,.23,.29,.42));start.custom_minimum_size=Vector2(58,29);start.add_theme_font_size_override("font_size",13);start.focus_mode=Control.FOCUS_NONE;start.pressed.connect(_activate.bind(id));row.add_child(start)
 else:row.add_child(_label(str(entry.get("status_label","未开放")),12,Color("b7c8bf")))
 var caption:=str(entry.get("description",""))
 var desc:=_label(caption,12,Color("acd0c8"));desc.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;desc.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;card.add_child(desc)
 var provenance:=_label("场景预览" if COVERS.has(id) else "主题图标",9,Color(.7,.85,.81,.7));provenance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;card.add_child(provenance)
 button.tooltip_text=str(entry.get("title",id))+" · "+("开始游戏" if enabled else str(entry.get("status_label","未开放")))
 button.pressed.connect(_activate.bind(id))
func _activate(id:String)->void:
 for entry in entries:
  if str(entry.get("id",""))==id and _available(entry):
   selected_id=id;scroll_y=scroll.scroll_vertical;_consume();game_requested.emit(id);return
func _restore_focus()->void:
 if not is_open:return
 if game_buttons.has(selected_id) and not game_buttons[selected_id].disabled:game_buttons[selected_id].grab_focus()
 else:
  var chosen:=false
  for id in game_buttons:
   if not game_buttons[id].disabled:game_buttons[id].grab_focus();chosen=true;break
  if not chosen:close_button.grab_focus()
 scroll.scroll_vertical=scroll_y
func _layout()->void:
 if not grid:return
 var w:=size.x;var margin:=20 if w<800 else 48
 header_count.visible=w>=850;help_label.visible=w>=1000
 shell.add_theme_constant_override("margin_left",margin);shell.add_theme_constant_override("margin_right",margin)
 for b in filter_buttons.values():b.custom_minimum_size.x=90 if w<800 else 112
 grid.columns=3 if w>=1050 else (2 if w>=600 else 1)
 var available_width:float=maxf(200,w-margin*2-18)
 var card_width:float=(available_width-36*(grid.columns-1))/grid.columns
 var rows:=2 if grid.columns==3 else 3
 var cover_height:=clampf((size.y-230.0)/rows-58.0,145.0,245.0)
 for card in grid.get_children():
  card.custom_minimum_size.x=card_width
  var cover:Button=card.get_child(0);cover.custom_minimum_size=Vector2(card_width,cover_height)
func _label(text:String,font_size:int,color:Color)->Label:
 var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",font_size);label.add_theme_color_override("font_color",color);label.add_theme_color_override("font_shadow_color",Color(0,.04,.08,.8));label.add_theme_constant_override("shadow_offset_y",1);return label
func _button(text:String,color:Color)->Button:
 var b:=Button.new();b.text=text;b.custom_minimum_size=Vector2(112,33);b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 for name in ["normal","hover","pressed","focus","disabled"]:
  var box:=StyleBoxFlat.new();box.bg_color=color if name=="normal" else color.lightened(.09);box.set_corner_radius_all(17);box.content_margin_left=12;box.content_margin_right=12
  if name=="focus":box.set_border_width_all(2);box.border_color=Color("a4fff1")
  if name=="disabled":box.bg_color=Color(.04,.12,.19,.15)
  b.add_theme_stylebox_override(name,box)
 for property in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:b.add_theme_color_override(property,Color("edf4df"))
 b.add_theme_color_override("font_disabled_color",Color(.6,.75,.73,.4));return b
