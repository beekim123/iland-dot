extends CanvasLayer
## Self-contained UI. No host references. Gameplay is never blocked by onboarding.
signal pause_requested
signal resume_requested
signal restart_requested
signal exit_requested
signal audio_requested

const Ink = preload("res://modules/tide_gulp/ui/tide_ink.gd")
const FONT = preload("res://modules/tide_gulp/ui/tide-book.otf")
const INK = Color("315d68")
const SOFT_INK = Color("3b5f68")
const BUTTON_INK = Color("214c58")
const WARNING_INK = Color("7e4a43")
const MINT = Color("75b9ad")
const GOLD = Color("d7b15f")
const CORAL = Color("c97d73")
const STAGE_NAMES = ["小小水滴", "银鳍幼鱼", "珊瑚游鱼", "逐浪大鱼", "深蓝领航", "海洋朋友"]

var surface: Control
var blocker: Control
var buttons: Dictionary = {}
var state: Dictionary = {}
var modal := ""
var previous_modal := ""
var result: Dictionary = {}
var intro_remaining := 13.0
var growth_remaining := 0.0
var growth_text := ""
var warning_remaining := 0.0
var warning_text := ""
var _clock := 0.0
var _last_action_ms := -1000
var _action_pending := false
var _layout_size := Vector2.ZERO
var _ui_scale := 1.0
var _view := Vector2(1280, 800)
var _modal_rect := Rect2()

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	surface = Ink.new()
	surface.name = "WatercolourPaper"
	surface.owner_hud = self
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(surface)
	blocker = Control.new()
	blocker.name = "ModalInputShield"
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	blocker.visible = false
	surface.add_child(blocker)
	_make_button("pause", "暂停", _pause)
	_make_button("exit", "回岛", request_exit_confirm)
	_make_button("resume", "继续游", _resume)
	_make_button("again", "再游一次", _restart)
	_make_button("leave", "回到小岛", _exit)
	_make_button("cancel", "继续游", _cancel_exit)
	_make_button("confirm", "回到小岛", _exit)
	_make_button("audio", "声音 · 开", _audio)
	_make_button("help", "玩法小纸条", _help)
	_make_button("close_help", "明白啦", _close_help)
	_layout()
	_refresh_visibility()

func _make_button(id: String, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.name = "Button_" + id
	b.text = text
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 18)
	# Explicitly override every state: the default theme uses white for focused
	# text, which made the auto-focused result action disappear on pale paper.
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(color_name, BUTTON_INK)
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("cde4dd") if style_name == "normal" else Color("bad8ce")
		if style_name == "focus":
			style.bg_color = Color(0, 0, 0, 0)
			style.border_color = Color("547a88")
			style.set_border_width_all(2)
		else:
			style.border_color = Color("83aaa7")
			style.set_border_width_all(1)
			if style_name == "pressed": style.bg_color = Color("a4c9c2")
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 17
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 10
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 5
		style.content_margin_bottom = 5
		b.add_theme_stylebox_override(style_name, style)
	b.pressed.connect(callback)
	surface.add_child(b)
	buttons[id] = b

func _process(delta: float) -> void:
	_clock += delta
	if modal.is_empty() and not bool(state.get("paused", false)):
		intro_remaining = maxf(0.0, intro_remaining - delta)
		growth_remaining = maxf(0.0, growth_remaining - delta)
		warning_remaining = maxf(0.0, warning_remaining - delta)
	if is_instance_valid(surface):
		if _layout_size != get_viewport().get_visible_rect().size:
			_layout()
		surface.queue_redraw()

func update_state(value: Dictionary) -> void:
	state.merge(value, true)
	if is_instance_valid(surface):
		buttons.audio.text = "声音 · 开" if bool(state.get("audio", true)) else "声音 · 关"
		surface.queue_redraw()

func show_intro() -> void:
	intro_remaining = 13.0

func show_pause() -> void:
	_set_modal("pause")

func hide_modal() -> void:
	_set_modal("")

func show_result(value: Dictionary) -> void:
	result = value.duplicate(true)
	intro_remaining = 0.0
	growth_remaining = 0.0
	warning_remaining = 0.0
	_set_modal("result")

func show_growth(stage: int, stage_name: String = "") -> void:
	var title := stage_name if not stage_name.is_empty() else str(STAGE_NAMES[clampi(stage - 1, 0, 5)])
	growth_text = "长大啦 · " + title
	growth_remaining = 3.5

func show_current_warning(message: String) -> void:
	if message.is_empty(): return
	warning_text = message
	warning_remaining = 3.2

func request_exit_confirm() -> void:
	if modal == "result":
		_exit()
		return
	if modal == "confirm": return
	previous_modal = modal
	if modal.is_empty(): pause_requested.emit()
	_set_modal("confirm")
	# Pause's leave button and confirmation share a location: a double click
	# must not turn the first request into an accidental irreversible exit.
	_last_action_ms = Time.get_ticks_msec()

func handle_escape() -> bool:
	if modal == "confirm":
		_cancel_exit()
		return true
	if modal == "help":
		_close_help()
		return true
	return false

func _set_modal(value: String) -> void:
	modal = value
	_action_pending = false
	if not is_instance_valid(surface): return
	_refresh_visibility()
	_layout()
	var focus_id := "resume" if modal == "pause" else "again" if modal == "result" else "cancel" if modal == "confirm" else "close_help" if modal == "help" else ""
	for b in buttons.values():
		b.disabled = false
		b.release_focus()
	if not focus_id.is_empty(): buttons[focus_id].call_deferred("grab_focus")
	surface.queue_redraw()

func _refresh_visibility() -> void:
	blocker.visible = not modal.is_empty()
	for key in buttons:
		buttons[key].visible = false
	buttons.pause.visible = modal.is_empty()
	buttons.exit.visible = modal.is_empty()
	match modal:
		"pause":
			for id in ["resume", "leave", "audio", "help"]: buttons[id].visible = true
		"result":
			buttons.again.visible = true
			buttons.leave.visible = true
		"confirm":
			buttons.cancel.visible = true
			buttons.confirm.visible = true
		"help":
			buttons.close_help.visible = true

func _can_act() -> bool:
	var now := Time.get_ticks_msec()
	if _action_pending or now - _last_action_ms < 180: return false
	_last_action_ms = now
	return true

func _pause() -> void:
	if not _can_act(): return
	show_pause()
	pause_requested.emit()

func _resume() -> void:
	if not _can_act(): return
	hide_modal()
	resume_requested.emit()

func _restart() -> void:
	if not _can_act(): return
	_action_pending = true
	buttons.again.disabled = true
	restart_requested.emit()

func _exit() -> void:
	if modal == "pause":
		request_exit_confirm()
		return
	if not _can_act(): return
	_action_pending = true
	buttons.confirm.disabled = true
	buttons.leave.disabled = true
	exit_requested.emit()

func _cancel_exit() -> void:
	if not _can_act(): return
	var restore := previous_modal
	_set_modal(restore)
	if restore.is_empty(): resume_requested.emit()

func _audio() -> void:
	if not _can_act(): return
	var enabled := not bool(state.get("audio", true))
	update_state({"audio": enabled})
	audio_requested.emit()

func _help() -> void:
	if not _can_act(): return
	_set_modal("help")

func _close_help() -> void:
	if not _can_act(): return
	_set_modal("pause")

func _layout() -> void:
	_layout_size = get_viewport().get_visible_rect().size
	_ui_scale = clampf(minf(_layout_size.x / 920.0, _layout_size.y / 540.0), 0.5, 1.0)
	_view = _layout_size / _ui_scale
	surface.size = _view
	surface.scale = Vector2.ONE * _ui_scale
	blocker.size = _view
	_put_button("pause", Rect2(_view.x - 176, 24, 70, 39))
	_put_button("exit", Rect2(_view.x - 98, 24, 70, 39))
	var h := 390.0 if modal == "result" else 360.0 if modal == "help" else 290.0 if modal == "pause" else 245.0
	_modal_rect = Rect2((_view - Vector2(550, h)) / 2.0, Vector2(550, h))
	var p := _modal_rect.position
	var y := p.y + h - 63
	_put_button("resume", Rect2(p.x + 40, y, 220, 43))
	_put_button("leave", Rect2(p.x + 288, y, 220, 43))
	_put_button("again", Rect2(p.x + 40, y, 220, 43))
	_put_button("cancel", Rect2(p.x + 40, y, 220, 43))
	_put_button("confirm", Rect2(p.x + 288, y, 220, 43))
	_put_button("audio", Rect2(p.x + 40, p.y + 143, 220, 40))
	_put_button("help", Rect2(p.x + 288, p.y + 143, 220, 40))
	_put_button("close_help", Rect2(p.x + 165, y, 220, 43))

func _put_button(id: String, rect: Rect2) -> void:
	buttons[id].position = rect.position
	buttons[id].size = rect.size

func _text(c: Control, content: String, pos: Vector2, font_size: int, color: Color = INK) -> void:
	c.draw_string(FONT, pos, content, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _center(c: Control, content: String, y: float, font_size: int, color: Color = INK) -> void:
	_text(c, content, Vector2((_view.x - FONT.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) / 2.0, y), font_size, color)

func _paper(c: Control, r: Rect2, tint: Color, seed_offset: int = 0) -> void:
	# Irregular pigment edges and a few fine paper fibres, not a polished app card.
	var p := PackedVector2Array()
	for i in range(14):
		var x := r.position.x + float(i) / 13.0 * r.size.x
		p.append(Vector2(x, r.position.y + sin(float(i * 3 + seed_offset)) * 2.1))
	for i in range(13, -1, -1):
		var x := r.position.x + float(i) / 13.0 * r.size.x
		p.append(Vector2(x, r.end.y + sin(float(i * 5 + seed_offset)) * 2.4))
	c.draw_colored_polygon(p, tint)
	var edge := tint.darkened(0.13)
	edge.a = 0.42
	c.draw_polyline(p, edge, 1.0, true)
	for i in range(17):
		var x := r.position.x + fmod(float(i * 79 + seed_offset * 3), r.size.x)
		var y := r.position.y + fmod(float(i * 37 + seed_offset * 7), r.size.y)
		c.draw_line(Vector2(x, y), Vector2(minf(x + 5, r.end.x), y + 0.6), Color(0.22, 0.38, 0.43, 0.045), 0.7, true)

func _symbol(c: Control, pos: Vector2, relation: String, s: float = 1.0) -> void:
	var stroke := INK
	if relation == "food":
		# Open mouth: visibly different even without colour vision.
		c.draw_arc(pos, 8 * s, 0.65, TAU - 0.65, 20, stroke, 2 * s, true)
		c.draw_line(pos + Vector2(6.4, -4.8) * s, pos, stroke, 2 * s, true)
		c.draw_line(pos, pos + Vector2(6.4, 4.8) * s, stroke, 2 * s, true)
		c.draw_circle(pos + Vector2(11, 0) * s, 1.7 * s, GOLD)
	elif relation == "peer":
		c.draw_line(pos + Vector2(-7, -3) * s, pos + Vector2(7, -3) * s, stroke, 2 * s, true)
		c.draw_line(pos + Vector2(-7, 3) * s, pos + Vector2(7, 3) * s, stroke, 2 * s, true)
	else:
		var points := PackedVector2Array([pos + Vector2(0, -9) * s, pos + Vector2(9, 7) * s, pos + Vector2(-9, 7) * s, pos + Vector2(0, -9) * s])
		c.draw_polyline(points, CORAL.darkened(0.22), 2 * s, true)
		c.draw_line(pos + Vector2(0, -3) * s, pos + Vector2(0, 1) * s, INK, 1.5 * s, true)
		c.draw_circle(pos + Vector2(0, 4) * s, 1 * s, INK)

func _fish(c: Control, pos: Vector2, scale_factor: float, tint: Color) -> void:
	var body := PackedVector2Array()
	for i in range(25):
		var a := float(i) / 24.0 * TAU
		body.append(pos + Vector2(cos(a) * 28, sin(a) * 14) * scale_factor)
	c.draw_colored_polygon(body, tint)
	c.draw_colored_polygon(PackedVector2Array([pos + Vector2(-22, 0) * scale_factor, pos + Vector2(-42, -15) * scale_factor, pos + Vector2(-39, 15) * scale_factor]), tint.darkened(0.08))
	c.draw_polyline(body, Color(0.2, 0.36, 0.39, 0.38), 1.2, true)
	c.draw_circle(pos + Vector2(15, -3) * scale_factor, 2.4 * scale_factor, INK)

func draw_ink(c: Control) -> void:
	var stage := clampi(int(state.get("stage", 1)), 1, 6)
	var name := str(state.get("stage_name", STAGE_NAMES[stage - 1]))
	# Three small HUD islands. The sea remains the largest readable area.
	_paper(c, Rect2(22, 20, 278, 122), Color(0.9, 0.96, 0.92, 0.92), 1)
	_text(c, name, Vector2(38, 45), 19)
	_text(c, "%d / 6" % stage, Vector2(234, 44), 15, SOFT_INK)
	for i in range(6):
		var p := Vector2(48 + i * 37, 66)
		c.draw_circle(p, 7, MINT if i < stage else Color(0.58, 0.72, 0.73, 0.28))
		if i == stage - 1: c.draw_arc(p, 10, -PI / 2, TAU - PI / 2, 30, INK, 1.0, true)
	var progress := clampf(float(state.get("stage_progress", 0.0)), 0.0, 1.0)
	c.draw_line(Vector2(39, 88), Vector2(190, 88), Color("bdd1cc"), 4, true)
	if progress > 0: c.draw_line(Vector2(39, 88), Vector2(39 + progress * 151, 88), MINT.darkened(0.12), 4, true)
	_text(c, "%d 分" % int(state.get("score", 0)), Vector2(212, 94), 16)
	var biome := str(state.get("biome", "晴光浅礁"))
	var phase := str(state.get("tide_phase", "calm"))
	var phase_text := "平潮" if phase == "calm" else "潮将至" if phase == "warning" else "流潮"
	_text(c, biome, Vector2(39, 126), 14, SOFT_INK)
	_text(c, "%s %02d" % [phase_text, ceili(float(state.get("tide_remaining", 0.0)))], Vector2(160, 126), 14, INK if phase != "warning" else WARNING_INK)
	var current_direction: Vector2 = state.get("tide_direction", Vector2.RIGHT)
	var arrow := Vector2(271, 121)
	var direction := Vector2(signf(current_direction.x), -signf(current_direction.y)).normalized()
	if direction == Vector2.ZERO: direction = Vector2.RIGHT
	var normal := direction.orthogonal()
	c.draw_line(arrow - direction * 9, arrow + direction * 9, INK, 1.4, true)
	c.draw_line(arrow + direction * 9, arrow + direction * 3 + normal * 4, INK, 1.4, true)
	c.draw_line(arrow + direction * 9, arrow + direction * 3 - normal * 4, INK, 1.4, true)
	_paper(c, Rect2(_view.x - 186, 16, 166, 57), Color(0.88, 0.95, 0.94, 0.85), 3)
	var dash_box := Rect2(_view.x - 170, _view.y - 94, 148, 70)
	_paper(c, dash_box, Color(0.87, 0.94, 0.92, 0.90), 8)
	var dash_pos := dash_box.position + Vector2(29, 33)
	var ready := bool(state.get("dash_ready", true))
	var cooldown := clampf(float(state.get("dash_cooldown_ratio", 0.0)), 0.0, 1.0)
	c.draw_arc(dash_pos, 17, 0, TAU, 40, Color("aec7c6"), 2.2, true)
	c.draw_arc(dash_pos, 17, -PI / 2, -PI / 2 + TAU * (1.0 if ready else 1.0 - cooldown), 40, MINT.darkened(0.22), 3, true)
	c.draw_polyline(PackedVector2Array([dash_pos + Vector2(-7, -5), dash_pos + Vector2(0, 0), dash_pos + Vector2(-7, 5)]), INK, 2, true)
	c.draw_polyline(PackedVector2Array([dash_pos + Vector2(0, -5), dash_pos + Vector2(7, 0), dash_pos + Vector2(0, 5)]), INK, 2, true)
	_text(c, "冲刺" if ready else "歇一小会", dash_box.position + Vector2(58, 31), 17)
	var mode_text := "左键 · 鼠标" if str(state.get("input_mode", "mouse")) == "mouse" else "空格 · 键盘"
	_text(c, mode_text, dash_box.position + Vector2(58, 52), 14, SOFT_INK)
	if modal.is_empty():
		_draw_world_cues(c)
		if growth_remaining > 0:
			_center(c, growth_text, 155, 24, INK)
		elif warning_remaining > 0:
			_center(c, warning_text, 143, 19, INK)
		elif not str(state.get("current_warning", "")).is_empty():
			_center(c, str(state.current_warning), 143, 18, INK)
		if (intro_remaining > 0 or not str(state.get("controls_hint", "")).is_empty()) and bool(state.get("controls_hint_visible", true)):
			_draw_intro(c)
	else:
		_draw_modal(c)

func _draw_world_cues(c: Control) -> void:
	var shown := 0
	for tag in state.get("screen_tags", []):
		if shown >= 5: break
		if not tag is Dictionary: continue
		var pos: Vector2 = tag.get("pos", Vector2.ZERO) / _ui_scale
		if pos.x < 18 or pos.y < 160 or pos.x > _view.x - 18 or pos.y > _view.y - 105: continue
		_symbol(c, pos, str(tag.get("relation", "peer")), 0.83)
		shown += 1
	var warning_count := 0
	for cue in state.get("warnings", []):
		if warning_count >= 2: break
		if not cue is Dictionary: continue
		var p: Vector2 = cue.get("pos", Vector2.ZERO) / _ui_scale
		p.x = clampf(p.x, 18, _view.x - 18)
		p.y = clampf(p.y, 138, _view.y - 112)
		_symbol(c, p, "danger", 1.1)
		warning_count += 1

func _draw_intro(c: Control) -> void:
	var p := Vector2(24, _view.y - 117)
	_paper(c, Rect2(p, Vector2(374, 91)), Color(0.92, 0.96, 0.92, 0.90), 11)
	if intro_remaining > 0:
		_text(c, "鼠标指向游动 · 左键冲刺", p + Vector2(15, 26), 17)
		_text(c, "也可 WASD + 空格 · Esc 暂停", p + Vector2(15, 49), 14, SOFT_INK)
	else:
		var hint := str(state.get("controls_hint", "寻找比你小的鱼，慢慢长大。"))
		c.draw_multiline_string(FONT, p + Vector2(15, 23), hint, HORIZONTAL_ALIGNMENT_LEFT, 344, 15, 2, INK)
	for item in [["food", "吃小鱼", 25], ["peer", "同级绕行", 132], ["danger", "大鱼要躲", 254]]:
		_symbol(c, p + Vector2(float(item[2]), 71), str(item[0]), 0.75)
		_text(c, str(item[1]), p + Vector2(float(item[2]) + 17, 77), 14, SOFT_INK)

func _draw_modal(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, _view), Color(0.08, 0.22, 0.27, 0.30))
	_paper(c, _modal_rect.grow(6), Color(0.54, 0.73, 0.75, 0.36), 22)
	_paper(c, _modal_rect, Color("e1eeea"), 3)
	var p := _modal_rect.position
	_fish(c, p + Vector2(472, 49), 0.65, Color("91c4bd"))
	match modal:
		"pause":
			_text(c, "在这里歇一会", p + Vector2(38, 59), 29)
			_text(c, "小鱼与洋流，都等着你。", p + Vector2(40, 102), 17, SOFT_INK)
			if not str(state.get("save_status", "")).is_empty():
				_text(c, str(state.save_status), p + Vector2(40, 211), 14, WARNING_INK)
		"result":
			_text(c, "这一程，游得真好", p + Vector2(38, 57), 28)
			var reason := str(result.get("reason", "下次再去更远的海吧。"))
			if reason.length() > 28: reason = reason.substr(0, 28) + "…"
			_text(c, reason, p + Vector2(40, 94), 17, SOFT_INK)
			_text(c, "%d 分" % int(result.get("score", 0)), p + Vector2(40, 155), 35)
			_text(c, "本次旅程", p + Vector2(42, 182), 14, SOFT_INK)
			_text(c, _time(float(result.get("survival_time", 0))), p + Vector2(302, 155), 31)
			_text(c, "生存时间", p + Vector2(304, 182), 14, SOFT_INK)
			c.draw_line(p + Vector2(40, 206), p + Vector2(508, 206), Color("a7c3c0"), 1, true)
			var high_stage := clampi(int(result.get("stage", 1)), 1, 6)
			_text(c, "最高成长  %d / 6" % high_stage, p + Vector2(40, 242), 18)
			_text(c, "个人最佳  %d 分" % int(result.get("best_score", 0)), p + Vector2(40, 274), 18)
			_text(c, "每次长大，都算数。", p + Vector2(304, 274), 14, SOFT_INK)
			var save_note := str(result.get("save_status", state.get("save_status", "")))
			if not save_note.is_empty():
				_text(c, save_note, p + Vector2(40, 306), 14, WARNING_INK)
		"confirm":
			_text(c, "要回到小岛吗？", p + Vector2(38, 58), 28)
			var exit_note := "这一程会结束，已获得的最佳纪录会留下。" if str(state.get("save_status", "")).is_empty() else "这一程会结束。当前记录无法写入本地。"
			_text(c, exit_note, p + Vector2(40, 111), 17, SOFT_INK)
		"help":
			_text(c, "小鱼的游泳纸条", p + Vector2(38, 57), 28)
			_text(c, "鼠标指向游动，左键冲刺。", p + Vector2(40, 101), 18)
			_text(c, "也可 WASD 移动，空格冲刺，Esc 暂停。", p + Vector2(40, 132), 17, SOFT_INK)
			for row in [["food", "吃小鱼，慢慢长大。", 177], ["peer", "同级鱼吃不了，轻轻绕开。", 213], ["danger", "尖角标记是天敌，冲刺离开。", 249]]:
				_symbol(c, p + Vector2(53, float(row[2]) - 6), str(row[0]))
				_text(c, str(row[1]), p + Vector2(78, float(row[2])), 17)

func _time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	return "%d:%02d" % [total / 60, total % 60]

func get_debug_layout() -> Dictionary:
	return {"viewport": _layout_size, "virtual_size": _view, "scale": _ui_scale, "modal": modal, "modal_rect": _modal_rect, "click_through": surface.mouse_filter == Control.MOUSE_FILTER_IGNORE, "blocker_visible": blocker.visible}
