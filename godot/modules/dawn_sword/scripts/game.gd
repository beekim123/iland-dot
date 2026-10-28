extends Node2D
signal exit_requested
const Rules = preload("res://modules/dawn_sword/scripts/rules.gd")
const Storage = preload("res://modules/dawn_sword/scripts/storage.gd")
const ROOT = "res://modules/dawn_sword/"
var rules = Rules.new()
var storage = Storage.new()
var started: bool = false
var hosted: bool = false
var exiting: bool = false
var paused: bool = false
var menu: String = "title"
var accumulator: float = 0.0
var held: Dictionary = {}
var pressed: Dictionary = {}
var settings: Dictionary = {"volume":0.7,"fullscreen":false,"shake":true,"flash":0.5,"subtitles":true,"difficulty":"adventure","keys":{}}
var keys: Dictionary = {"left":KEY_A,"right":KEY_D,"jump":KEY_SPACE,"attack":KEY_J,"roll":KEY_K,"guard":KEY_L,"dawn":KEY_U,"heal":KEY_H,"interact":KEY_E,"up":KEY_W,"down":KEY_S,"pause":KEY_ESCAPE}
var joy: Dictionary = {JOY_BUTTON_A:"jump",JOY_BUTTON_X:"attack",JOY_BUTTON_B:"roll",JOY_BUTTON_LEFT_SHOULDER:"guard",JOY_BUTTON_Y:"dawn",JOY_BUTTON_RIGHT_SHOULDER:"interact",JOY_BUTTON_BACK:"heal",JOY_BUTTON_START:"pause",JOY_BUTTON_DPAD_LEFT:"left",JOY_BUTTON_DPAD_RIGHT:"right",JOY_BUTTON_DPAD_UP:"up",JOY_BUTTON_DPAD_DOWN:"down"}
var ui: CanvasLayer
var panel: PanelContainer
var box: VBoxContainer
var font: Font
var manifest: Dictionary = {}
var textures: Dictionary = {}
var camera_x: float = 0.0
var save_status: String = ""
var remap: String = ""
var audio_node: Node
var previous_mode: String = "play"
var previous_level: String = ""
var saved: Dictionary = {}
var shake_time: float = 0.0
var last_device: String = "keyboard"
var previous_window_mode: int = DisplayServer.WINDOW_MODE_WINDOWED
var reviewing: bool = false
var settings_return: String = "title"
var first_button_set: bool = false
var parry_visual_time: float = 0.0
var previous_actor_states: Dictionary = {}
var landing_visual_times: Dictionary = {}

func _ready() -> void:
	if ResourceLoader.exists(ROOT+"fonts/story.ttf"): font = load(ROOT+"fonts/story.ttf")
	else: font = ThemeDB.fallback_font
	var art_path: String = ROOT+"art/manifest.json"
	if FileAccess.file_exists(art_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(art_path))
		if parsed is Dictionary: manifest = parsed
	ui = CanvasLayer.new()
	add_child(ui)
	if ResourceLoader.exists(ROOT+"audio/audio_director.gd"):
		audio_node = load(ROOT+"audio/audio_director.gd").new()
		add_child(audio_node)
	call_deferred("_auto_start")

func _auto_start() -> void:
	if not started: start({})

func start(context: Dictionary = {}) -> void:
	if started: return
	started = true
	hosted = not context.is_empty() or not exit_requested.get_connections().is_empty()
	previous_window_mode = DisplayServer.window_get_mode()
	if not hosted: get_tree().auto_accept_quit = false
	var result: Dictionary = storage.load_profile()
	if result.ok:
		saved = result.data
		settings.merge(saved.get("settings",{}),true)
		keys.merge(settings.get("keys",{}),true)
	else: save_status = result.error
	_apply_settings()
	if audio_node: audio_node.start("theme")
	_show_menu("title")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: request_exit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and started and menu == "":
		_clear_input()
		_show_menu("pause")

func _clear_input() -> void:
	held.clear()
	pressed.clear()
	accumulator = 0.0

func _input(event: InputEvent) -> void:
	if not started or exiting: return
	if remap != "" and event is InputEventKey and event.pressed and not event.echo:
		var old_key: int = int(keys[remap])
		for other_action in keys:
			if other_action != remap and int(keys[other_action]) == event.physical_keycode: keys[other_action] = old_key
		keys[remap] = event.physical_keycode
		settings.keys = keys.duplicate()
		remap = ""
		_save_settings()
		_show_menu("settings")
		get_viewport().set_input_as_handled()
		return
	var action: String = ""
	var down: bool = false
	if event is InputEventKey and not event.echo:
		last_device = "keyboard"
		for key in keys:
			if int(keys[key]) == event.physical_keycode: action = key
		if action == "" and event.physical_keycode == KEY_LEFT: action = "left"
		if action == "" and event.physical_keycode == KEY_RIGHT: action = "right"
		down = event.pressed
	elif event is InputEventJoypadButton:
		last_device = "gamepad"
		action = joy.get(event.button_index,"")
		down = event.pressed
	if action != "":
		held[action] = down
		if down: pressed[action+"_pressed"] = true
		if action == "pause" and down:
			if rules.mode == "dead":
				_show_menu("dead")
			elif menu == "": _show_menu("pause")
			elif menu == "pause": _resume()
			elif menu == "ending": _show_menu("title")
			elif menu != "title": _show_menu("pause")
			get_viewport().set_input_as_handled()
		elif menu == "": get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not started or exiting: return
	shake_time = maxf(0.0,shake_time-delta)
	if rules.mode == "dead": rules.hero.anim_time += delta
	if menu == "":
		accumulator += delta
		# Never discard elapsed time or queued edge inputs on a frame without a tick.
		var steps: int = 0
		while accumulator>=Rules.STEP and steps<30:
			var input: Dictionary = held.duplicate()
			input.merge(pressed)
			var axis: float = float(held.get("right",false))-float(held.get("left",false))
			if not Input.get_connected_joypads().is_empty():
				var stick: float = Input.get_joy_axis(Input.get_connected_joypads()[0],JOY_AXIS_LEFT_X)
				if absf(stick)>0.2: axis = stick
			input.move = axis
			rules.tick(input)
			pressed.clear()
			accumulator -= Rules.STEP
			steps += 1
			_process_events()
			if rules.mode == "dead":
				_show_menu("dead")
				break
			if rules.mode == "ending":
				_show_menu("ending")
				break
	if menu == "": _advance_visuals(delta)
	camera_x = clampf(rules.hero.x-460.0,0,maxf(0,rules.level.width-1280))
	queue_redraw()

func _advance_visuals(delta: float) -> void:
	parry_visual_time = maxf(0.0,parry_visual_time-delta)
	for enemy in rules.enemies:
		var id: int = int(enemy.id)
		landing_visual_times[id] = maxf(0.0,float(landing_visual_times.get(id,0.0))-delta)
		if previous_actor_states.get(id,"") == "flight" and enemy.state == "stagger" and enemy.y>=600: landing_visual_times[id] = 0.35
		previous_actor_states[id] = enemy.state

func _process_events() -> void:
	for event in rules.events:
		if event.type == "checkpoint": _save_game()
		if event.type in ["hit","hurt"] and settings.shake: shake_time = 0.12
		if event.type == "block" and rules.hero.guard and rules.hero.invuln>0 and rules.hero.invuln<=0.17 and rules.hero.guard_time<0.18: parry_visual_time = 0.2
		if audio_node:
			var cues: Dictionary = {"enemy_down":"defeat","death":"defeat","ending":"victory","dawn":"fire","chapter":"victory"}
			audio_node.cue(cues.get(event.type,event.type))
	rules.events.clear()
	var level_key: String = "%d:%d:%s" % [rules.chapter,rules.segment,rules.mode]
	if previous_level != level_key:
		previous_level = level_key
		previous_actor_states.clear()
		landing_visual_times.clear()
		if audio_node: audio_node.start("boss" if rules.segment == 3 and rules.mode == "play" else "theme")

func _save_game() -> void:
	var data: Dictionary = rules.profile()
	if reviewing:
		data = saved.duplicate(true)
		if not data.has("flags"): data.flags = {}
		data.flags.memories = rules.flags.memories.duplicate()
		data.flags.shortcuts = rules.flags.shortcuts.duplicate()
	data.settings = settings
	if storage.save_profile(data):
		saved = data
		save_status = "已保存 · %s" % rules.level.name
	else: save_status = storage.last_error

func _save_settings() -> void:
	var data: Dictionary = saved.duplicate(true)
	data.settings = settings
	data.difficulty = settings.difficulty
	if not storage.save_profile(data): save_status = storage.last_error
	else: saved = data
	_apply_settings()

func _apply_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if audio_node: audio_node.set_volume(float(settings.volume))
	rules.difficulty = settings.difficulty

func _resume() -> void:
	if rules.mode == "dead":
		_show_menu("dead")
		return
	menu = ""
	paused = false
	if is_instance_valid(panel): panel.queue_free()
	_clear_input()
	if audio_node: audio_node.set_paused(false)

func _new_game() -> void:
	reviewing = false
	rules = Rules.new()
	rules.difficulty = settings.difficulty
	rules.load_level(0,0)
	_resume()
	_save_game()

func _continue_game() -> void:
	reviewing = false
	rules = Rules.new()
	rules.restore(saved)
	_resume()

func _begin_review(chapter_index: int) -> void:
	reviewing = true
	rules = Rules.new()
	rules.restore(saved)
	rules.flags["homecoming"] = false
	rules.load_level(chapter_index,0)
	_resume()

func _button(label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(480,43)
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",20)
	button.add_theme_color_override("font_color",Color("3b3329"))
	button.add_theme_color_override("font_hover_color",Color("685127"))
	button.add_theme_color_override("font_focus_color",Color("685127"))
	for state in ["normal","hover","pressed","focus"]:
		var ink := StyleBoxFlat.new()
		ink.bg_color = Color(0.5,0.35,0.13,0.17 if state != "normal" else 0.035)
		ink.border_color = Color(0.45,0.32,0.15,0.6)
		ink.border_width_bottom = 1
		if state == "focus": ink.set_border_width_all(2)
		ink.content_margin_top = 5
		ink.content_margin_bottom = 5
		button.add_theme_stylebox_override(state,ink)
	button.pressed.connect(callback)
	box.add_child(button)
	if not first_button_set:
		first_button_set = true
		_focus_later.call_deferred(button)

func _focus_later(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree(): button.grab_focus()

func _label(text: String, size: int = 22) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("382e23"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 490
	box.add_child(label)

func _show_menu(which: String) -> void:
	first_button_set = false
	if which == "settings" and menu not in ["settings","keys","keys_move"]: settings_return = menu
	menu = which
	paused = true
	_clear_input()
	if audio_node: audio_node.set_paused(which not in ["title","ending"])
	if is_instance_valid(panel):
		ui.remove_child(panel)
		panel.queue_free()
	panel = PanelContainer.new()
	panel.position = Vector2(360,80)
	panel.custom_minimum_size = Vector2(560,100)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172b35df")
	style.border_color = Color("c7a86b")
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 0
	style.border_width_right = 0
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	var parchment: Texture2D = _texture(manifest.get("props",{}).get("parchment",{}).get("file",""))
	if parchment:
		var paper := StyleBoxTexture.new()
		paper.texture = parchment
		paper.texture_margin_left = 60
		paper.texture_margin_right = 60
		paper.texture_margin_top = 60
		paper.texture_margin_bottom = 60
		paper.content_margin_left = 38
		paper.content_margin_right = 38
		paper.content_margin_top = 30
		paper.content_margin_bottom = 30
		panel.add_theme_stylebox_override("panel",paper)
	else: panel.add_theme_stylebox_override("panel",style)
	ui.add_child(panel)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation",9)
	panel.add_child(box)
	match which:
		"title":
			_label("晨曦之剑",42)
			_label("龙 塔 救 援",24)
			_label("一柄旧剑，一段归乡的约定。",18)
			if saved.has("chapter"): _button("继续冒险",_continue_game)
			_button("新的冒险",func(): _show_menu("confirm") if saved.has("chapter") else _new_game())
			if saved.get("flags",{}).get("completed",false): _button("章节回顾",func(): _show_menu("chapters"))
			_button("设置与按键",func(): _show_menu("settings"))
			_button("退出",request_exit)
			if save_status != "": _label(save_status,16)
		"confirm":
			_label("开始新的旅程？",30)
			_label("这将覆盖当前有效冒险存档。",18)
			_button("确认重新开始",_new_game)
			_button("保留存档，返回",func(): _show_menu("title"))
		"pause":
			_label("歇一歇，再出发",30)
			_label(rules.level.objective,20)
			_label(save_status,16)
			_button("继续",_resume)
			_button("设置与按键",func(): _show_menu("settings"))
			_button("路线图",func(): _show_menu("map"))
			_button("返回标题（保留最近篝火）",func(): _show_menu("title"))
			_button("退出（保留最近篝火）",request_exit)
		"dead":
			_label("火光没有熄灭",32)
			_label("从最近篝火重试，无惩罚、无掉落。",18)
			_button("重新出发",func(): rules.retry(); _resume())
			_button("设置难度",func(): _show_menu("settings"))
			_button("返回标题",func(): _show_menu("title"))
		"ending":
			_label("终于，晨曦照亮归途",32)
			_label("恶龙败亡，艾琳平安归来。\n莱恩把旧剑收回鞘中。\n钟声不再预告危险，而是欢迎回家。",22)
			_label("THE END · 完整营救\n设计与开发：独立模块制作\n绘本素材：AI辅助原创插画\n感谢每一位愿意踏上旅程的人。",17)
			_button("章节回顾",func(): _show_menu("chapters"))
			_button("返回标题",func(): _show_menu("title"))
		"chapters":
			_label("重访王国",30)
			for c in range(5):
				var index: int = c
				_button("第%d章 · %s" % [c+1,Rules.Campaign.CHAPTERS[c][0]],func(): _begin_review(index))
			_button("返回",func(): _show_menu("title"))
		"map":
			_label("营救路线",30)
			for c in range(5): _label(("◆ " if c == rules.chapter else "◇ ")+Rules.Campaign.CHAPTERS[c][0],22)
			_label("每章四段 · 金色路标互动前进\n高处岔路收集王国记忆，不影响主线",17)
			_button("返回",func(): _show_menu("pause"))
		"settings":
			_label("旅途设置",28)
			_button("难度："+("故事" if settings.difficulty == "story" else "冒险"),func(): settings.difficulty = "adventure" if settings.difficulty == "story" else "story"; _save_settings(); _show_menu("settings"))
			_button("音量：%d%%（点击循环）" % int(settings.volume*100),func(): settings.volume = fmod(float(settings.volume)+0.25,1.01); _save_settings(); _show_menu("settings"))
			_button("全屏："+str(settings.fullscreen),func(): settings.fullscreen = not settings.fullscreen; _save_settings(); _show_menu("settings"))
			_button("震屏："+str(settings.shake),func(): settings.shake = not settings.shake; _save_settings(); _show_menu("settings"))
			_button("闪光："+str(settings.flash),func(): settings.flash = 0.0 if settings.flash>0 else 0.5; _save_settings(); _show_menu("settings"))
			_button("字幕："+str(settings.subtitles),func(): settings.subtitles = not settings.subtitles; _save_settings(); _show_menu("settings"))
			_button("重新绑定键盘",func(): _show_menu("keys"))
			_button("返回标题 / 暂停",func(): _show_menu("dead" if rules.mode == "dead" else settings_return))
		"keys":
			_label("点击动作后按新键",24)
			for action in ["jump","attack","roll","guard","dawn","heal","interact"]:
				var name_action: String = action
				_button(action+" : "+OS.get_keycode_string(int(keys[action])),func(): remap = name_action; _label("请按下新键…",16))
			_button("移动与菜单键",func(): _show_menu("keys_move"))
			_button("返回",func(): _show_menu("settings"))
		"keys_move":
			_label("移动与菜单键",24)
			for action in ["left","right","up","down","pause"]:
				var name_action: String = action
				_button(action+" : "+OS.get_keycode_string(int(keys[action])),func(): remap = name_action; _label("请按下新键…",16))
			_button("返回",func(): _show_menu("settings"))
	queue_redraw()

func request_exit() -> void:
	if exiting: return
	exiting = true
	_clear_input()
	if audio_node: await audio_node.shutdown()
	if hosted:
		DisplayServer.window_set_mode(previous_window_mode)
		exit_requested.emit()
	else: get_tree().quit()

func _hint(action: String) -> String:
	if last_device == "gamepad":
		return {"jump":"下键","attack":"左键","roll":"右键","guard":"左肩","dawn":"上键","heal":"Back","interact":"右肩","pause":"Menu"}.get(action,action)
	return _key(action)

func _enemy_visual(enemy: Dictionary) -> Dictionary:
	var name: String = enemy.animation
	var elapsed: float = enemy.anim_time
	if enemy.state == "attack":
		match enemy.kind:
			"axe_lord":
				if enemy.attack_count%2 == 0: name = "jump_slam"
			"bridge_guard":
				if enemy.attack_count%2 == 0: name = "shockwave"
			"rock_lizard": name = "charge"
			"ash_knight":
				if enemy.phase == 2: name = "heavy_slash"
			"dragon":
				if enemy.phase == 3: name = "pounce"
	if enemy.kind == "dragon" and landing_visual_times.get(int(enemy.id),0.0)>0:
		name = "land"
		elapsed = 0.35-float(landing_visual_times[int(enemy.id)])
	if not manifest.get("actors",{}).get(enemy.kind,{}).get("animations",{}).has(name):
		name = enemy.animation
		elapsed = enemy.anim_time
	return {"name":name,"elapsed":elapsed}

func _key(action: String) -> String:
	return OS.get_keycode_string(int(keys[action]))

func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		if ResourceLoader.exists(ROOT+"art/"+path): textures[path] = load(ROOT+"art/"+path)
		else: return null
	return textures[path]

func _prop(id: String, pos: Vector2, height: float) -> bool:
	var spec: Dictionary = manifest.get("props",{}).get(id,{})
	if spec.is_empty(): return false
	var tex: Texture2D = _texture(spec.file)
	if tex == null: return false
	var size := Vector2(float(tex.get_width())/tex.get_height()*height,height)
	draw_texture_rect(tex,Rect2(pos-Vector2(size.x*0.5,size.y),size),false)
	return true

func _terrain(p: Dictionary, y: float) -> bool:
	var id: String = "bridge" if p.kind == "bridge" else ("grass_platform" if rules.chapter == 0 or rules.mode == "homecoming" else ("bridge" if rules.chapter == 1 and p.kind != "ground" else "stone_platform"))
	var spec: Dictionary = manifest.get("props",{}).get(id,{})
	if spec.is_empty(): return false
	var tex: Texture2D = _texture(spec.file)
	if tex == null: return false
	var h: float = 105.0 if p.kind == "ground" else 75.0
	var source_x: float = tex.get_width()*0.2 if p.kind == "ground" else 0.0
	var source_w: float = tex.get_width()*0.6 if p.kind == "ground" else float(tex.get_width())
	var w: float = source_w/tex.get_height()*h
	var x: float = p.x
	while x<p.x+p.w:
		var piece: float = minf(w,p.x+p.w-x)
		if p.kind == "ground":
			draw_texture_rect_region(tex,Rect2(x-camera_x,y+12,piece+1,800-y),Rect2(tex.get_width()*0.3,tex.get_height()*0.3,tex.get_width()*0.4,tex.get_height()*0.2))
		draw_texture_rect_region(tex,Rect2(x-camera_x,y-h*float(spec.get("tile_top_ratio",float(spec.get("tile_top",0.0))/tex.get_height())),piece+1,h),Rect2(source_x,0,source_w*piece/w,tex.get_height()))
		x += piece
	return true

func _actor(kind: String, animation: String, pos: Vector2, facing: int, elapsed: float, fallback_size: float = 80, tint: Color = Color.WHITE) -> void:
	var actors: Dictionary = manifest.get("actors",{})
	if not actors.has(kind):
		# Deliberately labelled greybox; never considered production character art.
		draw_rect(Rect2(pos-Vector2(20,fallback_size),Vector2(40,fallback_size)),Color("706e76"))
		draw_string(font,pos+Vector2(-35,-fallback_size-7),kind,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
		return
	var spec: Dictionary = actors[kind]
	var animations: Dictionary = spec.get("animations",{})
	if animation == "death" and not animations.has("death"): return
	var anim: Dictionary = animations.get(animation,animations.get("idle",{}))
	var tex: Texture2D = _texture(anim.get("file",spec.file))
	if tex == null: return
	var count: int = maxi(1,int(anim.get("frames",1)))
	var frame: int = int(elapsed*float(anim.get("fps",10)))
	frame = frame%count if anim.get("loop",true) else mini(frame,count-1)
	frame += int(anim.get("start",int(anim.get("row",0))*int(spec.get("columns",1))))
	var fw: float = spec.get("frame_width",256)
	var fh: float = spec.get("frame_height",256)
	var cols: int = spec.get("columns",1)
	var region := Rect2((frame%cols)*fw,int(frame/cols)*fh,fw,fh)
	var height: float = spec.get("height",fallback_size)
	var size := Vector2(fw/fh*height,height)
	var anchor: Array = spec.get("anchor",[0.5,1.0])
	var target := Rect2(pos-Vector2(size.x*float(anchor[0]),size.y*float(anchor[1])),size)
	if facing<0:
		target.position.x += size.x
		target.size.x = -size.x
	draw_texture_rect_region(tex,target,region,tint)

func _draw() -> void:
	if not started: return
	var viewport_size: Vector2 = get_viewport_rect().size
	var shake := Vector2(sin(rules.time*140),cos(rules.time*117))*3.0 if shake_time>0 else Vector2.ZERO
	draw_set_transform(shake,0,viewport_size/Vector2(1280,800))
	draw_rect(Rect2(0,0,1280,800),Color("243c48"))
	var backgrounds: Array = manifest.get("backgrounds",[])
	if not backgrounds.is_empty():
		var bg = backgrounds[0 if rules.mode == "homecoming" else mini(rules.chapter,backgrounds.size()-1)]
		if bg is String:
			var tex: Texture2D = _texture(bg)
			if tex: draw_texture_rect(tex,Rect2(0,0,1280,800),false)
		elif bg is Dictionary:
			for layer in ["far","mid","near"]:
				var tex: Texture2D = _texture(bg.get(layer,""))
				if tex: draw_texture_rect(tex,Rect2(-60,-100,1400,900),false)
	if rules.chapter == 0 and rules.segment == 0 and not rules.flags.get("intro_seen",false):
		var dragon_x: float = 1600.0-rules.time*230.0 if rules.time<3.0 else 910.0+(rules.time-3.0)*300.0
		var dragon_y: float = 200.0+rules.time*140.0 if rules.time<3.0 else 620.0-(rules.time-3.0)*100.0
		_actor("dragon","fly",Vector2(dragon_x,dragon_y),-1 if rules.time<3 else 1,rules.time,330)
		_actor("princess","idle" if rules.time<3 else "rescued",Vector2(910,620) if rules.time<3 else Vector2(dragon_x-45,dragon_y+25),1,rules.time,105)
	# High contrast walkable ink edges stay separate from decorative background.
	for p in rules.level.platforms:
		if p.kind == "crumble" and rules.crumbles.get(str(p.x),0.0)>0.65: continue
		var y: float = p.y+sin(rules.time*1.3)*42 if p.kind == "moving" else p.y
		if p.kind == "ground":
			var cursor: float = p.x
			for gap in rules.level.hazards:
				if gap.kind != "pit": continue
				var section: Dictionary = p.duplicate()
				section.x = cursor
				section.w = maxf(0.0,gap.x-cursor)
				if section.w>0: _terrain(section,y)
				cursor = maxf(cursor,gap.x+gap.w)
			var section: Dictionary = p.duplicate()
			section.x = cursor
			section.w = p.x+p.w-cursor
			if section.w>0: _terrain(section,y)
		else:
			if not _terrain(p,y): draw_rect(Rect2(p.x-camera_x,y,p.w,18),Color("75694f"))
			draw_line(Vector2(p.x-camera_x,y),Vector2(p.x+p.w-camera_x,y),Color("544c39"),2)
	for hazard in rules.level.hazards:
		var color := Color("101b23") if hazard.kind == "pit" else Color("f1a94f")
		draw_rect(Rect2(hazard.x-camera_x,620 if hazard.kind == "pit" else 596,hazard.w,180 if hazard.kind == "pit" else 24),color)
		if hazard.kind == "pendulum":
			var swing := Vector2(hazard.x+hazard.w*0.5+sin(rules.time*1.8)*95-camera_x,570)
			draw_line(Vector2(hazard.x+hazard.w*0.5-camera_x,330),swing,Color("b6a781"),3)
			draw_circle(swing,21,Color("524b4b"))
			draw_arc(swing,21,0,TAU,16,Color("e0c491"),2)
		if hazard.kind != "pit":
			var active: bool = fmod(rules.time,hazard.period)>1.7
			draw_string(font,Vector2(hazard.x-camera_x,580),"▲ 危险" if active else "◇ 蓄势",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe2a1"))
	if rules.chapter == 4 and rules.segment == 2:
		for gate in [1200.0,2500.0]:
			var gate_index: int = 0 if gate == 1200.0 else 1
			if rules.mechanism_progress<=gate_index:
				_prop("pillar",Vector2(gate-camera_x+60,620),175)
			_prop("lever",Vector2(gate-camera_x+100,620),95)
			if not _prop("plate",Vector2(gate-camera_x-80,620),26): draw_rect(Rect2(gate-camera_x-125,613,90,7),Color("d7b76d"))
			draw_string(font,Vector2(gate-camera_x-125,590),"压力板",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe2a1"))
			draw_string(font,Vector2(gate-camera_x-45,520),"合作 ["+_hint("interact")+"]",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ffe2a1"))
	for ladder in rules.level.ladders:
		_prop("ladder",Vector2(ladder.x-camera_x,ladder.bottom),ladder.bottom-ladder.top)
		for y in range(int(ladder.top),int(ladder.bottom),18):
			draw_line(Vector2(ladder.x-camera_x-14,y),Vector2(ladder.x-camera_x+14,y),Color("c0a778"),3)
	for mechanism in rules.level.get("mechanisms",[]):
		var pos := Vector2(mechanism.x-camera_x,mechanism.y)
		if mechanism.kind in ["rescue","welcome"]:
			_actor("bridge_keeper" if mechanism.id == "bridgekeeper" else "villager","idle",pos,1,rules.time,110)
		elif not rules.activated.get(mechanism.id,false):
			var prop_id: String = "lever" if mechanism.kind == "lever" else "signpost"
			if mechanism.kind == "cart": prop_id = "cart"
			if "weight" in mechanism.id or "anchor" in mechanism.id: prop_id = "counterweight"
			if "winch" in mechanism.id: prop_id = "winch"
			_prop(prop_id,pos,78)
		if not rules.activated.get(mechanism.id,false):
			draw_string(font,pos+Vector2(-70,-100),mechanism.label+" ["+_hint("interact")+"]",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffedbd"))
	var camp_x: float = rules.level.checkpoint_x-camera_x
	if not _prop("campfire",Vector2(camp_x,620),66): draw_circle(Vector2(camp_x,605),15,Color("edac56"))
	draw_string(font,Vector2(camp_x-45,575),"篝火 ["+_hint("interact")+"]",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("fff1c7"))
	var exit_x: float = rules.level.exit_x-camera_x
	if not _prop("signpost",Vector2(exit_x,620),105): draw_line(Vector2(exit_x,620),Vector2(exit_x,510),Color("e7ca86"),4)
	draw_string(font,Vector2(exit_x-85,495),"前进 / 互动 ["+_hint("interact")+"]",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("fff1c7"))
	if not rules.flags.memories.has(rules.chapter):
		draw_circle(rules.level.collectible-Vector2(camera_x,0),11,Color("fce7a9"))
	for e in rules.enemies:
		if e.hp<=0 and e.anim_time>2: continue
		var visual: Dictionary = _enemy_visual(e)
		_actor(e.kind,visual.name,Vector2(e.x-camera_x,e.y),e.facing,visual.elapsed,210 if e.boss else 100,Color(1.0+settings.flash,1.0+settings.flash,1.0+settings.flash) if e.stun>0 else Color.WHITE)
		if e.hp>0:
			draw_rect(Rect2(e.x-camera_x-28,e.y-125,56,5),Color("32232c"))
			draw_rect(Rect2(e.x-camera_x-28,e.y-125,56*e.hp/e.max_hp,5),Color("d7a16a"))
		if e.state == "windup": draw_string(font,Vector2(e.x-camera_x-10,e.y-145),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,35,Color("ff6654") if e.boss and e.attack_count%3 == 0 else Color("ffcf6a"))
		if e.boss and e.hp>0 and absf(e.x-rules.hero.x)<700:
			draw_rect(Rect2(350,120,580,13),Color("201e27"))
			draw_rect(Rect2(350,120,580*e.hp/e.max_hp,13),Color("b75b4e"))
			draw_string(font,Vector2(450,111),e.kind+"  ·  阶段 "+str(e.phase),HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("ffe9bd"))
	_actor("hero","parry" if parry_visual_time>0 else rules.hero.animation,Vector2(rules.hero.x-camera_x,rules.hero.y),rules.hero.facing,0.2-parry_visual_time if parry_visual_time>0 else rules.hero.anim_time,112)
	if rules.chapter == 4 and rules.segment == 1 and not rules.flags.rescued:
		_actor("princess","idle",Vector2(rules.level.exit_x+40-camera_x,620),-1,rules.time,105)
		if not rules.flags.get("seal_broken",false):
			if not _prop("seal",Vector2(rules.level.exit_x-camera_x,620),120): draw_arc(Vector2(rules.level.exit_x-camera_x,560),55,0,TAU,32,Color("b393d7"),4)
	if rules.chapter == 4 and rules.segment == 3 and rules.mode == "play":
		for pillar_x in [260.0,rules.level.width-260.0]:
			if not _prop("pillar",Vector2(pillar_x-camera_x,620),180): draw_rect(Rect2(pillar_x-camera_x-20,460,40,160),Color("7d7770"))
			draw_string(font,Vector2(pillar_x-camera_x-40,445),"掩体",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe0a8"))
	if rules.flags.rescued and rules.chapter == 4:
		if rules.segment == 2:
			_actor("princess",rules.princess.animation,Vector2(rules.princess.x-camera_x,rules.princess.y),1,rules.princess.anim_time,105)
		else:
			_actor("princess","run" if rules.mode in ["epilogue","homecoming"] and absf(rules.hero.vx)>5 else "idle",Vector2(rules.hero.x-camera_x-70 if rules.mode in ["epilogue","homecoming"] else 230-camera_x,620),1,rules.time,105)
	if rules.cart_active: _prop("cart",Vector2(rules.hero.x-camera_x,rules.hero.y+10),75)
	if rules.level.get("wind",false):
		draw_string(font,Vector2(940,102),"风向 →" if sin(rules.time*0.8)>0 else "风向 ←",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("fff0c7"))
	for p in rules.projectiles: draw_circle(Vector2(p.x-camera_x,p.y),7,Color("f4a354") if p.fire else Color("d5d9d7"))
	for fx in rules.effects:
		draw_arc(Vector2(fx.x-camera_x,fx.y),24,0,TAU,12,Color(1,0.88,0.6,float(settings.flash)),3)
	# Parchment/ink HUD, entirely independent of island and gummy UI.
	draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(760,0),Vector2(725,78),Vector2(0,78)]),Color("182c36d0"))
	draw_line(Vector2(20,77),Vector2(715,77),Color("bca273"),1)
	draw_string(font,Vector2(28,31),"晨曦之剑  /  第%d章 · %s" % [rules.chapter+1,rules.level.name],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("f6e6c4"))
	draw_rect(Rect2(28,46,210,13),Color("543a3d"))
	draw_rect(Rect2(28,46,210*rules.hero.hp/rules.hero.max_hp,13),Color("b56154"))
	draw_string(font,Vector2(253,60),"生命 %d  药剂 %d [%s]" % [rules.hero.hp,rules.hero.heals,_hint("heal")],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f6e6c4"))
	if rules.flags.dawn: draw_string(font,Vector2(490,60),"晨光 %d%% [%s]" % [rules.hero.charge,_hint("dawn")],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe3a1"))
	draw_string(font,Vector2(830,55),"%s 暂停  ·  %s 互动" % [_hint("pause"),_hint("interact")],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("f6e6c4"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,720),Vector2(1190,720),Vector2(1240,800),Vector2(0,800)]),Color("182c36d0"))
	var objective: String = rules.story if rules.story != "" and settings.subtitles else rules.current_objective()
	objective = objective.replace("U 释放",_hint("dawn")+" 释放").replace("用 U ","用 "+_hint("dawn")+" ")
	draw_string(font,Vector2(30,748),objective,HORIZONTAL_ALIGNMENT_LEFT,1220,21,Color("f7e4bd"))
	draw_string(font,Vector2(30,781),("摇杆 移动 · 下键 跳跃 · 左键 攻击 · 右键 翻滚 · 左肩 盾防 · 右肩 互动 · Back 治疗" if last_device == "gamepad" else "%s/%s 移动 · %s 跳跃 · %s 攻击 · %s 翻滚 · %s 盾防 · %s 治疗" % [_key("left"),_key("right"),_key("jump"),_key("attack"),_key("roll"),_key("guard"),_key("heal")]),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("bdc6be"))
	if menu != "": draw_rect(Rect2(0,0,1280,800),Color(0.02,0.04,0.06,0.52))
