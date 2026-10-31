extends Node2D
signal exit_requested
const Rules = preload("res://modules/moon_post/rules.gd")
const FONT = preload("res://modules/moon_post/ui/moon-sans.otf")
const SAVE = "user://games/moon_post"
const INK = Color("f6ebdb")
const MUTED = Color("aaa9ce")
const GOLD = Color("f4ce83")
const COLORS = [Color("f4ce83"), Color("8be0cf"), Color("efaacb")]
var model = Rules.new()
var started := false
var hosted := false
var phase := "title"
var previous_phase := "play"
var unlocked := 1
var best: Dictionary = {}
var t := 0.0
var motion := 1.0
var old_positions: Array = []
var buttons: Array = []
var swipe_start := Vector2.ZERO
var swiping := false
var tip := ""
var tip_time := 0.0
var board_origin := Vector2(140, 205)
var cell := 82.0
var audio: AudioStreamPlayer
var audio_enabled := true
var exiting := false
var quit_handler: Callable
var previous_auto_quit := true

func _ready():
	get_viewport().size_changed.connect(resize)
	resize()
	call_deferred("auto_start")

func auto_start():
	if not started: start()

func start(context: Dictionary = {}):
	if started: return
	started = true
	hosted = not context.is_empty() or not exit_requested.get_connections().is_empty()
	quit_handler = context.get("quit_handler", Callable())
	previous_auto_quit = get_tree().auto_accept_quit
	if not hosted: get_tree().auto_accept_quit = false
	load_profile()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	setup_buttons()

func resize():
	var size := get_viewport_rect().size
	var factor := minf(size.x / 1280.0, size.y / 800.0)
	scale = Vector2.ONE * factor
	position = (size - Vector2(1280,800) * factor) / 2.0

func load_profile():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE + "/progress.cfg") == OK:
		unlocked = clampi(int(cfg.get_value("progress", "unlocked", 1)), 1, 12)
		var saved = cfg.get_value("progress", "best", {})
		if saved is Dictionary: best = saved
		audio_enabled = bool(cfg.get_value("settings", "sound", true))

func save_profile():
	DirAccess.make_dir_recursive_absolute(SAVE)
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "best", best)
	cfg.set_value("settings", "sound", audio_enabled)
	if cfg.save(SAVE + "/progress.cfg") != OK:
		tip = "进度暂时无法保存，本次仍可继续。"; tip_time = 4.0

func play_level(index: int):
	model.reset(index)
	old_positions = model.positions.duplicate()
	motion = 1.0
	phase = "play"
	tip = ""
	setup_buttons()

func _process(delta):
	t += delta
	motion = minf(1.0, motion + delta * 8.0)
	tip_time = maxf(0, tip_time - delta)
	queue_redraw()

func rounded(rect: Rect2, color: Color, radius: int = 20):
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func label_at(value: String, point: Vector2, size: int = 24, color: Color = INK):
	draw_string(FONT, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int, color: Color = INK):
	label_at(value, Vector2((1280-FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)/2,y),size,color)

func _draw():
	draw_rect(Rect2(0,0,1280,800),Color("171d38"))
	# Cut-paper horizon: layered island houses over a quiet sea.
	for i in range(55):
		var p := Vector2(fmod(i*197.0+31,1280),fmod(i*79.0,530))
		var a := 0.3+0.25*sin(t*1.2+i)
		draw_circle(p,1.4,Color(0.88,0.85,1.0,a))
	draw_circle(Vector2(1120,106),53,Color("f4e4b6"))
	draw_circle(Vector2(1140,89),49,Color("171d38"))
	for i in range(12):
		var x := i*120.0-50
		var h := 70.0+fmod(i*39.0,80)
		draw_rect(Rect2(x,700-h,105,h+100),Color("262c4c"))
		draw_colored_polygon(PackedVector2Array([Vector2(x-10,700-h),Vector2(x+52,650-h),Vector2(x+115,700-h)]),Color("343958"))
		for j in range(2):
			draw_rect(Rect2(x+22+j*40,720-h,13,23),Color("8c6d66"))
	for i in range(8):
		draw_line(Vector2(i*180+20,780+sin(t+i)*3),Vector2(i*180+110,780+sin(t+i)*3),Color("46435f"),2)
	if phase == "title":
		draw_title(); return
	label_at("月影邮差",Vector2(60,65),35)
	label_at("MOON POST  /  屋顶上的同步来信",Vector2(62,96),16,MUTED)
	if phase == "levels":
		centered("选择一条月光邮路",180,32)
		centered("完成邮路后解锁下一站 · 已送达的关卡可以随时重玩",219,18,MUTED)
		return
	draw_board()
	draw_side_panel()
	if phase in ["pause","help","win","ending"]: draw_overlay()

func draw_title():
	label_at("晴贝岛 · 夜间邮局",Vector2(100,105),20,GOLD)
	label_at("月影邮差",Vector2(96,205),68)
	label_at("MOON POST",Vector2(102,245),24,MUTED)
	label_at("一阵风，吹动所有纸邮差。",Vector2(102,310),27)
	label_at("借屋檐错开脚步，把晚安送到每一扇窗。",Vector2(102,355),22,MUTED)
	label_at("12 条手工邮路  /  无限撤销  /  无计时压力",Vector2(103,402),18,GOLD)
	# Large original folded-paper couriers on a miniature rooftop garden.
	rounded(Rect2(735,330,430,230),Color("383d62"),22)
	draw_colored_polygon(PackedVector2Array([Vector2(710,330),Vector2(950,260),Vector2(1190,330)]),Color("6c668c"))
	for i in range(3):
		draw_courier(Vector2(815+i*130,390+sin(t*2+i)*9),i,2.0)
		flower(Vector2(810+i*125,530),i)
	label_at("金笺 · 薄荷 · 桃信",Vector2(829,602),23,MUTED)
	label_at("方向键 / WASD · 滑动 · 屏幕方向键",Vector2(103,690),18,MUTED)

func draw_board():
	var data: Dictionary = model.levels[model.level_index]
	var grid: Array = data.grid
	cell = minf(82.0, minf(690.0/grid[0].length(),440.0/grid.size()))
	board_origin = Vector2(86+(730-grid[0].length()*cell)/2,203+(440-grid.size()*cell)/2)
	rounded(Rect2(57,143,780,530),Color("11172f"),26)
	label_at("邮路 %02d / 12   ·   %s" % [model.level_index+1,data.title],Vector2(84,182),24)
	var opened: bool = model.gates_open(model.positions)
	for y in range(grid.size()):
		for x in range(grid[y].length()):
			var p := board_origin+Vector2(x,y)*cell
			var v: String = grid[y][x]
			if v == "#":
				# Boundary is a scalloped rooftop edge, interior blocks are leafy chimney planters.
				if x == 0 or y == 0 or x == grid[y].length()-1 or y == grid.size()-1:
					rounded(Rect2(p+Vector2(2,8),Vector2(cell-4,cell-13)),Color("333853"),8)
					draw_line(p+Vector2(8,18),p+Vector2(cell-8,18),Color("4d526f"),3)
				else:
					rounded(Rect2(p+Vector2(6,19),Vector2(cell-12,cell-22)),Color("211d38"),8)
					rounded(Rect2(p+Vector2(4,9),Vector2(cell-8,cell-24)),Color("746782"),6)
					flower(p+Vector2(cell*0.5,cell*0.48),x+y)
			else:
				rounded(Rect2(p+Vector2(1,8),Vector2(cell-2,cell-1)),Color("38314d"),7)
				rounded(Rect2(p+Vector2(1,1),Vector2(cell-2,cell-9)),Color("625f7f") if (x+y)%2 == 0 else Color("5d5a78"),7)
				draw_line(p+Vector2(8,cell-15),p+Vector2(cell-9,cell-15),Color("7b7291"),1)
				if v == "s":
					draw_circle(p+Vector2.ONE*cell/2,22,Color("a38b69") if opened else Color("423e5d"))
					star(p+Vector2.ONE*cell/2,15,GOLD)
				if v == "g":
					var c := Color("8be0cf") if opened else Color("cfaddf")
					for k in range(3):
						draw_line(p+Vector2(17+k*18,14),p+Vector2(17+k*18,cell-17 if not opened else 27),c,4)
					draw_arc(p+Vector2(cell/2,23),cell*0.32,PI,TAU,20,c,3,true)
	var goals: Array = model.coordinates(data.goals)
	for i in range(goals.size()):
		var p: Vector2 = board_origin+Vector2(goals[i])*cell+Vector2.ONE*cell/2
		draw_circle(p,cell*0.34,Color(COLORS[i],0.16))
		draw_arc(p,cell*0.33,0,TAU,36,COLORS[i],2,true)
		# Envelope-shaped delivery destination, numbered for color-blind play.
		draw_rect(Rect2(p+Vector2(-20,-13),Vector2(40,26)),Color(COLORS[i],0.48))
		draw_line(p+Vector2(-20,-13),p+Vector2(0,2),COLORS[i],2)
		draw_line(p+Vector2(20,-13),p+Vector2(0,2),COLORS[i],2)
		label_at(str(i+1),p+Vector2(20,-16),15,COLORS[i])
	for i in range(model.positions.size()):
		var current: Vector2 = Vector2(model.positions[i])
		var prior: Vector2 = Vector2(old_positions[i]) if old_positions.size() > i else current
		var p := board_origin+prior.lerp(current,smoothstep(0,1,motion))*cell+Vector2.ONE*cell/2
		var shared: bool = model.positions.count(model.positions[i]) > 1
		if shared: p += Vector2((i-1)*15,-i*6)
		draw_courier(p+Vector2(0,sin(t*3+i)*2),i,0.85)
	label_at("同一步，同一阵风。烟囱会挡路，纸邮差可以彼此穿过。",Vector2(85,710),19,MUTED)
	if tip_time > 0: label_at(tip,Vector2(85,749),20,GOLD)
	else: label_at("Z 撤销   ·   R 重来   ·   Esc 暂停   ·   H 帮助",Vector2(85,749),17,MUTED)

func star(p: Vector2, radius: float, color: Color):
	var points := PackedVector2Array()
	for i in range(10):
		var a := i*PI/5-PI/2
		points.append(p+Vector2(cos(a),sin(a))*(radius if i%2 == 0 else radius*0.45))
	draw_colored_polygon(points,color)

func flower(p: Vector2, seed_value: int):
	draw_line(p+Vector2(0,14),p-Vector2(0,14),Color("a3c5ac"),3)
	for j in range(4):
		var a := j*PI/2
		draw_circle(p+Vector2(cos(a)*9,sin(a)*9)-Vector2(0,9),8,Color("9ccbb6") if seed_value%2 == 0 else Color("b89bbd"))
	draw_circle(p-Vector2(0,9),5,GOLD)

func draw_courier(p: Vector2, index: int, s: float):
	var color: Color = COLORS[index]
	draw_set_transform(p,0,Vector2.ONE*s)
	draw_ellipse_shadow(Vector2(0,23))
	# Folded hood and coat silhouette, not an animal silhouette.
	draw_colored_polygon(PackedVector2Array([Vector2(-25,20),Vector2(-15,-17),Vector2(0,-37),Vector2(20,-18),Vector2(28,20),Vector2(0,13)]),color)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-37),Vector2(0,13),Vector2(28,20),Vector2(20,-18)]),color.darkened(0.17))
	draw_colored_polygon(PackedVector2Array([Vector2(-13,-16),Vector2(13,-16),Vector2(0,-3)]),Color("fff6df"))
	draw_circle(Vector2(-5,-12),1.8,Color("383247")); draw_circle(Vector2(5,-12),1.8,Color("383247"))
	draw_line(Vector2(-15,21),Vector2(-19,27),color,4); draw_line(Vector2(15,21),Vector2(19,27),color,4)
	draw_rect(Rect2(-13,0,26,17),Color("fff6df"))
	draw_line(Vector2(-13,0),Vector2(0,10),Color("907c86"),1.5)
	draw_line(Vector2(13,0),Vector2(0,10),Color("907c86"),1.5)
	draw_circle(Vector2(22,-25),10,Color("26243c"))
	label_at(str(index+1),Vector2(18,-20),14,color)
	draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow(p: Vector2):
	draw_colored_polygon(PackedVector2Array([p+Vector2(-26,0),p+Vector2(-14,-6),p+Vector2(14,-6),p+Vector2(26,0),p+Vector2(14,7),p+Vector2(-14,7)]),Color(0.08,0.07,0.18,0.3))

func draw_side_panel():
	rounded(Rect2(865,143,353,530),Color("292b4a"),26)
	label_at("夜间邮局",Vector2(893,184),23,GOLD)
	label_at("步数  %02d" % model.moves,Vector2(893,227),29)
	label_at("最短邮路  %d 步" % model.levels[model.level_index].par,Vector2(1050,225),16,MUTED)
	var hint: String = model.levels[model.level_index].hint
	var lines := wrap_text(hint,17)
	for i in range(lines.size()): label_at(lines[i],Vector2(893,271+i*27),17,MUTED)
	label_at("每次指挥所有邮差",Vector2(960,372),17,GOLD)
	label_at("点按方向键，也可以滑动屋顶",Vector2(903,633),16,MUTED)

func wrap_text(value: String, width: int) -> Array:
	var lines: Array = []
	for i in range(0,value.length(),width): lines.append(value.substr(i,width))
	return lines

func draw_overlay():
	draw_rect(Rect2(0,0,1280,800),Color(0.04,0.05,0.12,0.82))
	rounded(Rect2(270,158,740,492),Color("32334f"),30)
	var title := "月光稍歇"
	if phase == "help": title = "给新邮差的便笺"
	if phase == "win": title = "晚安信，送到了！"
	if phase == "ending": title = "整座岛，都收到了晚安"
	centered(title,225,37,GOLD)
	if phase == "help":
		var lines = ["方向键 / WASD / 滑动 / 点按：所有纸邮差同时移动。","墙与屋檐会挡路；纸邮差可以相互穿过、重叠。","编号 1 / 2 / 3 的邮差要同时站在各自同号同色邮筒上。","星形灯台：任意邮差踩住时，所有月门开启。","移动用出发前的灯台状态判断；关门不会挤走门内邮差。","Z 无限撤销 · R 重来 · Esc 暂停。没有时间限制。"]
		for i in range(lines.size()): centered(lines[i],290+i*41,19,INK)
	elif phase == "pause":
		centered("不必着急，月亮会等你。",300,25)
		centered("暂停期间不会接收移动输入。",342,19,MUTED)
	elif phase == "win":
		centered("邮路 %02d  ·  %d 步送达" % [model.level_index+1,model.moves],304,27)
		centered("最短 %d 步  /  你的最佳 %d 步" % [model.levels[model.level_index].par,int(best.get(str(model.level_index),model.moves))],350,21,MUTED)
		centered("每一扇小窗后，都有一个等信的人。",406,22)
	else:
		centered("12 条邮路 · 三位纸邮差 · 一座亮着灯的小岛",310,25)
		centered("谢谢你，把月光折成了可以抵达的信。",365,23,MUTED)
		for i in range(3): draw_courier(Vector2(535+i*105,438),i,1.1)

func button(text: String, rect: Rect2, action: Callable, primary := false, disabled := false):
	var b := Button.new()
	b.text = text; b.position = rect.position; b.size = rect.size
	b.add_theme_font_override("font",FONT)
	b.add_theme_font_size_override("font_size",21)
	b.add_theme_color_override("font_color",Color("29243b") if primary else INK)
	b.add_theme_color_override("font_hover_color",Color("29243b") if primary else INK)
	b.add_theme_color_override("font_disabled_color",Color("66657f"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD if primary else Color("474563")
		if state == "hover": style.bg_color = style.bg_color.lightened(0.12)
		if state == "pressed": style.bg_color = style.bg_color.darkened(0.12)
		if state == "disabled": style.bg_color = Color("282b43")
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2); style.border_color = GOLD
		style.set_corner_radius_all(14)
		b.add_theme_stylebox_override(state,style)
	b.disabled = disabled
	b.pressed.connect(action)
	add_child(b); buttons.append(b)

func setup_buttons():
	for b in buttons:
		b.hide(); b.queue_free()
	buttons.clear()
	if phase == "title":
		button("开始送信" if unlocked == 1 else "继续邮路 %02d" % unlocked,Rect2(103,463,278,67),func(): play_level(unlocked-1),true)
		button("选择邮路",Rect2(103,548,170,57),func(): change_phase("levels"))
		button("返回小岛",Rect2(290,548,170,57),exit_game)
		button("玩法",Rect2(477,548,110,57),show_help)
		return
	if phase == "levels":
		for i in range(12):
			var name_value: String = model.levels[i].title
			var caption := "%02d  %s%s" % [i+1,name_value,"  ✓" if best.has(str(i)) else ""]
			button(caption,Rect2(140+(i%3)*340,270+(i/3)*85,320,66),play_level.bind(i),false,i>=unlocked)
		button("返回",Rect2(532,659,216,58),func(): change_phase("title"))
		return
	if phase in ["pause","help","win","ending"]:
		if phase == "help": button("明白了",Rect2(510,566,260,57),func(): change_phase(previous_phase),true)
		if phase == "pause":
			button("继续送信",Rect2(505,390,270,60),func(): change_phase("play"),true)
			button("选择邮路",Rect2(350,484,270,58),func(): change_phase("levels"))
			button("返回小岛",Rect2(660,484,270,58),exit_game)
		if phase == "win":
			button("下一条邮路" if model.level_index < 11 else "送完最后一封",Rect2(505,464,270,60),advance,true)
			button("再送一次",Rect2(350,549,270,58),func(): play_level(model.level_index))
			button("选择邮路",Rect2(660,549,270,58),func(): change_phase("levels"))
		if phase == "ending":
			button("重访邮路",Rect2(350,535,270,60),func(): change_phase("levels"),true)
			button("返回小岛",Rect2(660,535,270,60),exit_game)
		return
	button("邮路",Rect2(868,54,96,49),func(): change_phase("levels"))
	button("帮助",Rect2(978,54,96,49),show_help)
	button("暂停",Rect2(1088,54,130,49),func(): change_phase("pause"))
	button("↑",Rect2(1005,390,80,68),do_move.bind(0),true)
	button("←",Rect2(914,468,80,68),do_move.bind(3),true)
	button("↓",Rect2(1005,468,80,68),do_move.bind(2),true)
	button("→",Rect2(1096,468,80,68),do_move.bind(1),true)
	button("撤销 Z",Rect2(889,554,145,54),undo_move)
	button("重来 R",Rect2(1052,554,145,54),func(): play_level(model.level_index))
	button("一步提示",Rect2(868,695,156,53),hint_step)
	button("声音 开" if audio_enabled else "声音 关",Rect2(1040,695,178,53),toggle_sound)

func change_phase(value: String):
	phase = value
	swiping = false
	setup_buttons()

func show_help():
	previous_phase = phase
	change_phase("help")

func do_move(direction: int):
	if phase != "play": return
	old_positions = model.positions.duplicate()
	if model.move(direction):
		motion = 0.0
		chime(330.0+direction*55,0.07)
		if model.won():
			var key := str(model.level_index)
			best[key] = mini(int(best.get(key,99999)),model.moves)
			unlocked = maxi(unlocked,mini(12,model.level_index+2))
			save_profile(); change_phase("win"); chime(660,0.3)
	else:
		tip = "这一阵风被屋檐挡住了，试试其他方向。"; tip_time = 2.2

func undo_move():
	if phase != "play": return
	old_positions = model.positions.duplicate()
	if model.undo(): motion = 0.0; chime(260,0.07)
	else: tip = "已经回到这条邮路的起点。"; tip_time = 2.0

func hint_step():
	var solution: String = model.solve()
	if solution == "!": tip = "现在无法送达。可以撤销几步，或重新开始。"
	elif solution.is_empty(): tip = "已经全部送达！"
	else: tip = "下一步可以试试：" + ["↑ 向上","→ 向右","↓ 向下","← 向左"][int(solution[0])]
	tip_time = 5.0

func advance():
	if model.level_index == 11: change_phase("ending")
	else: play_level(model.level_index+1)

func toggle_sound():
	audio_enabled = not audio_enabled
	save_profile(); setup_buttons()

func chime(hz: float, duration: float):
	if not audio_enabled or not audio: return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data := PackedByteArray()
	for i in range(int(22050*duration)):
		var f := float(i)/22050
		var value := int(sin(f*hz*TAU)*exp(-f*16)*minf(1,f*180)*5500)
		data.append(value&255); data.append((value>>8)&255)
	stream.data = data
	audio.stream = stream; audio.play()

func _unhandled_input(event):
	if not started or exiting: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if phase == "help": change_phase(previous_phase)
			elif phase == "pause": change_phase("play")
			elif phase == "play": change_phase("pause")
			elif phase == "levels": change_phase("title")
			else: exit_game()
			return
		if phase != "play": return
		match event.keycode:
			KEY_UP, KEY_W: do_move(0)
			KEY_RIGHT, KEY_D: do_move(1)
			KEY_DOWN, KEY_S: do_move(2)
			KEY_LEFT, KEY_A: do_move(3)
			KEY_Z, KEY_BACKSPACE: undo_move()
			KEY_R: play_level(model.level_index)
			KEY_H: show_help()
		get_viewport().set_input_as_handled()
	if phase != "play": return
	if event is InputEventScreenTouch:
		if event.pressed:
			swipe_start = get_global_transform().affine_inverse()*event.position; swiping = swipe_start.x < 840
		else: finish_swipe(get_global_transform().affine_inverse()*event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			swipe_start = get_local_mouse_position(); swiping = swipe_start.x < 840
		else: finish_swipe(get_local_mouse_position())

func finish_swipe(point: Vector2):
	if not swiping: return
	swiping = false
	var delta := point-swipe_start
	if delta.length() < 28: return
	if absf(delta.x) > absf(delta.y): do_move(1 if delta.x > 0 else 3)
	else: do_move(2 if delta.y > 0 else 0)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST and started:
		if quit_handler.is_valid(): quit_handler.call()
		else: request_exit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and phase == "play": change_phase("pause")

func exit_game():
	request_exit()

func _exit_tree():
	if started and not hosted: get_tree().auto_accept_quit = previous_auto_quit

func request_exit():
	if exiting: return
	exiting = true
	get_viewport().set_input_as_handled()
	if audio: audio.stop()
	save_profile()
	if hosted: exit_requested.emit()
	else: get_tree().quit()
