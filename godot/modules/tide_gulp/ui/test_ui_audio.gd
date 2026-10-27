extends SceneTree
## Headless structural/state/input regression. Actual screenshots are separate QA.
var failures: Array[String] = []
var event_counts := {"pause":0, "resume":0, "restart":0, "exit":0, "audio":0}

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func count_event(event: String) -> void:
	event_counts[event] += 1

func luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return 0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b

func contrast(foreground: Color, background: Color) -> float:
	var light := maxf(luminance(foreground), luminance(background))
	var dark := minf(luminance(foreground), luminance(background))
	return (light + 0.05) / (dark + 0.05)

func click_at(pos: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = pos
		event.global_position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)

func run() -> void:
	var HUD = load("res://modules/tide_gulp/ui/tide_hud.gd")
	var Audio = load("res://modules/tide_gulp/audio/tide_audio.gd")
	if not HUD or not Audio:
		push_error("Tide UI / audio scripts did not load")
		quit(1)
		return
	var hud = HUD.new()
	root.add_child(hud)
	for event in ["pause", "resume", "restart", "exit", "audio"]:
		hud.connect(event + "_requested", count_event.bind(event))
	await process_frame
	# Focus/hover+pressed/disabled states must never inherit white from the theme.
	for id in hud.buttons:
		var button: Button = hud.buttons[id]
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
			expect(button.has_theme_color_override(color_name), "%s explicitly defines %s" % [id,color_name])
			for style_name in ["normal", "hover", "pressed", "disabled"]:
				var background: Color = button.get_theme_stylebox(style_name).bg_color
				expect(contrast(button.get_theme_color(color_name), background) >= 4.5, "%s/%s/%s meets 4.5:1 text contrast" % [id,color_name,style_name])
			expect(button.get_theme_font_size("font_size") >= 18, "%s keeps readable button text" % id)
	# Worst-case pale HUD paper composited over black is darker than any sea.
	var dark_paper := Color(0.87 * 0.90, 0.94 * 0.90, 0.92 * 0.90)
	for foreground in [HUD.INK, HUD.SOFT_INK, HUD.WARNING_INK]:
		expect(contrast(foreground, dark_paper) >= 4.5, "Body text retains 4.5:1 contrast on translucent HUD paper")
	expect(hud.modal.is_empty(), "Onboarding must not block gameplay")
	expect(hud.get_debug_layout().click_through, "Full-screen gameplay surface must pass mouse input")
	expect(not hud.blocker.visible, "Gameplay input shield should be hidden")
	for dimensions in [Vector2i(1280,800), Vector2i(920,540), Vector2i(640,360), Vector2i(1920,1080)]:
		root.size = dimensions
		await process_frame
		hud.update_state({"stage":6,"stage_name":"大海朋友","stage_progress":1.0,"score":123456,"dash_ready":false,"dash_cooldown_ratio":0.7})
		for mode in ["pause", "help", "confirm", "result"]:
			hud._set_modal(mode)
			await process_frame
			var layout: Dictionary = hud.get_debug_layout()
			var rect: Rect2 = layout.modal_rect
			var viewport_rect := Rect2(Vector2.ZERO, layout.virtual_size)
			expect(viewport_rect.encloses(rect), "%s modal must fit %s" % [mode,dimensions])
			for id in hud.buttons:
				var b: Button = hud.buttons[id]
				if b.visible:
					expect(viewport_rect.encloses(b.get_rect()), "%s button must fit %s" % [id,dimensions])
					expect(b.get_combined_minimum_size().y <= b.size.y, "%s has no default-theme minheight overflow" % id)
					expect(b.mouse_filter == Control.MOUSE_FILTER_STOP, "%s must intercept clicks" % id)
		hud.hide_modal()
	hud._last_action_ms = -1000
	hud.request_exit_confirm()
	expect(hud.modal == "confirm" and event_counts.pause == 1, "In-game exit must pause and ask once")
	hud.request_exit_confirm()
	expect(event_counts.pause == 1, "Repeated exit must not duplicate pause")
	hud._last_action_ms = -1000
	expect(hud.handle_escape(), "Escape dismisses exit confirmation")
	expect(hud.modal.is_empty() and event_counts.resume == 1, "Cancel active-game exit resumes")
	hud.show_pause()
	await process_frame
	expect(hud.buttons.resume.has_focus(), "Pause has a useful keyboard focus")
	hud.request_exit_confirm()
	hud._exit()
	expect(event_counts.exit == 0, "Double click opening confirmation must not confirm exit")
	hud._last_action_ms = -1000
	hud._cancel_exit()
	expect(hud.modal == "pause" and event_counts.resume == 1, "Cancel paused-game exit stays paused")
	hud._set_modal("help")
	hud._last_action_ms = -1000
	expect(hud.handle_escape() and hud.modal == "pause", "Escape from help returns to pause")
	hud.show_result({"score":500,"survival_time":83.4,"max_stage":4,"best_score":700,"reason":"躲开大鱼，下次再来。"})
	hud._last_action_ms = -1000
	hud._restart()
	hud._restart()
	expect(event_counts.restart == 1, "Repeated restart sends one signal")
	hud.show_result({"score":100})
	expect(not hud.buttons.again.disabled, "A reused HUD must reset restart disabled state")
	hud._last_action_ms = -1000
	hud._exit()
	hud._exit()
	expect(event_counts.exit == 1, "Repeated exit sends one signal")
	hud.hide_modal()
	await process_frame
	expect(not hud.blocker.visible and not hud.buttons.resume.has_focus(), "Dismissed modal must release focus and input shield")
	var probe = load("res://modules/tide_gulp/ui/test_input_probe.gd").new()
	root.add_child(probe)
	click_at(Vector2(root.size) * 0.5)
	expect(probe.unhandled_clicks == 1, "Real click in sea must reach gameplay input")
	hud._last_action_ms = -1000
	click_at(hud.buttons.pause.get_global_rect().get_center())
	expect(hud.modal == "pause" and probe.unhandled_clicks == 1, "Real pause button click must not leak dash input")
	click_at(Vector2(10, root.size.y / 2))
	expect(probe.unhandled_clicks == 1, "Modal backdrop must consume clicks")
	hud.hide_modal()
	probe.queue_free()
	hud.show_growth(6, "大海朋友")
	hud.show_current_warning("洋流将至")
	expect(hud.growth_remaining > 0 and hud.warning_remaining > 0, "Transient growth/tide messages are armed")
	var audio = Audio.new()
	root.add_child(audio)
	await process_frame
	expect(audio.get_debug_state().voice_count == 4, "Audio has a bounded voice pool")
	var stream: AudioStreamWAV = audio._music.stream
	expect(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == 24 * 44100, "Music loops the full exact-length composition")
	for event in ["swallow", "growth", "dash", "warning", "tide", "death", "button"]:
		audio.play(event)
	audio.set_paused(true)
	expect(audio.get_debug_state().music_paused, "Pause silences music")
	for voice in audio._voices:
		expect(not voice.playing, "Pause silences SFX")
	audio.play("growth")
	for voice in audio._voices:
		expect(not voice.playing, "Paused state cannot start SFX")
	audio.set_paused(false)
	audio.set_enabled(false)
	expect(audio.get_debug_state().music_paused, "Audio off silences music")
	audio.set_enabled(true)
	audio.stop_all()
	expect(not audio._music.playing, "Exit stops music")
	audio.queue_free()
	hud.queue_free()
	await process_frame
	stream = null
	# Audio server releases playback references on its next mix tick, not render frame.
	await create_timer(0.15).timeout
	if failures.is_empty():
		print("TIDE_UI_AUDIO_OK: responsive layouts, click-through, focus, pause/exit/restart repeated actions, audio lifecycle")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)
