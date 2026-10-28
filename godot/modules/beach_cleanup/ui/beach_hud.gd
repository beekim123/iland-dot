extends Control
## Independent beach-sign HUD; runtime owns pause and simulation.
signal pause_requested
signal resume_requested
signal return_requested
signal replay_requested
signal next_requested
signal hint_requested
signal ui_clicked
const INK = Color('#294e4b')
const SAND = Color('#f1dfb4')
const TEAL = Color('#438e83')
const RUST = Color('#b9613b')
var canvas: Control
var heading: Label
var counters: Label
var ecology: Label
var cargo: Label
var prompt: Label
var save_warning: Control
var save_warning_text: Label
var slots: Control
var modal: Control
var state: Dictionary = {}
var modal_kind := ''
var _completion: Dictionary = {}
var _before: Texture2D
var _after: Texture2D
var _buttons: Array[Button] = []

class BeachSign extends Panel:
	func _draw() -> void:
		# Shallow end-grain and two pin holes; quiet physical wood, not a card UI.
		var grain := Color(0.48, 0.34, 0.18, 0.13)
		draw_line(Vector2(14, 5), Vector2(size.x - 19, 6), grain, 1.0)
		draw_line(Vector2(21, size.y - 7), Vector2(size.x - 12, size.y - 6), grain, 1.0)
		for x in [6.0, size.x - 6.0]:
			draw_circle(Vector2(x, size.y * 0.5), 1.6, Color('#a78c62'))
			draw_circle(Vector2(x, size.y * 0.5 + 0.6), 0.7, Color('#dec697'))

class CargoTray extends Control:
	var used := 0
	func _draw() -> void:
		for i in range(12):
			var p := Vector2((i % 6) * 27, (i / 6) * 23)
			draw_style_box(_box(Color('#c0ad83'), 4), Rect2(p, Vector2(22, 18)))
			if i < used:
				draw_style_box(_box(Color('#438e83'), 3), Rect2(p + Vector2(3, 3), Vector2(16, 12)))
	static func _box(c: Color, r: int) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = c
		b.set_corner_radius_all(r)
		return b

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var font := load('res://modules/beach_cleanup/ui/shore-sans.otf') as Font
	theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	canvas = Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	_sign(Rect2(18, 16, 220, 76), SAND, canvas)
	heading = _label('拾光海滩', Rect2(30, 18, 202, 27), 22, canvas)
	counters = _label('地面 24   ·   已卸 0', Rect2(30, 45, 202, 22), 18, canvas)
	ecology = _label('生态回归 0 / 3', Rect2(30, 67, 202, 22), 17, canvas)
	_sign(Rect2(742, 16, 200, 86), SAND, canvas)
	cargo = _label('车厢 0 / 12', Rect2(755, 18, 175, 26), 22, canvas)
	slots = CargoTray.new()
	slots.position = Vector2(762, 49)
	slots.size = Vector2(170, 46)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(slots)
	_button('暂停', Rect2(868, 111, 74, 32), canvas, func(): pause_requested.emit())
	_button('找残留', Rect2(784, 111, 76, 32), canvas, func(): hint_requested.emit())
	_sign(Rect2(180, 488, 600, 38), Color('#e7d2a5'), canvas)
	prompt = _label('按住左键 · 夹取车前垃圾', Rect2(192, 487, 576, 21), 18, canvas)
	_label('WASD 驾驶   长按左键 夹取   E 卸货   Esc 暂停', Rect2(192, 506, 576, 20), 16, canvas)
	# An error-only overlay stays above modal dimmers. Hidden for ordinary
	# sessions, so the successful-save HUD renders exactly as before.
	save_warning = Control.new()
	save_warning.name = "PersistentSaveWarning"
	save_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_warning.z_index = 100
	canvas.add_child(save_warning)
	_sign(Rect2(180, 478, 600, 54), SAND, save_warning)
	save_warning_text = _label('', Rect2(192, 482, 576, 44), 18, save_warning)
	save_warning_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_warning_text.add_theme_color_override('font_color', RUST)
	save_warning.hide()
	resized.connect(_layout)
	_layout()
	update_state(state)

func _layout() -> void:
	if not is_instance_valid(canvas): return
	var factor := minf(size.x / 960.0, size.y / 540.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - Vector2(960, 540) * factor) * 0.5
	canvas.size = Vector2(960, 540)

func _sign(rect: Rect2, color: Color, parent: Control) -> Panel:
	var p := BeachSign.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	box.border_color = Color('#ad9064')
	box.border_width_bottom = 2
	box.shadow_color = Color(0.12, 0.19, 0.18, 0.18)
	box.shadow_size = 2
	box.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override('panel', box)
	parent.add_child(p)
	return p

func _label(text: String, rect: Rect2, font_size: int, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.add_theme_color_override('font_color', INK)
	l.add_theme_font_size_override('font_size', font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(l)
	return l

func _button(text: String, rect: Rect2, parent: Control, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_color_override('font_color', Color('#fff5d9'))
	b.add_theme_font_size_override('font_size', 18 if parent == canvas else 20)
	for kind in ['normal', 'hover', 'pressed', 'focus']:
		var box := StyleBoxFlat.new()
		box.bg_color = TEAL.lightened(0.12) if kind == 'hover' else TEAL
		box.set_corner_radius_all(6)
		box.border_color = Color('#fff5d9') if kind == 'focus' else Color('#285b54')
		box.set_border_width_all(3 if kind == 'focus' else 1)
		box.border_width_bottom = 2
		b.add_theme_stylebox_override(kind, box)
	b.pressed.connect(func(): ui_clicked.emit())
	b.pressed.connect(action)
	if parent == canvas: _buttons.append(b)
	parent.add_child(b)
	return b

func update_state(data: Dictionary) -> void:
	state = data.duplicate()
	if not is_instance_valid(heading): return
	heading.text = str(data.get('beach_name', '拾光海滩'))
	counters.text = '地面 %d   ·   已卸 %d' % [data.get('ground_remaining', 0), data.get('delivered', 0)]
	ecology.text = '生态回归 %d / %d' % [data.get('zones_restored', 0), data.get('zones_total', 3)]
	var used := clampi(int(data.get('cargo_used', 0)), 0, 12)
	cargo.text = '车厢 %d / 12' % used
	slots.used = used
	slots.queue_redraw()
	prompt.text = str(data.get('hint_text', ''))
	if prompt.text.is_empty(): prompt.text = '按住左键 · 夹取车前垃圾；留下贝壳与小动物'
	if not str(data.get('capacity_message', '')).is_empty(): prompt.text = str(data['capacity_message'])
	if int(data.get('ground_remaining', 0)) == 0 and used > 0:
		prompt.text = '海滩已清理 · 回卸货站卸下最后一车'
	if bool(data.get('depot_near', false)): prompt.text = '卸货站 · 按 E 卸货，让车厢轻装出发' if used > 0 else '卸货站 · 车厢已空，出发吧'
	var warning := str(data.get('save_status', ''))
	if not warning.is_empty(): prompt.text = warning
	save_warning_text.text = warning
	save_warning.visible = not warning.is_empty()

func set_save_status(value: String) -> void:
	# Saving may fail while paused, when runtime presentation ticks are stopped.
	state['save_status'] = value
	update_state(state)


func hide_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
		modal = null
	modal_kind = ''
	for b in _buttons: b.focus_mode = Control.FOCUS_ALL

func _modal(title: String, kind: String) -> Control:
	hide_modal()
	modal_kind = kind
	for b in _buttons: b.focus_mode = Control.FOCUS_NONE
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.10, 0.20, 0.19, 0.65)
	shade.size = Vector2(960, 540)
	modal.add_child(shade)
	_sign(Rect2(180, 80, 600, 380), SAND, modal)
	_label(title, Rect2(210, 101, 540, 45), 31, modal)
	return modal

func show_pause() -> void:
	var p := _modal('让海风慢慢吹', 'pause')
	_label('进度会保留。想走走，还是继续清理？', Rect2(210, 161, 550, 35), 23, p)
	_button('继续清理', Rect2(210, 227, 540, 49), p, func(): hide_modal(); resume_requested.emit()).grab_focus()
	_button('重玩这片海滩', Rect2(210, 291, 540, 49), p, func(): _confirm('replay'))
	_button('保存并回岛', Rect2(210, 355, 540, 49), p, func(): _confirm('return'))

func _confirm(kind: String) -> void:
	var p := _modal('重新出发？' if kind == 'replay' else '先回岛休息？', 'confirm_' + kind)
	_label('本局进度将重置，海滩会换一种摆放。' if kind == 'replay' else '已拾取、车载与生态进度都会保留。', Rect2(210, 176, 550, 60), 22, p)
	_button('取消', Rect2(210, 328, 255, 57), p, func():
		if not _completion.is_empty(): show_completion(_completion, _before, _after)
		else: show_pause()
	).grab_focus()
	_button('确认重玩' if kind == 'replay' else '保存并回岛', Rect2(485, 328, 265, 57), p, func():
		hide_modal()
		if kind == 'replay':
			_completion.clear()
			replay_requested.emit()
		else: return_requested.emit()
	)

func show_completion(data: Dictionary, before: Texture2D = null, after: Texture2D = null) -> void:
	_completion = data.duplicate()
	_before = before
	_after = after
	var p := _modal('寄一张干净的海滩', 'completion')
	for i in range(2):
		var texture := before if i == 0 else after
		var frame := TextureRect.new()
		frame.position = Vector2(210 + i * 276, 158)
		frame.size = Vector2(264, 148)
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.texture = texture
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(frame)
		_label('来时' if i == 0 else '此刻', Rect2(220 + i * 276, 270, 80, 27), 20, p)
	_label('路程 %.0f 米   ·   卸货 %d 次   ·   生态已回归' % [data.get('distance', 0.0), data.get('unloads', 0)], Rect2(210, 309, 555, 28), 20, p)
	var best_distance := float(data.get('best_distance', 0.0))
	var best_unloads := int(data.get('best_unloads', 0))
	_label('此前最佳  %.0f 米 / %d 次卸货' % [best_distance, best_unloads] if best_distance > 0 else '这是这片海滩的第一张明信片', Rect2(210, 337, 555, 23), 17, p)
	if bool(data.get('has_next', false)):
		_button('下一片海滩', Rect2(210, 367, 190, 53), p, func(): hide_modal(); _completion.clear(); next_requested.emit()).grab_focus()
	else:
		_button('再次清理', Rect2(210, 367, 190, 53), p, func(): _confirm('replay')).grab_focus()
	_button('重玩', Rect2(415, 367, 130, 53), p, func(): _confirm('replay'))
	_button('回岛', Rect2(560, 367, 190, 53), p, func(): _confirm('return'))

func handle_escape() -> void:
	if modal_kind == 'pause':
		hide_modal()
		resume_requested.emit()
	elif modal_kind.begins_with('confirm_'):
		if _completion.is_empty(): show_pause()
		else: show_completion(_completion, _before, _after)
	elif modal_kind.is_empty(): pause_requested.emit()

func reset_session() -> void:
	_completion.clear()
	_before = null
	_after = null
	if is_instance_valid(save_warning): save_warning.hide()
	hide_modal()
