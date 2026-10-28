extends CanvasLayer
## Compact independent shell controls. The menu is not a fifth world portal.
signal catalog_requested
signal shuffle_requested
var catalog_button: Button
var shuffle_button: Button
var notice: Label
var root_control: Control

func _ready() -> void:
	layer = 12
	root_control = Control.new(); root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root_control)
	var strip := HBoxContainer.new(); root_control.add_child(strip)
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	strip.offset_left = 24; strip.offset_top = -78; strip.offset_bottom = -28
	strip.add_theme_constant_override("separation",10)
	catalog_button = _button("全部小游戏",true); strip.add_child(catalog_button)
	shuffle_button = _button("换一组",false); strip.add_child(shuffle_button)
	catalog_button.pressed.connect(func(): catalog_requested.emit())
	shuffle_button.pressed.connect(func(): shuffle_requested.emit())
	notice = Label.new(); root_control.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	notice.offset_left = 26; notice.offset_top = -112; notice.offset_right = 676; notice.offset_bottom = -86
	notice.add_theme_font_override("font",load("res://hub/hub-ui.otf"))
	notice.add_theme_font_size_override("font_size",16)
	notice.add_theme_color_override("font_color",Color("fff4d6"))
	notice.add_theme_color_override("font_shadow_color",Color("183747"))
	notice.add_theme_constant_override("shadow_offset_y",2)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _button(title: String, primary: bool) -> Button:
	var button := Button.new(); button.text = title
	button.custom_minimum_size = Vector2(156 if primary else 112,50)
	button.add_theme_font_override("font",load("res://hub/hub-ui.otf"))
	button.add_theme_font_size_override("font_size",19)
	button.add_theme_color_override("font_color",Color("173d4a") if primary else Color("fff4de"))
	button.add_theme_color_override("font_hover_color",Color("173d4a"))
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("fff1cb") if primary else Color("235b68")
		if state == "hover": style.bg_color = Color("b8f0dc")
		if state == "pressed": style.bg_color = Color("8adbc6")
		style.set_corner_radius_all(18); style.content_margin_left = 18; style.content_margin_right = 18
		style.content_margin_top = 11; style.content_margin_bottom = 11
		style.shadow_color = Color(0.06,0.2,0.23,.24); style.shadow_size = 5
		if state == "focus": style.bg_color = Color(0,0,0,0); style.set_border_width_all(3); style.border_color = Color("fff8e6")
		button.add_theme_stylebox_override(state,style)
	return button

func set_status(text: String) -> void:
	if is_instance_valid(notice): notice.text = text

func set_shuffle_enabled(value: bool) -> void:
	if is_instance_valid(shuffle_button): shuffle_button.disabled = not value
