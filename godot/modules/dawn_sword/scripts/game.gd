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
		if event.physical_keycode == KEY_LEFT: action = "left"
		if event.physical_keycode == KEY_RIGHT: action = "right"
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
			elif menu != "title": _show_menu("pause")
			get_viewport().set_input_as_handled()
		elif menu == "": get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not started or exiting: return
	shake_time = maxf(0.0,shake_time-delta)
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
	camera_x = clampf(rules.hero.x-460.0,0,maxf(0,rules.level.width-1280))
	queue_redraw()

func _process_events() -> void:
	for event in rules.events:
		if event.type == "checkpoint": _save_game()
		if event.type in ["hit","hurt"] and settings.shake: shake_time = 0.12
		if audio_node:
			var cues: Dictionary = {"enemy_down":"defeat","death":"defeat","ending":"victory","dawn":"fire","chapter":"victory"}
			audio_node.cue(cues.get(event.type,event.type))
	rules.events.clear()
	var level_key: String = "%d:%d" % [rules.chapter,rules.segment]
	if previous_level != level_key:
		previous_level = level_key
		if audio_node: audio_node.start("boss" if rules.segment == 3 else "theme")

func _save_game() -> void:
	var data: Dictionary = rules.profile()
	data.settings = settings
	if storage.save_profile(data):
		saved = data
		save_status = "已保存 · %s" % rules.level.name
	else: save_status = storage.last_error

func _save_settings() -> void:
	var data: Dictionary = saved.duplicate(true)
	data.settings = settings
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
	rules = Rules.new()
	rules.difficulty = settings.difficulty
	rules.load_level(0,0)
	_resume()
	_save_game()

func _continue_game() -> void:
	rules.restore(saved)
	_resume()

func _button(label_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(480,43)
	button.add_theme_font_override("font",font)
	button.add_theme_font_size_override("font_size",20)
	button.pressed.connect(callback)
	box.add_child(button)
	if box.get_child_count() == 2: _focus_later.call_deferred(button)

func _focus_later(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree(): button.grab_focus()

func _label(text: String, size: int = 22) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("f1dfb7"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 490
	box.add_child(label)

func _show_menu(which: String) -> void:
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
	panel.add_theme_stylebox_override("panel",style)
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
				_button("第%d章 · %s" % [c+1,Rules.Campaign.CHAPTERS[c][0]],func(): rules.load_level(index,0); _resume())
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
			_button("返回标题 / 暂停",func(): _show_menu("dead" if rules.mode == "dead" else ("title" if previous_level == "" else "pause")))
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

func _key(action: String) -> String:
	return OS.get_keycode_string(int(keys[action]))

func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		if ResourceLoader.exists(ROOT+"art/"+path): textures[path] = load(ROOT+"art/"+path)
		else: return null
	return textures[path]

func _actor(kind: String, animation: String, pos: Vector2, facing: int, elapsed: float, fallback_size: float = 80) -> void:
	var actors: Dictionary = manifest.get("actors",{})
	if not actors.has(kind):
		# Deliberately labelled greybox; never considered production character art.
		draw_rect(Rect2(pos-Vector2(20,fallback_size),Vector2(40,fallback_size)),Color("706e76"))
		draw_string(font,pos+Vector2(-35,-fallback_size-7),kind,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
		return
	var spec: Dictionary = actors[kind]
	var animations: Dictionary = spec.get("animations",{})
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
	draw_texture_rect_region(tex,target,region)

func _draw() -> void:
	if not started: return
	var viewport_size: Vector2 = get_viewport_rect().size
	var shake := Vector2(sin(rules.time*140),cos(rules.time*117))*3.0 if shake_time>0 else Vector2.ZERO
	draw_set_transform(shake,0,viewport_size/Vector2(1280,800))
	draw_rect(Rect2(0,0,1280,800),Color("243c48"))
	var backgrounds: Array = manifest.get("backgrounds",[])
	if not backgrounds.is_empty():
		var bg = backgrounds[mini(rules.chapter,backgrounds.size()-1)]
		if bg is String:
			var tex: Texture2D = _texture(bg)
			if tex: draw_texture_rect(tex,Rect2(0,0,1280,800),false)
		elif bg is Dictionary:
			for layer in ["far","mid","near"]:
				var tex: Texture2D = _texture(bg.get(layer,""))
				if tex: draw_texture_rect(tex,Rect2(0,0,1280,800),false)
	# High contrast walkable ink edges stay separate from decorative background.
	for p in rules.level.platforms:
		var y: float = p.y+sin(rules.time*1.3)*42 if p.kind == "moving" else p.y
		if p.kind == "ground":
			draw_rect(Rect2(p.x-camera_x,y,p.w,180),Color("303d36"))
		else: draw_rect(Rect2(p.x-camera_x,y,p.w,18),Color("75694f"))
		draw_line(Vector2(p.x-camera_x,y),Vector2(p.x+p.w-camera_x,y),Color("d7c495"),4)
	for hazard in rules.level.hazards:
		var color := Color("101b23") if hazard.kind == "pit" else Color("f1a94f")
		draw_rect(Rect2(hazard.x-camera_x,620 if hazard.kind == "pit" else 596,hazard.w,180 if hazard.kind == "pit" else 24),color)
		if hazard.kind != "pit":
			var active: bool = fmod(rules.time,hazard.period)>1.7
			draw_string(font,Vector2(hazard.x-camera_x,580),"▲ 危险" if active else "◇ 蓄势",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe2a1"))
	if rules.chapter == 4 and rules.segment == 2:
		for gate in [1200.0,2500.0]:
			draw_circle(Vector2(gate-camera_x,555),22,Color("d7b76d"),false,3)
			draw_string(font,Vector2(gate-camera_x-45,520),"合作 [E]",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ffe2a1"))
	for ladder in rules.level.ladders:
		for y in range(int(ladder.top),int(ladder.bottom),18):
			draw_line(Vector2(ladder.x-camera_x-14,y),Vector2(ladder.x-camera_x+14,y),Color("c0a778"),3)
	var camp_x: float = rules.level.checkpoint_x-camera_x
	draw_circle(Vector2(camp_x,605),15,Color("edac56"))
	draw_string(font,Vector2(camp_x-45,575),"篝火 [E]",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("fff1c7"))
	var exit_x: float = rules.level.exit_x-camera_x
	draw_line(Vector2(exit_x,620),Vector2(exit_x,510),Color("e7ca86"),4)
	draw_string(font,Vector2(exit_x-85,495),"前进 / 互动 [E]",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("fff1c7"))
	if not rules.flags.memories.has(rules.chapter):
		draw_circle(rules.level.collectible-Vector2(camera_x,0),11,Color("fce7a9"))
	for e in rules.enemies:
		if e.hp<=0 and e.anim_time>2: continue
		_actor(e.kind,e.animation,Vector2(e.x-camera_x,e.y),e.facing,e.anim_time,210 if e.boss else 100)
		if e.hp>0:
			draw_rect(Rect2(e.x-camera_x-28,e.y-125,56,5),Color("32232c"))
			draw_rect(Rect2(e.x-camera_x-28,e.y-125,56*e.hp/e.max_hp,5),Color("d7a16a"))
		if e.state == "windup": draw_string(font,Vector2(e.x-camera_x-10,e.y-145),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,35,Color("ffcf6a"))
		if e.boss and e.hp>0 and absf(e.x-rules.hero.x)<700:
			draw_rect(Rect2(350,120,580,13),Color("201e27"))
			draw_rect(Rect2(350,120,580*e.hp/e.max_hp,13),Color("b75b4e"))
			draw_string(font,Vector2(450,111),e.kind+"  ·  阶段 "+str(e.phase),HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("ffe9bd"))
	_actor("hero",rules.hero.animation,Vector2(rules.hero.x-camera_x,rules.hero.y),rules.hero.facing,rules.hero.anim_time,112)
	if rules.flags.rescued and rules.chapter == 4:
		_actor("princess","run" if rules.mode == "epilogue" else "idle",Vector2(rules.hero.x-camera_x-70 if rules.segment == 2 or rules.mode == "epilogue" else 230-camera_x,620),1,rules.time,105)
	for p in rules.projectiles: draw_circle(Vector2(p.x-camera_x,p.y),7,Color("f4a354") if p.fire else Color("d5d9d7"))
	for fx in rules.effects:
		draw_arc(Vector2(fx.x-camera_x,fx.y),24,0,TAU,12,Color(1,0.88,0.6,float(settings.flash)),3)
	# Parchment/ink HUD, entirely independent of island and gummy UI.
	draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(760,0),Vector2(725,78),Vector2(0,78)]),Color("182c36d0"))
	draw_line(Vector2(20,77),Vector2(715,77),Color("bca273"),1)
	draw_string(font,Vector2(28,31),"晨曦之剑  /  第%d章 · %s" % [rules.chapter+1,rules.level.name],HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("f6e6c4"))
	draw_rect(Rect2(28,46,210,13),Color("543a3d"))
	draw_rect(Rect2(28,46,210*rules.hero.hp/rules.hero.max_hp,13),Color("b56154"))
	draw_string(font,Vector2(253,60),"生命 %d  药剂 %d [H]" % [rules.hero.hp,rules.hero.heals],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("f6e6c4"))
	if rules.flags.dawn: draw_string(font,Vector2(490,60),"晨光 %d%% [U]" % rules.hero.charge,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("ffe3a1"))
	draw_string(font,Vector2(830,55),"Esc 暂停  ·  E 互动",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("f6e6c4"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,720),Vector2(1190,720),Vector2(1240,800),Vector2(0,800)]),Color("182c36d0"))
	var objective: String = rules.story if rules.story != "" and settings.subtitles else rules.level.objective
	draw_string(font,Vector2(30,748),objective,HORIZONTAL_ALIGNMENT_LEFT,1220,21,Color("f7e4bd"))
	draw_string(font,Vector2(30,781),("摇杆 移动 · 下键 跳跃 · 左键 攻击 · 右键 翻滚 · 左肩 盾防 · 右肩 互动 · Back 治疗" if last_device == "gamepad" else "%s/%s 移动 · %s 跳跃 · %s 攻击 · %s 翻滚 · %s 盾防 · %s 治疗" % [_key("left"),_key("right"),_key("jump"),_key("attack"),_key("roll"),_key("guard"),_key("heal")]),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("bdc6be"))
	if menu != "": draw_rect(Rect2(0,0,1280,800),Color(0.02,0.04,0.06,0.52))
