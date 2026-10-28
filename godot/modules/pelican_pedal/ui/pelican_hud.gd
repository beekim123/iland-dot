extends Control
signal pause_requested
signal resume_requested
signal next_requested
signal retry_requested
signal home_requested
signal comfort_changed(value: bool)
var game
var menu: PanelContainer
var menu_title: Label
var menu_info: Label
var actions: VBoxContainer
var warning: Label
var menu_kind := ""
var font: Font
var paused_button: Button
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); size=Vector2(1280,800); mouse_filter=MOUSE_FILTER_IGNORE
	if ResourceLoader.exists("res://modules/pelican_pedal/ui/pelican-sans.otf"): font=load("res://modules/pelican_pedal/ui/pelican-sans.otf")
	else: font=ThemeDB.fallback_font
	add_theme_font_override("font",font)
	paused_button=Button.new(); paused_button.text="暂停 Ⅱ"; paused_button.position=Vector2(1110,22); paused_button.size=Vector2(140,45); add_child(paused_button); paused_button.pressed.connect(func():pause_requested.emit())
	menu=PanelContainer.new(); menu.custom_minimum_size=Vector2(440,360); add_child(menu); menu.hide()
	var style:=StyleBoxFlat.new(); style.bg_color=Color("fcf0d9"); style.corner_radius_top_left=22;style.corner_radius_top_right=22;style.corner_radius_bottom_left=22;style.corner_radius_bottom_right=22;style.content_margin_left=28;style.content_margin_right=28;style.content_margin_top=24;style.content_margin_bottom=24;menu.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",14);menu.add_child(column)
	menu_title=Label.new();menu_title.add_theme_font_size_override("font_size",30);menu_title.add_theme_color_override("font_color",Color("244d60"));column.add_child(menu_title)
	menu_info=Label.new();menu_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;menu_info.custom_minimum_size.x=384;menu_info.add_theme_color_override("font_color",Color("426575"));column.add_child(menu_info)
	actions=VBoxContainer.new();actions.add_theme_constant_override("separation",10);column.add_child(actions)
	warning=Label.new(); warning.z_index=100;warning.add_theme_color_override("font_color",Color("fff2d5")); warning.add_theme_color_override("font_shadow_color",Color("352c35"));warning.add_theme_constant_override("shadow_offset_x",2);warning.add_theme_constant_override("shadow_offset_y",2);warning.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;warning.mouse_filter=MOUSE_FILTER_IGNORE;add_child(warning)
func _process(_dt: float) -> void:
	var view_size:=get_viewport_rect().size
	var factor:=minf(view_size.x/1280.0,view_size.y/800.0)
	size=Vector2(1280,800);scale=Vector2.ONE*factor;position=(view_size-size*factor)*.5
	paused_button.position=Vector2(size.x-160,20)
	menu.position=(size-menu.size)*.5
	warning.position=Vector2(24,size.y-94); warning.size=Vector2(size.x-48,48)
	queue_redraw()
func bind(value) -> void: game=value
func update() -> void:
	if game: warning.text=game.save_status
	queue_redraw()
func _draw() -> void:
	if not game: return
	var s=game.sim
	var ink:=Color("244d60"); var cream:=Color("fff2da"); var orange:=Color("e98945")
	draw_style_box(_panel(Color("244d60e8")),Rect2(20,20,440,105))
	draw_string(font,Vector2(40,51),"顺风急送 / 第 %d 单" % (s.job_index+1),HORIZONTAL_ALIGNMENT_LEFT,-1,23,cream)
	var destination: String="码头取货" if s.phase=="pickup" else s.Map.stop_name(s.target_index())
	draw_string(font,Vector2(40,86),destination,HORIZONTAL_ALIGNMENT_LEFT,-1,26,cream)
	draw_string(font,Vector2(40,111),"已送 %d/%d · 完好 %d%%" % [s.delivered,s.deliveries.size(),int(s.integrity)],HORIZONTAL_ALIGNMENT_LEFT,-1,17,cream)
	var speed_text: String="%02d" % int(absf(s.speed)*3.6)
	draw_circle(Vector2(83,size.y-95),47,Color("fff2dae8"));draw_string(font,Vector2(52,size.y-93),speed_text,HORIZONTAL_ALIGNMENT_LEFT,-1,32,ink);draw_string(font,Vector2(58,size.y-70),"km/h",HORIZONTAL_ALIGNMENT_LEFT,-1,15,ink)
	var seconds:=int(maxf(0,s.deadline-s.elapsed));var clock_text: String="加急奖励 %d:%02d" % [seconds/60,seconds%60] if s.elapsed<=s.deadline else "继续送达 · 已超时"
	draw_style_box(_panel(Color("244d60df")),Rect2(size.x-370,76,350,43))
	draw_string(font,Vector2(size.x-350,105),clock_text,HORIZONTAL_ALIGNMENT_LEFT,-1,21,cream)
	if s.phase in ["pickup","delivery"]:
		var delta: Vector2=s.target()-s.pos;var bearing:=wrapf(atan2(-delta.x,-delta.y)-s.yaw,-PI,PI)
		var cx:=size.x*.5;var arrow_x:=cx+clampf(bearing/(PI*.75),-1,1)*180
		draw_style_box(_panel(Color("244d60df")),Rect2(cx-205,20,410,68))
		draw_line(Vector2(cx-195,48),Vector2(cx+195,48),Color("fff2da80"),2)
		draw_colored_polygon(PackedVector2Array([Vector2(arrow_x-8,38),Vector2(arrow_x+8,38),Vector2(arrow_x,51)]),orange)
		draw_string(font,Vector2(cx-60,77),"目的地 %dm" % int(delta.length()),HORIZONTAL_ALIGNMENT_CENTER,120,18,cream)
		if s.interactable():
			draw_style_box(_panel(Color("fff2daee")),Rect2(size.x*.5-180,size.y-155,360,56))
			draw_string(font,Vector2(size.x*.5-160,size.y-119),"E 取件出发" if s.phase=="pickup" else "E 交付包裹",HORIZONTAL_ALIGNMENT_CENTER,320,24,ink)
		elif delta.length()<3.3 and absf(s.speed)>=1:
			draw_string(font,Vector2(size.x*.5-160,size.y-120),"按空格停车后交接",HORIZONTAL_ALIGNMENT_CENTER,320,22,cream)
	if s.reset_hold>0: draw_arc(Vector2(size.x*.5,size.y*.5),34,-PI*.5,-PI*.5+TAU*minf(s.reset_hold/1.3,1),40,orange,5)
	draw_style_box(_panel(Color("244d60ed")),Rect2(150,size.y-57,1110,43))
	draw_string(font,Vector2(170,size.y-28),"WASD 骑行 · 鼠标右键环视 · 空格刹车 · E 交接 · 长按 R 扶正 · Esc 暂停",HORIZONTAL_ALIGNMENT_LEFT,-1,16,cream)
func _panel(color: Color) -> StyleBoxFlat:
	var result:=StyleBoxFlat.new();result.bg_color=color;result.corner_radius_top_left=14;result.corner_radius_top_right=14;result.corner_radius_bottom_left=14;result.corner_radius_bottom_right=14;return result
func show_menu(kind: String) -> void:
	menu_kind=kind
	for child in actions.get_children(): actions.remove_child(child);child.queue_free()
	if kind.is_empty(): menu.hide(); return
	menu.show()
	if kind=="pause":
		menu_title.text="路边歇一会儿";menu_info.text="配送时间已暂停，继续后接着骑。"
		_button("继续骑行",func():resume_requested.emit())
		_button("镜头晃动："+("关闭" if game.comfort else "开启"),func():comfort_changed.emit(not game.comfort);show_menu("pause"))
		_button("重新配送…",func():show_menu("retry_confirm"))
		_button("关闭游戏" if get_tree().current_scene==game else "回到海岛",func():home_requested.emit())
	elif kind=="retry_confirm":
		menu_title.text="重新配送？";menu_info.text="本单位置、货物和耗时将重新开始，已完成订单记录保留。"
		_button("取消",func():show_menu("pause"))
		_button("确认重新开始",func():retry_requested.emit())
	else:
		var success: bool=kind=="complete"
		menu_title.text="这一程送到了！" if success else "包裹需要重新整理"
		menu_info.text="完好 %d%% · %d 次碰撞\n行程 %dm · 用时 %d 秒\n本单得分 %d" % [int(game.sim.integrity),game.sim.collisions,int(game.sim.distance),int(game.sim.elapsed),game.sim.score()]
		if success: _button("接下一单",func():next_requested.emit())
		_button("重新配送",func():retry_requested.emit())
		_button("关闭游戏" if get_tree().current_scene==game else "回到海岛",func():home_requested.emit())
	if actions.get_child_count()>0: actions.get_child(0).grab_focus()
func _button(label: String, action: Callable) -> void:
	var button:=Button.new();button.text=label;button.custom_minimum_size.y=44;button.add_theme_font_size_override("font_size",20);actions.add_child(button);button.pressed.connect(action)
