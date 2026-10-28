extends CanvasLayer
signal pause_requested
signal retry_requested
signal exit_requested
signal continue_requested
signal volume_changed(value: float)
var overlay: Control
var bar: HBoxContainer
var score_label: Label
var hint_label: Label
var wind_label: Label
var shield: ColorRect
var modal: PanelContainer
var modal_title: Label
var buttons: VBoxContainer
var status_label: Label
var toast: Label
var toast_time := 0.0
var volume_value := .65
var volume_slider: HSlider
var paused := false
var hosted := false
var _accept_down: Dictionary = {}
var phase := "playing"
var last_snapshot := {}
func _ready() -> void:
	layer=20
	overlay=Control.new(); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(overlay)
	var theme:=Theme.new(); theme.default_font_size=17; theme.default_font=load("res://modules/monkey_vine/ui/fonts/JungleSansSubset.otf")
	for state in ["normal","hover","pressed","focus"]:
		var style:=StyleBoxFlat.new(); style.bg_color=Color("e4efd0") if state=="normal" else Color("b9d88d")
		style.corner_radius_top_left=10; style.corner_radius_top_right=10; style.corner_radius_bottom_left=10; style.corner_radius_bottom_right=10
		style.content_margin_left=14; style.content_margin_right=14; style.content_margin_top=9; style.content_margin_bottom=9
		if state=="focus": style.border_width_left=3; style.border_width_right=3; style.border_width_top=3; style.border_width_bottom=3; style.border_color=Color("487a3b")
		theme.set_stylebox(state,"Button",style)
	for name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]: theme.set_color(name,"Button",Color("203d2d"))
	overlay.theme=theme
	bar=HBoxContainer.new(); bar.position=Vector2(18,14); bar.add_theme_constant_override("separation",16); overlay.add_child(bar)
	score_label=Label.new(); score_label.add_theme_color_override("font_color",Color("203d2d")); bar.add_child(score_label)
	var pause_button:=Button.new(); pause_button.text="Ⅱ 暂停"; pause_button.pressed.connect(_pause_action); bar.add_child(pause_button)
	hint_label=Label.new(); hint_label.text="A / D 移动与借力 · 空格起跳，按住抓藤 · 松开飞出"; hint_label.add_theme_color_override("font_color",Color("203d2d")); hint_label.position=Vector2(18,65); hint_label.add_theme_font_size_override("font_size",14); overlay.add_child(hint_label)
	shield=ColorRect.new(); shield.color=Color(0.05,.15,.08,.25); shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); shield.mouse_filter=Control.MOUSE_FILTER_STOP; overlay.add_child(shield); shield.hide()
	wind_label=Label.new(); wind_label.position=Vector2(18,118); wind_label.add_theme_color_override("font_color",Color("203d2d")); wind_label.add_theme_font_size_override("font_size",14); overlay.add_child(wind_label)
	modal=PanelContainer.new(); modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER); modal.custom_minimum_size=Vector2(300,240); modal.position=Vector2(-150,-120)
	var panel:=StyleBoxFlat.new(); panel.bg_color=Color(.91,.96,.83,.97); panel.corner_radius_top_left=18; panel.corner_radius_top_right=18; panel.corner_radius_bottom_left=18; panel.corner_radius_bottom_right=18; panel.content_margin_left=22; panel.content_margin_right=22; panel.content_margin_top=16; panel.content_margin_bottom=16; modal.add_theme_stylebox_override("panel",panel); overlay.add_child(modal)
	buttons=VBoxContainer.new(); buttons.add_theme_constant_override("separation",8); modal.add_child(buttons)
	modal_title=Label.new(); modal_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; modal_title.add_theme_color_override("font_color",Color("203d2d")); buttons.add_child(modal_title)
	modal.hide()
	toast=Label.new(); toast.position=Vector2(18,94); toast.add_theme_color_override("font_color",Color("203d2d")); toast.add_theme_font_size_override("font_size",19); overlay.add_child(toast)
	# Status is independent of modal and stays above it at all viewport sizes.
	var status_layer:=CanvasLayer.new(); status_layer.layer=100; add_child(status_layer)
	status_label=Label.new(); status_label.theme=theme; status_label.position=Vector2(12,0); status_label.add_theme_color_override("font_color",Color("642719")); status_label.add_theme_color_override("font_shadow_color",Color("fff4d7")); status_label.add_theme_constant_override("shadow_outline_size",0); status_label.add_theme_font_size_override("font_size",14); status_layer.add_child(status_label)
	get_viewport().size_changed.connect(_resize); _resize()
func _resize() -> void:
	var size=get_viewport().get_visible_rect().size
	if status_label: status_label.position.y=size.y-42; status_label.size.x=maxf(100,size.x-24); status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if hint_label:
		hint_label.visible=not paused
		hint_label.add_theme_font_size_override("font_size",12 if size.x<700 else 14)
func set_volume(value: float) -> void:
	volume_value=clampf(value,0,1)
	if is_instance_valid(volume_slider): volume_slider.set_value_no_signal(volume_value)
func set_hosted(value: bool) -> void: hosted=value
func update_snapshot(s: Dictionary) -> void:
	last_snapshot=s
	if wind_label:
		var wind=float(s.get("wind_x",0.0))
		wind_label.text=("微风 →" if wind>0 else "← 微风") if absf(wind)>.03 else ""
	if score_label: score_label.text="香蕉 %d  ·  林区 %d" % [int(s.get("score",0)),int(s.get("segment",0))+1]
	var next_phase=str(s.get("phase","playing"))
	if next_phase!=phase:
		phase=next_phase
		if phase=="segment_clear": toast.text="抵达树屋！前往下一片丛林 →"; toast_time=1.6
		elif phase=="failed": toast.text="回到安全树枝，再试一次…"; toast_time=1.3
		elif not paused: modal.hide(); shield.hide()
func _process(delta: float) -> void:
	if toast_time>0:
		toast_time-=delta
		if toast_time<=0: toast.text=""
func _button(text: String, callback: Callable) -> Button:
	var b:=Button.new(); b.text=text; b.pressed.connect(callback); buttons.add_child(b); return b
func _show_modal(title: String, complete: bool) -> void:
	for c in buttons.get_children():
		if c!=modal_title: c.queue_free()
	modal_title.text=title
	var first: Button
	if complete: first=_button("下一片丛林 →",_continue_action)
	elif paused: first=_button("继续冒险",_continue_action)
	else: first=_button("从检查点重试",_retry_action)
	if paused: _button("从检查点重试",_retry_action)
	_button("返回海岛" if hosted else "关闭游戏",_exit_action)
	if paused:
		var volume:=HSlider.new(); volume.min_value=0; volume.max_value=1; volume.step=.05; volume.value=volume_value; volume_slider=volume; volume.tooltip_text="音乐与音效音量"; volume.custom_minimum_size.y=24; volume.value_changed.connect(func(v): volume_value=v; volume_changed.emit(v)); buttons.add_child(volume)
	modal.show(); shield.show(); first.grab_focus()
func set_paused(value: bool) -> void:
	paused=value
	if paused: _show_modal("丛林小憩",false)
	elif phase=="playing": modal.hide(); shield.hide()
	_resize()
func show_status(message: String) -> void:
	if status_label:
		# The top control legend already states the startup help. Do not duplicate it.
		status_label.text="" if message.begins_with("空格起跳，按住抓藤") else message
func _consume() -> void:
	if is_inside_tree(): get_viewport().set_input_as_handled()
func _pause_action() -> void: _consume(); pause_requested.emit()
func _retry_action() -> void: _consume(); retry_requested.emit()
func _continue_action() -> void: _consume(); continue_requested.emit()
func _exit_action() -> void: _consume(); exit_requested.emit()
func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var accept := code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]
	# A confirm can hide this modal on keydown. Consume its matching release
	# while still mounted; the host owns tail releases after synchronous unload.
	if accept and _accept_down.has(code):
		if not event.pressed: _accept_down.erase(code)
		_consume()
		return
	if modal==null or not modal.visible: return
	if accept:
		var viewport := get_viewport()
		var focus := viewport.gui_get_focus_owner()
		viewport.set_input_as_handled()
		if event.pressed and not event.echo and not _accept_down.has(code):
			_accept_down[code] = true
			if focus is Button:
				# This may synchronously detach the whole module. No tree access after.
				focus.pressed.emit()
		return
	if code in [KEY_A,KEY_D,KEY_W,KEY_S,KEY_LEFT,KEY_RIGHT]:
		_consume()
