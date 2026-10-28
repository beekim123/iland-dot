extends Control
signal pause_requested
signal resume_requested
signal retry_requested
signal home_requested
signal sound_requested
signal collection_requested
const FONT = preload("fruit-sans.otf")
var state := {}
var profile := {}
var paused := false
var save_warning := ""
var toast := ""
var toast_time := 0.0
var panel: PanelContainer
var title: Label
var detail: Label
var resume_button: Button
var retry_button: Button
var exit_button: Button
var pause_button: Button
var sound_button: Button
var collection_button: Button
var collection_open:=false
var warning_banner:PanelContainer
var warning_label:Label
var confirmation := false
var sound_on := true
var standalone:=false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme_value:=Theme.new();theme_value.default_font=FONT;theme_value.default_font_size=19
	for style in ["normal","hover","pressed","focus"]:
		var box:=StyleBoxFlat.new();box.bg_color=Color("f7e8d6") if style=="normal" else Color("d7f1da")
		box.corner_radius_top_left=18;box.corner_radius_top_right=18;box.corner_radius_bottom_left=18;box.corner_radius_bottom_right=18
		box.content_margin_left=18;box.content_margin_right=18;box.content_margin_top=10;box.content_margin_bottom=10
		if style=="focus":box.set_border_width_all(3);box.border_color=Color("407b68");box.bg_color=Color(0,0,0,0)
		theme_value.set_stylebox(style,"Button",box)
	theme_value.set_color("font_focus_color","Button",Color("294f57"));theme_value.set_color("font_pressed_color","Button",Color("294f57"));theme_value.set_color("font_color","Button",Color("4a5752"));theme_value.set_color("font_hover_color","Button",Color("2f5a47"));theme=theme_value
	pause_button=Button.new();pause_button.text="暂停  Esc";pause_button.pressed.connect(func():pause_requested.emit());add_child(pause_button)
	sound_button=Button.new();sound_button.text="音乐 开";sound_button.pressed.connect(func():sound_requested.emit());add_child(sound_button)
	collection_button=Button.new();collection_button.text="水果图鉴";collection_button.pressed.connect(func():collection_requested.emit());add_child(collection_button)
	panel=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_STOP;panel.hide()
	var panel_style:=StyleBoxFlat.new();panel_style.bg_color=Color("fff8e9");panel_style.corner_radius_top_left=28;panel_style.corner_radius_top_right=28;panel_style.corner_radius_bottom_left=28;panel_style.corner_radius_bottom_right=28;panel_style.set_content_margin_all(26);panel.add_theme_stylebox_override("panel",panel_style);add_child(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",14);panel.add_child(column)
	title=Label.new();title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_color_override("font_color",Color("425c4b"));title.add_theme_font_size_override("font_size",30);column.add_child(title)
	detail=Label.new();detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;detail.add_theme_color_override("font_color",Color("6a7465"));detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.custom_minimum_size=Vector2(0,90);column.add_child(detail)
	resume_button=_button(column,"继续吃水果",func():resume_requested.emit())
	retry_button=_button(column,"再游一次",func():retry_requested.emit())
	exit_button=_button(column,"返回海岛",func():_request_home())
	warning_banner=PanelContainer.new();warning_banner.z_index=100;warning_banner.mouse_filter=Control.MOUSE_FILTER_IGNORE;var warning_style:=StyleBoxFlat.new();warning_style.bg_color=Color("fff2b0");warning_style.set_content_margin_all(7);warning_banner.add_theme_stylebox_override("panel",warning_style);add_child(warning_banner)
	warning_label=Label.new();warning_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;warning_label.add_theme_font_size_override("font_size",14);warning_label.add_theme_color_override("font_color",Color("695322"));warning_banner.add_child(warning_label);warning_banner.hide()
	resized.connect(_layout);_layout()

func _button(column: VBoxContainer, text_value:String, action:Callable) -> Button:
	var b:=Button.new();b.text=text_value;b.custom_minimum_size.y=45;b.pressed.connect(action);column.add_child(b);return b

func _layout() -> void:
	if not is_instance_valid(panel):return
	var toolbar_width:=104 if size.x<900 else 128
	pause_button.position=Vector2(size.x-toolbar_width-22,25);pause_button.size=Vector2(toolbar_width,42)
	sound_button.position=Vector2(size.x-toolbar_width-22,76);sound_button.size=Vector2(toolbar_width,38)
	collection_button.position=Vector2(25,146);collection_button.size=Vector2(110 if size.x<900 else 135,38)
	var compact:=size.y<500
	var usable_height:=size.y-(60 if not save_warning.is_empty() else 0)
	var width:=minf(430,size.x-32);var height:=minf(390,usable_height-32)
	panel.position=Vector2((size.x-width)*.5,(usable_height-height)*.5);panel.size=Vector2(width,height)
	var style:StyleBoxFlat=panel.get_theme_stylebox("panel").duplicate();style.set_content_margin_all(14 if compact else 26);panel.add_theme_stylebox_override("panel",style)
	detail.custom_minimum_size.y=45 if compact else 90;title.add_theme_font_size_override("font_size",22 if compact else 30)
	for button in [resume_button,retry_button,exit_button]:
		button.custom_minimum_size.y=32 if compact else 45
		button.add_theme_font_size_override("font_size",16 if compact else 19)
		for style_name in ["normal","hover","pressed"]:
			var bs:StyleBoxFlat=theme.get_stylebox(style_name,"Button").duplicate();bs.content_margin_top=4 if compact else 10;bs.content_margin_bottom=4 if compact else 10;button.add_theme_stylebox_override(style_name,bs)
	panel.size=Vector2(width,height)
	if is_instance_valid(warning_banner):
		warning_banner.position=Vector2(20,size.y-50);warning_banner.size=Vector2(size.x-40,36)
	queue_redraw()

func present(snapshot:Dictionary, data:Dictionary, is_paused:bool, warning:String) -> void:
	var warning_changed:=save_warning!=warning
	state=snapshot;profile=data;paused=is_paused;save_warning=warning
	warning_banner.visible=not warning.is_empty();warning_label.text=warning
	if warning_changed:_layout()
	var modal := paused or not bool(state.get("alive",true))
	var was_visible:=panel.visible;panel.visible=modal
	pause_button.visible=not modal;collection_button.visible=not modal
	if modal:
		if collection_open:
			title.text="水果软糖图鉴"
			var names:=["苹果","橘瓣","草莓","葡萄","西瓜"];var lines:=[]
			for i in 5:lines.append("%s  ·  %d 颗"%[names[i],int(profile.fruit_counts[i])])
			detail.text="\n".join(lines);resume_button.visible=true;resume_button.text="继续吃水果";retry_button.hide();exit_button.hide()
		elif not confirmation:
			exit_button.show()
			var won:=bool(state.get("won",false))
			title.text="海底大丰收！" if won else ("稍微歇一会" if paused else "海底旅行结束")
			detail.text="时间已暂停，转向也已清空。" if paused else "得分 %d  ·  最长 %d 节\n吃掉 %d 颗水果软糖\n%s"%[int(state.get("score",0)),int(state.get("longest",4)),int(state.get("meals",0)),"水蛇长到了 120 节！" if won else ("碰到自己的身体了。" if state.get("reason","")=="self" else "游出了安全水域。")]
			resume_button.visible=paused;resume_button.text="继续吃水果";retry_button.visible=true;retry_button.text="再游一次";exit_button.text="关闭游戏" if standalone else "返回海岛"
		if not was_visible:
			if paused:resume_button.grab_focus()
			else:retry_button.grab_focus()
	else:
		confirmation=false;collection_open=false
		if get_viewport().gui_get_focus_owner():get_viewport().gui_release_focus()
	queue_redraw()

func _request_home() -> void:
	if not confirmation and bool(state.get("alive",true)):
		confirmation=true;title.text="结束这一盘？";detail.text="本盘成绩会记入纪录。\n再次进入会开始新的一盘。";resume_button.hide();retry_button.hide();exit_button.text="确认关闭游戏" if standalone else "确认返回海岛";exit_button.grab_focus();queue_redraw()
	else:
		var viewport:=get_viewport()
		if viewport:viewport.set_input_as_handled()
		home_requested.emit()

func cancel_confirmation() -> bool:
	if not confirmation:return false
	confirmation=false;present(state,profile,paused,save_warning);resume_button.grab_focus();return true

func _draw() -> void:
	if state.is_empty():return
	var ink:=Color("edf9ed")
	_text(Vector2(28,43),"海底软糖水蛇",30,ink)
	_text(Vector2(29,66),"UNDERWATER · GUMMY SNAKE",12,Color("c0dfdf"))
	_text(Vector2(29,108),"%04d"%int(state.get("score",0)),35,Color("ffd4ad"))
	_text(Vector2(136,106),"分",15,ink)
	_text(Vector2(29,134),"长度 %d  /  最高分 %d"%[int(state.get("longest",4)),int(profile.get("best_score",0))],14,ink)
	var cx:=size.x*.5+(25 if size.x<900 else 0)
	_text(Vector2(cx-105,45),"混合三种水果  +30",17,ink)
	var colors:=[Color("ef8293"),Color("ffb65f"),Color("f56889"),Color("ae8be3"),Color("84c99a")]
	var combo:Array=state.get("combo",[])
	for i in 3:
		draw_circle(Vector2(cx-29+i*29,68),8,colors[int(combo[i])] if i<combo.size() else Color("e7d8c4"))
	_text(Vector2(27,size.y-48),"A/D 转向  Space/C 升潜  W/S 速度" if size.x<900 else "A/D 转向  Space/C 升潜  W/S 速度     Esc 暂停",14,ink)
	_text(Vector2(size.x-240,size.y-26),"深度 %.1fm  ·  %.1f 米/秒"%[float(state.get("depth",0)),float(state.get("speed",0))],14,ink)
	if not toast.is_empty():
		var tw:=FONT.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
		_text(Vector2((size.x-tw)*.5,118),toast,22,Color("c76784"))
	if state.has("target_distance") and not panel.visible:
		var h:float=state.target_height
		_text(Vector2(28,211),"目标水果 %.1fm  %s %.1fm"%[state.target_distance,"上方" if h>=0 else "下方",absf(h)],15,ink)
		var point:Vector2=state.get("target_screen",Vector2(-1,-1))
		if point.x>=0 and point.y>=190 and point.x<size.x-15 and point.y<size.y-70:
			draw_arc(point,22,0,TAU,32,Color("fff4b8"),2,true)
		_text(Vector2(28,235),str(state.get("target_hint","")),14,ink)
	if float(state.get("boundary_distance",10))<3:
		_text(Vector2(size.x*.5-85,90),"接近边界，请转向！",20,Color("b54545"))
	if float(state.get("countdown",0))>0 and not panel.visible:
		_text(Vector2(size.x*.5-18,size.y*.5),str(int(ceilf(float(state.countdown)))),52,Color("ca6e84"))
		_text(Vector2(size.x*.5-80,size.y*.5+32),"准备好吃水果了吗",17,ink)
	if panel.visible:draw_rect(Rect2(Vector2.ZERO,size),Color(.15,.24,.19,.18))
	# Save warning is a separate topmost child, with reserved space below modal.

func _text(at:Vector2, value:String, pixels:int, color:Color) -> void:
	draw_string(FONT,at+Vector2(0,1),value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,Color(0.02,.12,.17,.65))
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _input(event:InputEvent) -> void:
	if not panel.visible or not event is InputEventKey:return
	var code:int=int(event.physical_keycode) if event.physical_keycode!=0 else int(event.keycode)
	if code not in [KEY_ENTER,KEY_KP_ENTER,KEY_SPACE]:return
	var viewport:=get_viewport()
	var focused:Control=viewport.gui_get_focus_owner()
	if focused is Button and panel.is_ancestor_of(focused):
		# Accept before emitting: the host may synchronously remove this entire game.
		viewport.set_input_as_handled()
		if event.pressed and not event.echo:focused.pressed.emit()
