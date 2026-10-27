extends CanvasLayer
## Independent sunlit-greenhouse competition HUD. Presentation emits intent only.
## Legacy score keys remain green/coral for simulation and save compatibility.
signal pause_requested
signal exit_requested
signal restart_requested
signal audio_requested
const Icon = preload("bloom_icon.gd")
const FONT = preload("bloom-ui.otf")
const Rules = preload("../sim.gd")
const BLUE = Color("2f62ff")
const ORANGE = Color("ff8a1f")
const WHITE = Color("f2f5f5")
const MINERAL = Color("dce1e1")
const GRAPHITE = Color("252e38")
const MUTED = Color("c2ccd5")
const SCORE_WIDTH := 560.0
var root: Control
var canvas: Control
var modal_canvas: Control
var overlay: Control
var score_strip: Panel
var score_green: Label
var score_coral: Label
var clock_label: Label
var cover_green: ColorRect
var cover_coral: ColorRect
var team_markers: Array[Control] = []
var resources: Panel
var health: ProgressBar
var water: ProgressBar
var health_text: Label
var water_text: Label
var water_status: Label
var dash_text: Label
var pod_text: Label
var dash_card: Panel
var pod_card: Panel
var dash_fill: ProgressBar
var pod_fill: ProgressBar
var mute_icon: Control
var utility_controls: Control
var modal: Panel
var scrim: ColorRect
var modal_title: Label
var modal_subtitle: Label
var modal_detail: Label
var modal_kicker: Label
var modal_accent: ColorRect
var result_scores: Control
var result_blue: Label
var result_orange: Label
var action: Button
var restart_action: Button
var result_return: Button
var center_title: Label
var center_subtitle: Label
var center_kicker: Label
var center_group: Control
var intro: Control
var hint: Label
var hint_backing: ColorRect
var toast: Label
var state: Dictionary = {}
var hint_elapsed := 0.0
var toast_left := 0.0
var _last_countdown := 0.0

class WorldOverlay extends Control:
	var tags: Array = []
	var target := Vector2.ZERO
	var crosshair_on := false
	var team_color := Color("f2f5f5")
	func _draw() -> void:
		for tag in tags:
			var p: Vector2 = tag.pos
			var color: Color = tag.color
			if tag.has("fuse"):
				draw_arc(p,13,-PI*.5,PI*1.5,32,Color(.10,.13,.17,.8),3.0,true)
				draw_arc(p,13,-PI*.5,-PI*.5+TAU*clampf(tag.fuse,0,1),32,color,2.0,true)
				p += Vector2(0,-20)
			if tag.get("player",false):
				draw_colored_polygon(PackedVector2Array([p+Vector2(-3,-10),p+Vector2(3,-10),p+Vector2(0,-6)]),Color("f2f5f5"))
			var w := 30.0 if tag.get("player",false) else 26.0
			draw_rect(Rect2(p+Vector2(-w*.5,-2),Vector2(w,5)),Color(.08,.11,.15,.8))
			draw_rect(Rect2(p+Vector2(-w*.5+1,-1),Vector2(maxf(0,(w-2)*clampf(tag.hp,0,1)),3)),color)
		if crosshair_on:
			# Four short strokes leave the impact point and target silhouette clear.
			for v in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				draw_line(target+v*5,target+v*10,Color(.06,.08,.12,.8),3.2,true)
				draw_line(target+v*5,target+v*10,team_color,1.4,true)
			draw_circle(target,2.1,Color(.06,.08,.12,.8))
			draw_circle(target,1.0,team_color)

func _ready() -> void:
	layer = 14
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 16
	root.theme = theme
	overlay = WorldOverlay.new()
	root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas = _control(root)
	_build_score()
	_build_utilities()
	_build_resources()
	_build_abilities()
	_build_center()
	_build_intro()
	hint_backing = _rect(canvas,Vector2.ZERO,Vector2(700,26),Color(.045,.065,.09,.76))
	hint = _text(canvas,"WASD 移动   /   鼠标瞄准 · 左键喷射   /   SPACE 冲刺   /   右键花苞   /   ESC 暂停",12,Vector2.ZERO,Vector2(750,24),MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_backing.size.x = FONT.get_string_size(hint.text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+28
	toast = _text(canvas,"",16,Vector2.ZERO,Vector2(640,30),WHITE)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readable(toast)
	scrim = ColorRect.new()
	scrim.color = Color(.045,.065,.09,.74)
	root.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.hide()
	modal_canvas = _control(root)
	_build_modal()
	get_viewport().size_changed.connect(_layout)
	_layout()
	update_state(state)

func _control(parent: Node) -> Control:
	var node := Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _plate(parent: Node, dimensions: Vector2, color: Color = Color(.09,.12,.17,.80)) -> Panel:
	var panel := Panel.new()
	panel.size = dimensions
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel",_style(color))
	parent.add_child(panel)
	return panel

func _style(color: Color, border: Color = Color(1,1,1,.13)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(1)
	return box

func _text(parent: Node, value: String, font_size: int, pos: Vector2, dimensions: Vector2, color: Color = WHITE) -> Label:
	var label := Label.new()
	label.text = value
	label.position = pos
	label.size = dimensions
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _number(parent: Node, value: String, font_size: int, pos: Vector2, dimensions: Vector2, color: Color = WHITE) -> Label:
	var label := _text(parent,value,font_size,pos,dimensions,color)
	# Tabular numerals from the module's self-contained font, never a system font.
	var digits := FontVariation.new()
	digits.base_font = FONT
	digits.opentype_features = {"tnum":1}
	label.add_theme_font_override("font",digits)
	return label

func _readable(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color",Color(.04,.06,.09,.9))
	label.add_theme_constant_override("shadow_offset_y",1)
	label.add_theme_constant_override("shadow_outline_size",2)

func _rect(parent: Node, pos: Vector2, dimensions: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = dimensions
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect

func _icon(parent: Node, kind: String, color: Color, pos: Vector2, dimensions: Vector2) -> Control:
	var icon := Icon.new()
	icon.kind = kind
	icon.tint = color
	icon.position = pos
	icon.size = dimensions
	parent.add_child(icon)
	return icon

func _build_score() -> void:
	score_strip = _plate(canvas,Vector2(SCORE_WIDTH,54))
	score_strip.name = "BroadcastScore"
	for team in 2:
		for slot in 2:
			var x := 9.0+slot*24.0 if team==0 else SCORE_WIDTH-55.0+slot*24.0
			var marker := _icon(score_strip,"team_blue" if team==0 else "team_orange",BLUE.lightened(.24) if team==0 else ORANGE,Vector2(x,11),Vector2(21,24))
			marker.is_player = team==0 and slot==0
			team_markers.append(marker)
	_text(score_strip,"蓝队",11,Vector2(67,14),Vector2(33,24),MUTED)
	score_green = _number(score_strip,"0.0%",25,Vector2(108,4),Vector2(110,39))
	score_coral = _number(score_strip,"0.0%",25,Vector2(342,4),Vector2(110,39))
	score_coral.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text(score_strip,"橙队",11,Vector2(460,14),Vector2(33,24),MUTED)
	_rect(score_strip,Vector2(232,11),Vector2(1,25),Color(1,1,1,.16))
	_rect(score_strip,Vector2(327,11),Vector2(1,25),Color(1,1,1,.16))
	clock_label = _number(score_strip,"3:00",24,Vector2(238,5),Vector2(84,37))
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var track := _rect(score_strip,Vector2(0,49),Vector2(SCORE_WIDTH,4),Color(.5,.56,.62,.32))
	cover_green = _rect(track,Vector2.ZERO,Vector2(0,4),BLUE)
	cover_coral = _rect(track,Vector2(SCORE_WIDTH,0),Vector2(0,4),ORANGE)

func _build_utilities() -> void:
	utility_controls = _control(canvas)
	utility_controls.size = Vector2(120,36)
	var sound := _icon_button(utility_controls,"sound","声音开关",Vector2.ZERO)
	mute_icon = sound.get_child(0)
	sound.pressed.connect(func(): audio_requested.emit())
	var pause := _icon_button(utility_controls,"pause","ESC · 暂停",Vector2(42,0))
	pause.pressed.connect(func(): pause_requested.emit())
	var home := _icon_button(utility_controls,"home","返回海岛",Vector2(84,0))
	home.pressed.connect(func(): exit_requested.emit())

func _icon_button(parent: Control, kind: String, tip: String, pos: Vector2) -> Button:
	var button := Button.new()
	button.position = pos
	button.size = Vector2(36,36)
	button.tooltip_text = tip
	_style_button(button,false)
	# Utility clicks must never leave SPACE focused on a button during play.
	button.focus_mode = Control.FOCUS_NONE
	parent.add_child(button)
	_icon(button,kind,WHITE,Vector2(7,7),Vector2(22,22))
	return button

func _bar(parent: Node, color: Color, pos: Vector2, dimensions: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	# Disable native percentage layout BEFORE assigning a thin final size.
	# Otherwise the default font minimum expands size to 27 px and retains it.
	bar.show_percentage = false
	bar.position = pos
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(.55,.61,.67,.22)
	bar.add_theme_stylebox_override("background",background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar)
	bar.size = dimensions
	return bar

func _build_resources() -> void:
	resources = _plate(canvas,Vector2(252,82))
	resources.name = "PlayerResources"
	_rect(resources,Vector2.ZERO,Vector2(3,82),BLUE)
	_icon(resources,"health",WHITE,Vector2(14,11),Vector2(19,19))
	_text(resources,"生命",11,Vector2(42,8),Vector2(38,22),MUTED)
	health_text = _number(resources,"100",20,Vector2(180,4),Vector2(56,29))
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health = _bar(resources,WHITE,Vector2(42,34),Vector2(194,5))
	_icon(resources,"water",BLUE.lightened(.45),Vector2(14,47),Vector2(19,21))
	water_status = _text(resources,"液量",11,Vector2(42,43),Vector2(132,22),MUTED)
	water_text = _number(resources,"100",17,Vector2(184,40),Vector2(52,26),BLUE.lightened(.5))
	water_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	water = _bar(resources,BLUE,Vector2(42,69),Vector2(194,4))

func _build_abilities() -> void:
	dash_card = _ability("dash","SPACE","冲刺")
	pod_card = _ability("pod","右键","花苞")
	dash_text = dash_card.get_meta("status")
	pod_text = pod_card.get_meta("status")
	dash_fill = dash_card.get_meta("fill")
	pod_fill = pod_card.get_meta("fill")
	dash_card.tooltip_text = "向移动方向短冲刺 · 3 秒冷却"
	pod_card.tooltip_text = "在己方涂层部署花苞 · 3 秒后扩地 · 可被击毁"

func _ability(kind: String, key: String, title: String) -> Panel:
	var block := _plate(canvas,Vector2(96,82))
	_icon(block,kind,WHITE,Vector2(12,10),Vector2(29,29))
	var status := _number(block,"就绪",13,Vector2(43,12),Vector2(47,27),WHITE)
	_text(block,title,12,Vector2(12,46),Vector2(38,22),MINERAL)
	var key_label := _text(block,key,10,Vector2(47,46),Vector2(40,22),MUTED)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var fill := _bar(block,BLUE,Vector2(0,79),Vector2(96,3))
	block.set_meta("status",status)
	block.set_meta("fill",fill)
	return block

func _build_center() -> void:
	center_group = _control(canvas)
	center_group.size = Vector2(420,140)
	center_kicker = _text(center_group,"MATCH START",12,Vector2(0,0),Vector2(420,20),MINERAL)
	center_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_title = _number(center_group,"3",72,Vector2(0,19),Vector2(420,90))
	center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_subtitle = _text(center_group,"准备争夺地面",15,Vector2(0,110),Vector2(420,26),WHITE)
	center_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for label in [center_title,center_subtitle,center_kicker]: _readable(label)

func _build_intro() -> void:
	intro = _control(canvas)
	intro.size = Vector2(580,190)
	var panel := _plate(intro,Vector2(580,190),Color(.07,.10,.14,.90))
	_rect(panel,Vector2.ZERO,Vector2(580,3),BLUE)
	_text(panel,"绒芽争园  /  BLOOM SKIRMISH",12,Vector2(26,19),Vector2(520,25),MUTED)
	_text(panel,"让地面成为你的颜色",30,Vector2(26,50),Vector2(528,44))
	_text(panel,"2 对 2    /    180 秒    /    覆盖更多地面获胜",14,Vector2(28,100),Vector2(520,28),MINERAL)
	_rect(panel,Vector2(26,142),Vector2(28,2),BLUE)
	_text(panel,"点击场景开始  →",16,Vector2(65,130),Vector2(430,38),WHITE)

func _style_button(button: Button, primary: bool) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var base := BLUE if primary else Color(.08,.11,.15,.83)
	button.add_theme_stylebox_override("normal",_style(base,Color(1,1,1,.18)))
	button.add_theme_stylebox_override("hover",_style(base.lightened(.14),Color(1,1,1,.6)))
	button.add_theme_stylebox_override("pressed",_style(base.darkened(.14),WHITE))
	button.add_theme_stylebox_override("focus",_style(Color(0,0,0,0),WHITE))
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		button.add_theme_color_override(key,WHITE)
	button.add_theme_font_size_override("font_size",16)

func _menu_button(value: String, y: float, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.position = Vector2(408,y)
	button.size = Vector2(218,46)
	_style_button(button,primary)
	modal.add_child(button)
	return button

func _build_modal() -> void:
	modal = _plate(modal_canvas,Vector2(662,330),Color(.075,.10,.14,.97))
	modal.name = "MatchIntermission"
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_accent = _rect(modal,Vector2.ZERO,Vector2(662,3),BLUE)
	modal_kicker = _text(modal,"MATCH PAUSED",12,Vector2(32,25),Vector2(540,25),MUTED)
	modal_title = _text(modal,"比赛暂停",36,Vector2(30,60),Vector2(352,58))
	modal_subtitle = _text(modal,"赛场等你回来",17,Vector2(32,125),Vector2(340,32),MINERAL)
	modal_detail = _text(modal,"ESC 继续 · 暂停时计时停止",12,Vector2(32,271),Vector2(598,25),MUTED)
	_rect(modal,Vector2(380,68),Vector2(1,196),Color(1,1,1,.15))
	result_scores = _control(modal)
	result_scores.position = Vector2(32,176)
	result_scores.size = Vector2(320,78)
	_text(result_scores,"蓝队",11,Vector2.ZERO,Vector2(100,20),BLUE.lightened(.4))
	_text(result_scores,"橙队",11,Vector2(170,0),Vector2(100,20),ORANGE)
	result_blue = _number(result_scores,"0.0%",30,Vector2(0,21),Vector2(142,44))
	result_orange = _number(result_scores,"0.0%",30,Vector2(170,21),Vector2(142,44))
	_rect(result_scores,Vector2(0,70),Vector2(140,2),BLUE)
	_rect(result_scores,Vector2(170,70),Vector2(140,2),ORANGE)
	action = _menu_button("继续比赛",80,true)
	action.pressed.connect(func():
		if state.get("finished",false): restart_requested.emit()
		else: pause_requested.emit())
	restart_action = _menu_button("重新开始",140,false)
	restart_action.pressed.connect(func(): restart_requested.emit())
	result_return = _menu_button("返回海岛",200,false)
	result_return.pressed.connect(func(): exit_requested.emit())
	modal.hide()

func _layout() -> void:
	if not is_instance_valid(canvas): return
	var vp := get_viewport().get_visible_rect().size
	var scale_factor := maxf(.25,minf(vp.x/1280.0,vp.y/800.0))
	var area := vp/scale_factor
	for target in [canvas,modal_canvas]:
		target.scale = Vector2.ONE*scale_factor
		target.size = area
		target.position = Vector2.ZERO
	score_strip.position = Vector2((area.x-SCORE_WIDTH)*.5,18)
	utility_controls.position = Vector2(area.x-142,24)
	resources.position = Vector2(24,area.y-106)
	dash_card.position = Vector2(area.x-228,area.y-106)
	pod_card.position = Vector2(area.x-122,area.y-106)
	hint.position = Vector2((area.x-750)*.5,area.y-38)
	hint_backing.position = Vector2((area.x-hint_backing.size.x)*.5,area.y-38)
	toast.position = Vector2((area.x-640)*.5,area.y-142)
	center_group.position = Vector2((area.x-420)*.5,(area.y-140)*.5-26)
	intro.position = Vector2((area.x-580)*.5,(area.y-190)*.5)
	modal.position = (area-modal.size)*.5

func update_state(data: Dictionary) -> void:
	state = data
	if not is_node_ready(): return
	var blue := clampf(float(data.get("green",0)),0,100)
	var orange := clampf(float(data.get("coral",0)),0,100)
	score_green.text = "%.1f%%"%blue
	score_coral.text = "%.1f%%"%orange
	cover_green.size.x = SCORE_WIDTH*blue/100.0
	cover_coral.size.x = SCORE_WIDTH*orange/100.0
	cover_coral.position.x = SCORE_WIDTH-cover_coral.size.x
	var seconds := maxi(0,ceili(float(data.get("time",180))))
	clock_label.text = "%d:%02d"%[seconds/60,seconds%60]
	clock_label.add_theme_color_override("font_color",ORANGE if seconds<=30 else WHITE)
	health.value = clampf(float(data.get("hp",100)),0,100)
	water.value = clampf(float(data.get("water",100)),0,100)
	health_text.text = str(ceili(health.value))
	water_text.text = str(ceili(water.value))
	health_text.add_theme_color_override("font_color",ORANGE if health.value<=25 else WHITE)
	water_status.text = "松开左键补液" if water.value<=15 else "液量"
	water_status.add_theme_color_override("font_color",ORANGE if water.value<=15 else MUTED)
	var dash := maxf(0,float(data.get("dash_cd",0)))
	var pod := maxf(0,float(data.get("pod_cd",0)))
	dash_text.text = "%.1fs"%dash if dash>0 else "就绪"
	pod_text.text = "%.1fs"%pod if pod>0 else "就绪"
	dash_card.modulate.a = .68 if dash>0 else 1.0
	pod_card.modulate.a = .68 if pod>0 else 1.0
	dash_fill.value = (1-clampf(dash/Rules.DASH_COOLDOWN,0,1))*100
	pod_fill.value = (1-clampf(pod/Rules.POD_COOLDOWN,0,1))*100
	mute_icon.kind = "sound" if data.get("audio",true) else "mute"
	_update_roster(data.get("roster",[]))
	var finished: bool = data.get("finished",false)
	var paused: bool = data.get("paused",false)
	var was_modal := modal.visible
	modal.visible = finished or paused
	scrim.visible = modal.visible
	canvas.modulate.a = .25 if modal.visible else 1.0
	overlay.visible = not modal.visible
	restart_action.visible = paused and not finished
	result_scores.visible = modal.visible
	result_blue.text = "%.1f%%"%blue
	result_orange.text = "%.1f%%"%orange
	if finished:
		var winner := int(data.get("winner",-1))
		modal_kicker.text = "MATCH COMPLETE  /  2V2"
		modal_title.text = "比赛胜利" if winner==0 else ("比赛失利" if winner==1 else "势均力敌")
		modal_subtitle.text = "蓝队占据更多地面" if winner==0 else ("橙队占据更多地面" if winner==1 else "双方覆盖率相同")
		modal_accent.color = BLUE if winner==0 else (ORANGE if winner==1 else MINERAL)
		modal_detail.text = "最佳覆盖 %.1f%%   /   累计获胜 %d 场"%[data.get("best",0.0),data.get("wins",0)]
		action.text = "再来一局"
		action.position.y = 108
		result_return.position.y = 172
	elif paused:
		modal_kicker.text = "MATCH PAUSED  /  "+clock_label.text
		modal_title.text = "比赛暂停"
		modal_subtitle.text = "赛场等你回来"
		modal_accent.color = BLUE
		modal_detail.text = "ESC 继续 · 暂停时比赛计时停止"
		action.text = "继续比赛"
		action.position.y = 80
		result_return.position.y = 200
	if modal.visible and not was_modal: action.grab_focus()
	elif was_modal and not modal.visible: get_viewport().gui_release_focus()
	var countdown := maxf(0,float(data.get("countdown",0)))
	var alive: bool = data.get("alive",true)
	var pointer: bool = data.get("pointer_active",false)
	if not alive:
		dash_text.text = "退场"
		pod_text.text = "退场"
		dash_card.modulate.a = .48
		pod_card.modulate.a = .48
	if countdown>_last_countdown+1.0:
		hint_elapsed = 0
		toast_left = 0
	_last_countdown = countdown
	intro.visible = not modal.visible and not pointer
	center_group.visible = not modal.visible and pointer and (countdown>0 or not alive)
	center_title.visible = center_group.visible
	center_subtitle.visible = center_group.visible
	if countdown>0:
		center_title.text = str(ceili(countdown))
		center_kicker.text = "MATCH START"
		center_subtitle.text = "准备争夺地面"
	elif not alive:
		center_title.text = "%.1f"%data.get("respawn",4.0)
		center_kicker.text = "RESPAWN"
		center_subtitle.text = "正在返回出生区"
	overlay.crosshair_on = not modal.visible and pointer and countdown<=0 and alive
	overlay.target = get_viewport().get_visible_rect().size*.5
	overlay.team_color = ORANGE if data.get("aim_enemy",false) else WHITE
	overlay.tags = data.get("tags",[])
	overlay.queue_redraw()

func _update_roster(roster: Array) -> void:
	var slots := [0,0]
	for actor in roster:
		var team := int(actor.get("team",-1))
		if team<0 or team>1 or slots[team]>=2: continue
		var marker: Control = team_markers[team*2+slots[team]]
		marker.active = actor.get("alive",true)
		marker.is_player = actor.get("player",false)
		marker.queue_redraw()
		slots[team] += 1

func show_toast(message: String, duration: float = 2.2) -> void:
	toast.text = message
	toast_left = duration
	toast.modulate.a = 1.0

func _process(delta: float) -> void:
	if not state.get("paused",false) and state.get("pointer_active",false):
		hint_elapsed += delta
	hint.modulate.a = 1-clampf((hint_elapsed-9)/3,0,1)
	hint_backing.modulate.a = hint.modulate.a
	toast_left = maxf(0,toast_left-delta)
	toast.modulate.a = minf(1,toast_left*3)
