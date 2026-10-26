extends CanvasLayer
## Self-contained candy HUD. Only signals leave this module; it never owns game input.
signal pause_requested
signal exit_requested
signal restart_requested
const Icon = preload("candy_icon.gd")
const FONT = preload("hud-font.otf")
const INK = Color("624765")
var root: Control
var canvas: Control
var values := {}
var wave_label: Label
var best_label: Label
var modal: PanelContainer
var modal_title: Label
var modal_subtitle: Label
var action: Button
var hint: Label
var hint_time := 0.0
var last_state := {}

func _ready() -> void:
	layer = 12
	root = Control.new(); add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new(); theme.default_font = FONT; theme.default_font_size = 18; root.theme = theme
	canvas = Control.new(); root.add_child(canvas); canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stats := HBoxContainer.new(); stats.position = Vector2(24,14); stats.add_theme_constant_override("separation",10); canvas.add_child(stats)
	_chip(stats,"star","0",Color("f6ba54"),118,"分数")
	_chip(stats,"bomb","1/1",Color("ea84ae"),100,"可用炸弹 / 容量")
	_chip(stats,"range","2",Color("a58cdb"),80,"爆炸范围")
	_chip(stats,"speed","1.0",Color("69beb3"),86,"移动速度")
	var badge := PanelContainer.new(); badge.position = Vector2(507,10); badge.custom_minimum_size = Vector2(186,58)
	badge.add_theme_stylebox_override("panel",_style(Color("fff5dd"),28)); canvas.add_child(badge)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; badge.add_child(row)
	var mascot := Icon.new(); mascot.kind="gummy"; mascot.tint=Color("f5a56e"); mascot.custom_minimum_size=Vector2(38,38); row.add_child(mascot)
	wave_label = _label("第 1 波",22); row.add_child(wave_label)
	best_label = _label("最高 0",13); best_label.position=Vector2(28,72); best_label.modulate.a=.75; canvas.add_child(best_label)
	var pause := _icon_button("pause","暂停",Vector2(1060,22)); pause.pressed.connect(func(): pause_requested.emit())
	var home := _icon_button("home","返回海岛",Vector2(1124,22)); home.pressed.connect(func(): exit_requested.emit())
	hint = _label("WASD 移动   ·   SPACE 放糖果   ·   ESC 暂停",15)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; hint.position=Vector2(300,712); hint.size=Vector2(600,24); canvas.add_child(hint)
	modal=PanelContainer.new(); modal.position=Vector2(405,265); modal.custom_minimum_size=Vector2(390,215); modal.add_theme_stylebox_override("panel",_style(Color("fff6ec"),32)); canvas.add_child(modal)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",14); modal.add_child(column)
	modal_title=_label("休息一下",29); modal_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; column.add_child(modal_title)
	modal_subtitle=_label("糖果花园等你回来",17); modal_subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; column.add_child(modal_subtitle)
	action=Button.new(); action.text="继续游戏"; action.custom_minimum_size=Vector2(240,52); _style_button(action,Color("f6b3c6")); column.add_child(action)
	action.pressed.connect(func():
		if last_state.get("alive",true): pause_requested.emit()
		else: restart_requested.emit())
	modal.hide()
	get_viewport().size_changed.connect(_layout); _layout()

func _layout() -> void:
	var vp:=get_viewport().get_visible_rect().size
	var s:float=min(vp.x/1200.0,vp.y/750.0)
	canvas.scale=Vector2.ONE*s; canvas.size=Vector2(1200,750); canvas.position=(vp-canvas.size*s)*.5

func _style(color:Color,radius:int) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new(); s.bg_color=color
	s.set_corner_radius_all(radius); s.set_border_width_all(2); s.border_color=Color(1,1,1,.75)
	s.shadow_color=Color(.28,.16,.32,.16); s.shadow_size=3; s.shadow_offset=Vector2(0,4)
	s.content_margin_left=14; s.content_margin_right=14; s.content_margin_top=10; s.content_margin_bottom=10
	return s

func _label(text:String,font_size:int) -> Label:
	var l:=Label.new(); l.text=text; l.add_theme_font_size_override("font_size",font_size); l.add_theme_color_override("font_color",INK); l.mouse_filter=Control.MOUSE_FILTER_IGNORE; return l

func _chip(parent:Control,kind:String,text:String,color:Color,width:float,tip:String) -> void:
	var panel:=PanelContainer.new(); panel.custom_minimum_size=Vector2(width,48); panel.tooltip_text=tip
	panel.add_theme_stylebox_override("panel",_style(Color("fff9f0"),24)); parent.add_child(panel)
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",4); panel.add_child(row)
	var icon:=Icon.new(); icon.kind=kind; icon.tint=color; icon.custom_minimum_size=Vector2(30,30); row.add_child(icon)
	var label:=_label(text,22); row.add_child(label); values[kind]=label

func _style_button(b:Button,color:Color) -> void:
	b.focus_mode=Control.FOCUS_NONE; b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",_style(color,26)); b.add_theme_stylebox_override("hover",_style(color.lightened(.12),26))
	var pressed:=_style(color.darkened(.06),26); pressed.shadow_size=0; pressed.shadow_offset=Vector2.ZERO; b.add_theme_stylebox_override("pressed",pressed)
	b.add_theme_color_override("font_color",INK); b.add_theme_color_override("font_hover_color",INK); b.add_theme_color_override("font_pressed_color",INK)
	b.button_down.connect(func(): b.scale=Vector2(.95,.95))
	b.button_up.connect(func(): b.scale=Vector2.ONE)
	b.mouse_exited.connect(func(): b.scale=Vector2.ONE)

func _icon_button(kind:String,tip:String,pos:Vector2) -> Button:
	var b:=Button.new(); b.position=pos; b.size=Vector2(52,52); b.tooltip_text=tip; _style_button(b,Color("fff7e9")); canvas.add_child(b)
	var icon:=Icon.new(); icon.kind=kind; icon.position=Vector2(8,8); icon.size=Vector2(36,36); b.add_child(icon); return b

func update_state(data:Dictionary) -> void:
	last_state=data
	if not is_node_ready(): return
	values.star.text=str(data.get("score",0))
	var cap:int=int(data.get("capacity",1)); values.bomb.text="%d/%d"%[maxi(0,cap-int(data.get("bombs_active",0))),cap]
	values.range.text=str(data.get("range",2)); values.speed.text="%.1f"%float(data.get("speed",1.0))
	wave_label.text="第 %d 波"%int(data.get("wave",1)); best_label.text="最高 %d"%int(data.get("highscore",0))
	var alive:bool=data.get("alive",true); var paused:bool=data.get("paused",false)
	modal.visible=paused or not alive
	if not alive:
		modal_title.text="再来一颗糖！"; modal_subtitle.text="得分 %d · 即将重新开始"%int(data.get("score",0)); action.text="立即重来"
	elif paused:
		modal_title.text="休息一下"; modal_subtitle.text="糖果花园等你回来"; action.text="继续游戏"
	elif float(data.get("next_wave",0))>0:
		wave_label.text="下一波！"

func _process(delta:float) -> void:
	hint_time+=delta
	if hint: hint.modulate.a=lerpf(1.0,.35,clampf((hint_time-8)/3,0,1))
