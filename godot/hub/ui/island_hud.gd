extends CanvasLayer
signal reset_requested
signal beach_requested
signal mute_requested
signal volume_changed(value:float)
const Icon=preload("island_icon.gd")
const FontFace=preload("island-hud-font.otf")
var canvas:Control
var sound_icon:Control
var status:Label
var elapsed:=0.0
func _ready():
	layer=10
	var root:=Control.new(); add_child(root); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var theme:=Theme.new(); theme.default_font=FontFace; theme.default_font_size=17; root.theme=theme
	canvas=Control.new(); root.add_child(canvas); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shell:=Icon.new(); shell.position=Vector2(28,23); shell.size=Vector2(50,50); canvas.add_child(shell)
	var title:=Label.new(); title.text="晴贝小岛"; title.position=Vector2(86,25); title.add_theme_font_size_override("font_size",23); title.add_theme_color_override("font_color",Color("fff3dc")); title.add_theme_color_override("font_shadow_color",Color("22515b")); title.add_theme_constant_override("shadow_offset_y",2); canvas.add_child(title)
	var subtitle:=Label.new(); subtitle.text="SUNNY SHELL"; subtitle.position=Vector2(88,59); subtitle.add_theme_font_size_override("font_size",11); subtitle.modulate=Color("c6e8dc"); canvas.add_child(subtitle)
	var view:=_button("view","观景 · R",Vector2(1120,26)); view.pressed.connect(func(): reset_requested.emit())
	var beach:=_button("beach","沙滩近景",Vector2(1120,88)); beach.pressed.connect(func(): beach_requested.emit())
	var sound:=_button("sound","静音 · M",Vector2(1120,150)); sound_icon=sound.get_child(0); sound.pressed.connect(func(): mute_requested.emit())
	var volume:=HSlider.new(); volume.position=Vector2(1076,220); volume.size=Vector2(96,24); volume.min_value=0; volume.max_value=1; volume.step=.01; volume.value=.65; volume.focus_mode=Control.FOCUS_NONE; volume.tooltip_text="海浪与音乐音量"; canvas.add_child(volume); volume.value_changed.connect(func(v): volume_changed.emit(v))
	status=Label.new(); status.text="拖动旋转  ·  滚轮缩放  ·  点击探索"; status.position=Vector2(350,710); status.size=Vector2(500,26); status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size",14); status.add_theme_color_override("font_color",Color("fff6df")); status.add_theme_color_override("font_shadow_color",Color("17424d")); status.add_theme_constant_override("shadow_offset_y",2); canvas.add_child(status)
	get_viewport().size_changed.connect(_layout); _layout()
func _layout():
	var vp:=get_viewport().get_visible_rect().size
	var s:float=min(vp.x/1200.0,vp.y/750.0)
	canvas.scale=Vector2.ONE*s; canvas.size=Vector2(1200,750); canvas.position=(vp-canvas.size*s)*.5
func _style(color:Color)->StyleBoxFlat:
	var s:=StyleBoxFlat.new(); s.bg_color=color; s.set_corner_radius_all(25); s.set_border_width_all(2); s.border_color=Color("fff9e9"); s.shadow_size=3; s.shadow_offset=Vector2(0,4); s.shadow_color=Color(0,.15,.2,.22); return s
func _button(kind:String,tip:String,pos:Vector2)->Button:
	var b:=Button.new(); b.position=pos; b.size=Vector2(50,50); b.focus_mode=Control.FOCUS_NONE; b.tooltip_text=tip; b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal",_style(Color("e9f2d9"))); b.add_theme_stylebox_override("hover",_style(Color("fff6dd"))); var down:=_style(Color("c6e2d2")); down.shadow_size=0; b.add_theme_stylebox_override("pressed",down)
	canvas.add_child(b); var icon:=Icon.new(); icon.kind=kind; icon.position=Vector2(7,7); icon.size=Vector2(36,36); b.add_child(icon)
	b.button_down.connect(func(): b.scale=Vector2(.94,.94)); b.button_up.connect(func(): b.scale=Vector2.ONE); b.mouse_exited.connect(func(): b.scale=Vector2.ONE)
	return b
func set_muted(value:bool):
	if sound_icon: sound_icon.muted=value; sound_icon.queue_redraw()
func set_status(text:String):
	if status: status.text=text
func _process(delta:float):
	elapsed+=delta
	if status: status.modulate.a=lerpf(1.0,.4,clampf((elapsed-10)/3,0,1))
