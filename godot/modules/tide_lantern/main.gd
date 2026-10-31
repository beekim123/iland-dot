extends Node2D
signal exit_requested
const Rules = preload("rules.gd")
const Store = preload("store.gd")
const FONT = preload("ui/tide-font.otf")
const INK = Color("102d38")
const CREAM = Color("f7efd7")
const GOLD = Color("f6c66d")
const TEAL = Color("68cfc3")
var state: Dictionary = {}
var started := false
var context: Dictionary = {}
var exiting := false
var intro := true
var paused := false
var selected := 1
var hover := -1
var buttons: Array = []
var undo_state: Dictionary = {}
var undo_used := false
var elapsed := 0.0
var flash := 0.0
var last_cells: Array = []
var impact_origin := Vector2.ZERO
var exact_flash := false
var muted := false
var profile := {"wins":0,"best_exact":0}
var result_saved := false
var audio: AudioStreamPlayer
var portrait := false
var virtual_size := Vector2(1280,800)
var canvas_scale := 1.0
var canvas_origin := Vector2.ZERO

func _ready() -> void:
	audio = AudioStreamPlayer.new(); add_child(audio)
	call_deferred("_autostart")
func _autostart() -> void:
	if not started and get_tree().current_scene == self: start({})
func start(host_context: Dictionary = {}) -> void:
	if started: return
	started = true; context = host_context.duplicate(); state = Rules.new_run(); load_profile(); restore_run(); queue_redraw()
func load_profile() -> void:
	if FileAccess.file_exists("user://games/tide_lantern/profile.json"):
		var json = JSON.new()
		if json.parse(FileAccess.get_file_as_string("user://games/tide_lantern/profile.json")) != OK: return
		var data = json.data
		if data is Dictionary:
			profile.wins = maxi(0,int(data.get("wins",0))); profile.best_exact = maxi(0,int(data.get("best_exact",0)))
func save_result() -> void:
	if result_saved: return
	result_saved = true
	if state.status == "won": profile.wins += 1
	profile.best_exact = maxi(profile.best_exact, state.exact)
	DirAccess.make_dir_recursive_absolute("user://games/tide_lantern")
	var file = FileAccess.open("user://games/tide_lantern/profile.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(profile))
func reset_run() -> void:
	state = Rules.new_run(); selected = 1; intro = false; paused = false; undo_state = {}; undo_used = false; result_saved = false; save_run()
func _process(delta: float) -> void:
	elapsed += delta; flash = maxf(0,flash-delta); queue_redraw()
func _draw() -> void:
	if not started: return
	var vp = get_viewport_rect().size
	portrait = vp.x/vp.y < 1.15
	virtual_size = Vector2(760,1280) if portrait else Vector2(1280,800)
	canvas_scale = minf(vp.x/virtual_size.x,vp.y/virtual_size.y); canvas_origin = (vp-virtual_size*canvas_scale)*0.5
	draw_rect(Rect2(Vector2.ZERO,vp),Color("071d29"))
	draw_set_transform(canvas_origin,0,Vector2.ONE*canvas_scale)
	buttons.clear()
	draw_rect(Rect2(Vector2.ZERO,virtual_size),INK)
	for k in range(11):
		var yy = 140.0+k*65.0
		var points = PackedVector2Array()
		for xx in range(-20,1301,20): points.append(Vector2(xx,yy+sin(xx*0.013+elapsed*0.3+k)*8))
		draw_polyline(points,Color(0.20,0.43,0.47,0.14),2)
	# Stars and distant island silhouettes give the board its nighttime harbor setting.
	for i in range(32):
		var p = Vector2(28+(i*137)%1220,20+(i*73)%155)
		draw_circle(p,1.3,Color(0.8,0.9,0.83,0.35+0.15*sin(elapsed+i)))
	label("LANTERN / TIDE",Vector2(52,42),15,TEAL)
	label("灯塔净潮",Vector2(50,92),38,CREAM)
	label("把每一束光，恰好交给黑夜。",Vector2(52,124),17,Color("9ebfc0"))
	lighthouse(Vector2(675,90))
	button(Rect2(470,38,106,58) if portrait else Rect2(1000,35,106,48),"静音" if not muted else "声音", "mute",false,16)
	button(Rect2(590,38,108,58) if portrait else Rect2(1120,35,108,48),"暂停 Ⅱ","pause",false,16)
	panel(Rect2(50,150,660 if portrait else 1180,64),Color("21434c"),18)
	label("%02d / 05   %s" % [state.room+1,Rules.ROOM_NAMES[state.room]],Vector2(72,191),22,CREAM)
	label("心火 %d / %d" % [state.hp,state.max_hp],Vector2(410,178) if portrait else Vector2(505,190),18 if portrait else 21,Color("f7b3a1"))
	label("护光 %d" % state.shield,Vector2(410,202) if portrait else Vector2(735,190),18 if portrait else 21,TEAL)
	label("精准 %d" % state.exact,Vector2(570,202) if portrait else Vector2(900,190),18 if portrait else 21,GOLD)
	for k in range(0 if portrait else 5): draw_circle(Vector2(1135+k*15,181),4,GOLD if k<=state.room else Color("46606a"))
	label("潮 池",Vector2(58,248),18,TEAL)
	label("数字 = 潮影强度   ·   红点 = 袭击倒计时",Vector2(180,248),15,Color("a6c5c5"))
	var preview = Rules.affected(selected,hover) if hover >= 0 and not intro and not paused else []
	for i in range(20):
		var r = cell_rect(i); var c = state.board[i]
		var tint = Color("254c55") if (i+i/5)%2 == 0 else Color("214650")
		if i in preview: tint = Color("426b67")
		panel(r,tint,15)
		if i in preview: outline(r,GOLD,2,15)
		if i in last_cells and flash > 0: panel(r,Color(1,0.85,0.49,flash*0.7),15)
		var p = r.get_center()
		match c.kind:
			"wisp":
				wisp(p+Vector2(0,-7),c.hp,i)
				for j in range(c.timer): draw_circle(Vector2(p.x+(j-(c.timer-1)*0.5)*12,r.end.y-12),3.7,Color("ffab91") if c.timer==1 else Color("82b6b5"))
				label(str(c.attack),Vector2(r.end.x-20,r.position.y+23),13,Color("ffbd9c"))
			"powder":
				var poly = PackedVector2Array([p+Vector2(-21,4),p+Vector2(-12,-23),p+Vector2(8,-30),p+Vector2(24,5),p+Vector2(5,19)])
				draw_colored_polygon(poly,Color("9fdae0")); draw_line(p+Vector2(8,-30),p+Vector2(4,18),CREAM,2)
				label("盐晶",p+Vector2(-23,39),14,CREAM)
			"coral":
				for j in range(3):
					var a = p+Vector2((j-1)*15,-20+abs(j-1)*8)
					draw_line(p+Vector2(0,16),a,Color("e7979c"),8,true); draw_circle(a,6,Color("ffc3b1"))
				label("心珊瑚",p+Vector2(-32,39),14,CREAM)
			"beacon":
				draw_circle(p,25,Color(1,0.8,0.4,0.12)); panel(Rect2(p-Vector2(13,22),Vector2(26,38)),GOLD,7)
				draw_arc(p+Vector2(0,-22),9,PI,TAU,16,CREAM,3)
				label("航灯",p+Vector2(-23,39),14,CREAM)
			_:
				draw_arc(p+Vector2(-3,0),14,0.2,2.5,16,Color("41717a"),2)
	if flash > 0:
		for i in last_cells:
			var p = cell_rect(i).get_center()
			draw_line(impact_origin,p,Color(1,0.83,0.45,flash),3,true)
			draw_arc(p,22+(0.65-flash)*60,0,TAU,32,Color(1,0.85,0.5,flash),3,true)
		if exact_flash:
			panel(Rect2(205,400,335,65),Color(0.07,0.19,0.22,0.88),18)
			label("精准共鸣 · 护光 +1",Vector2(225,442),25,GOLD)
	label("六 件 遗 灯",Vector2(55,754) if portrait else Vector2(760,248),18,TEAL)
	for t in range(6):
		var r = Rect2(28+(t%3)*238,775+(t/3)*114,226,100) if portrait else Rect2(750+(t%2)*240,270+(t/2)*114,226,100)
		var active = selected == t
		panel(r,Color("365d60") if active else Color("203e49"),14)
		outline(r,GOLD if active else Color("3b5960"),2 if active else 1,14)
		label("%d  %s" % [t+1,Rules.TOOLS[t].name],r.position+Vector2(15,31),21,GOLD if active else CREAM)
		label("力 %d  ·  %s" % [Rules.TOOLS[t].power,Rules.TOOLS[t].desc],r.position+Vector2(15,56),13,Color("b5ceca"))
		for w in range(Rules.TOOLS[t].wear+state.wear_bonus):
			draw_circle(r.position+Vector2(20+w*14,78),4,GOLD if w<state.wear[t] else Color("46616a"))
		if state.wear[t] == 0: label("耗尽",r.position+Vector2(170,82),15,Color("ee9d91"))
		buttons.append({"rect":r,"id":"tool%d"%t})
	label("精准净化：力量 = 剩余强度",Vector2(55,1038) if portrait else Vector2(755,640),19,GOLD)
	label("返还 1 耐久，获得 1 护光。",Vector2(55,1067) if portrait else Vector2(755,667),17,CREAM)
	label("盐晶爆炸伤及十字邻格，可连锁。",Vector2(55,1095) if portrait else Vector2(755,694),16,Color("a8c7c6"))
	panel(Rect2(50,1120,660,54) if portrait else Rect2(50,730,940,48),Color("213e47"),12)
	label(state.log.left(31 if portrait else 48),Vector2(67,1154) if portrait else Vector2(67,760),18 if portrait else 16,CREAM)
	button(Rect2(50,1190,660,60) if portrait else Rect2(1005,730,225,48),"回溯一步" if not undo_used else "回溯已用", "undo", false,17)
	if portrait and (intro or paused or state.status != "play"): draw_portrait_modal()
	elif intro: draw_intro()
	elif paused: draw_pause()
	elif state.status == "upgrade": draw_upgrade()
	elif state.status in ["won","lost"]: draw_result()
	draw_set_transform(Vector2.ZERO)
func cell_rect(i: int) -> Rect2:
	return Rect2(55+(i%5)*130,270+(i/5)*111,120,101)
func panel(r: Rect2, color: Color, radius: int = 12) -> void:
	var style = StyleBoxFlat.new(); style.bg_color = color; style.set_corner_radius_all(radius); draw_style_box(style,r)
func outline(r: Rect2, color: Color, width: int, radius: int) -> void:
	var style = StyleBoxFlat.new(); style.bg_color = Color.TRANSPARENT; style.border_color = color; style.set_border_width_all(width); style.set_corner_radius_all(radius); draw_style_box(style,r)
func label(txt: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(FONT,pos,txt,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func button(r: Rect2, txt: String, id: String, primary := false, size := 20) -> void:
	panel(r,GOLD if primary else Color("31545e"),12)
	var width = FONT.get_string_size(txt,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	label(txt,Vector2(r.get_center().x-width/2,r.get_center().y+size*0.35),size,INK if primary else CREAM)
	buttons.append({"rect":r,"id":id})
func lighthouse(p: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([p+Vector2(-15,28),p+Vector2(-9,-25),p+Vector2(10,-25),p+Vector2(18,28)]),CREAM)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-14,-25),p+Vector2(0,-42),p+Vector2(15,-25)]),Color("dc9174"))
	draw_rect(Rect2(p+Vector2(-7,-21),Vector2(16,12)),GOLD)
	draw_colored_polygon(PackedVector2Array([p+Vector2(8,-15),p+Vector2(180,-42),p+Vector2(180,19)]),Color(1,0.8,0.4,0.08))
	draw_line(p+Vector2(-16,7),p+Vector2(15,7),Color("538f95"),8)
	draw_arc(p+Vector2(0,34),34,PI,TAU,20,Color("669d9e"),3)
func wisp(p: Vector2,hp: int, index: int) -> void:
	p.y += sin(elapsed*2+index)*3
	draw_circle(p,31,Color(0.38,0.77,0.79,0.08))
	var body = Color("b2dcd9") if hp<=3 else Color("bba8d6")
	draw_circle(p+Vector2(0,-5),23,body)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-23,-4),p+Vector2(-28,23),p+Vector2(-12,15),p+Vector2(0,24),p+Vector2(12,15),p+Vector2(27,22),p+Vector2(23,-4)]),body)
	draw_circle(p+Vector2(-8,-9),3,INK); draw_circle(p+Vector2(8,-9),3,INK)
	label(str(hp),p+Vector2(-7,16),20,INK)
func shade() -> void:
	draw_rect(Rect2(Vector2.ZERO,virtual_size),Color(0.025,0.08,0.12,0.86)); buttons.clear()
func draw_intro() -> void:
	shade(); panel(Rect2(250,105,780,590),Color("244954"),28)
	lighthouse(Vector2(900,210))
	label("海岛守夜手册",Vector2(300,167),17,TEAL)
	label("今晚，由你点亮归途。",Vector2(300,221),32,CREAM)
	label("五处潮池被梦影占据。用六件遗灯净化它们，",Vector2(300,282),22,CREAM)
	label("在心火熄灭前，把光送到月蚀灯塔。",Vector2(300,317),22,CREAM)
	label("01   选遗灯 → 点潮池。每次行动消耗 1 耐久。",Vector2(300,379),20,GOLD)
	label("02   力量恰好等于强度：耐久返还，护光 +1。",Vector2(300,425),20,GOLD)
	label("03   潮影红点归零会袭击；盐晶可十字连爆。",Vector2(300,471),20,GOLD)
	label("珊瑚回复 3 心火 · 航灯获得 3 护光 · 每关可回溯一次",Vector2(300,526),17,Color("b6d1cb"))
	button(Rect2(300,576,430,65),"提灯出发", "begin",true,24)
	button(Rect2(750,576,230,65),"返回海岛", "exit",false,22)
func draw_pause() -> void:
	shade(); panel(Rect2(390,190,500,420),Color("244954"),24)
	label("让潮声等一会儿",Vector2(440,255),29,CREAM)
	button(Rect2(440,300,400,64),"继续守夜", "pause",true)
	button(Rect2(440,384,400,64),"重新出发", "retry")
	button(Rect2(440,468,400,64),"返回海岛", "exit")
func draw_upgrade() -> void:
	shade(); panel(Rect2(175,190,930,430),Color("244954"),26)
	label("航标点亮 · 漂流礼物",Vector2(225,258),32,GOLD)
	label("所有遗灯已准备修复。选一份礼物，驶向下一片海。",Vector2(225,307),21,CREAM)
	var names = ["温暖灯芯", "铜环加固", "结晶共鸣"]
	var descriptions = ["心火上限 +3\n回复 7 心火", "全遗灯耐久上限 +1\n回复 3 心火", "盐晶爆炸力量 +1\n回复 3 心火"]
	for i in range(3):
		var r = Rect2(225+i*285,350,260,205)
		button(r,"", "upgrade%d"%i)
		label(names[i],r.position+Vector2(25,45),26,GOLD)
		var lines = descriptions[i].split("\n")
		label(lines[0],r.position+Vector2(25,94),18,CREAM); label(lines[1],r.position+Vector2(25,126),18,CREAM)
		label("选择 →",r.position+Vector2(25,177),19,TEAL)
func draw_result() -> void:
	shade(); panel(Rect2(285,165,710,475),Color("244954"),28)
	label("归途已有光" if state.status == "won" else "潮水带走了微光",Vector2(340,237),38,GOLD)
	label("五座航标连成星河。小岛，晚安。" if state.status == "won" else "别担心，灯塔会等你再一次出发。",Vector2(340,290),22,CREAM)
	label("净化旅程  %d / 5    ·    行动 %d" % [state.room+1,state.moves],Vector2(340,353),23,TEAL)
	label("精准净化 %d    ·    最佳纪录 %d" % [state.exact,profile.best_exact],Vector2(340,397),23,TEAL)
	label("累计守夜成功 %d 次" % profile.wins,Vector2(340,440),18,Color("a9c8c5"))
	button(Rect2(340,505,275,70),"再守一夜", "retry",true,24)
	button(Rect2(640,505,295,70),"返回海岛", "exit",false,24)
func _input(event: InputEvent) -> void:
	if not started: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not intro: paused = not paused; get_viewport().set_input_as_handled()
		elif not intro and not paused and state.status == "play":
			if event.keycode >= KEY_1 and event.keycode <= KEY_6: selected = event.keycode-KEY_1
			if event.keycode == KEY_Z: action("undo")
	if event is InputEventMouseMotion:
		var p = (event.position-canvas_origin)/canvas_scale; hover = -1
		for i in range(20):
			if cell_rect(i).has_point(p): hover = i
	var clicked = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1
	if clicked or (event is InputEventScreenTouch and event.pressed):
		var p = (event.position-canvas_origin)/canvas_scale
		for b in buttons:
			if b.rect.has_point(p): get_viewport().set_input_as_handled(); action(b.id); return
		if not intro and not paused and state.status == "play":
			for i in range(20):
				if cell_rect(i).has_point(p): play_cell(i); get_viewport().set_input_as_handled(); return
func play_cell(i: int) -> void:
	var before = state.duplicate(true)
	if Rules.act(state,selected,i):
		undo_state = before; last_cells = Rules.affected(selected,i); flash = 0.65
		impact_origin = cell_rect(i).get_center(); exact_flash = state.exact > before.exact
		for j in range(20):
			if state.board[j] != before.board[j] and j not in last_cells and state.board[j].kind != "wisp": last_cells.append(j)
		tone(660 if state.exact > before.exact else 330)
		if state.status in ["won","lost"]: save_result()
		save_run()
func action(id: String) -> void:
	if id.begins_with("tool"): selected = int(id.trim_prefix("tool")); tone(260+selected*55)
	elif id.begins_with("upgrade"):
		if Rules.upgrade(state,int(id.trim_prefix("upgrade"))): undo_state = {}; undo_used = false; tone(800)
	elif id == "begin": intro = false; tone(550)
	elif id == "retry": reset_run()
	elif id == "pause": paused = not paused
	elif id == "mute": muted = not muted
	elif id == "undo" and not undo_used and not undo_state.is_empty() and state.status == "play":
		state = undo_state.duplicate(true); undo_used = true; state.log = "潮水倒流了一步。每片潮池仅有一次机会。"
	elif id == "exit":
		request_exit(); return
	save_run()
	queue_redraw()
func tone(frequency: float) -> void:
	if muted: return
	var wave = AudioStreamWAV.new(); wave.format = AudioStreamWAV.FORMAT_16_BITS; wave.mix_rate = 22050
	var samples = PackedByteArray(); samples.resize(4410)
	for i in range(2205):
		var v = sin(TAU*frequency*i/22050.0)*0.16*(1.0-i/2205.0)
		samples.encode_s16(i*2,int(v*32767))
	wave.data = samples; audio.stop(); audio.stream = wave; audio.play()

func request_exit() -> void:
	if exiting: return
	exiting = true
	save_run()
	audio.stop(); audio.stream = null
	if get_tree().current_scene == self: get_tree().quit(); return
	exit_requested.emit()
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var handler = context.get("quit_handler",Callable())
		if handler is Callable and handler.is_valid(): handler.call()
		else: request_exit()

func draw_portrait_modal() -> void:
	shade(); panel(Rect2(35,210,690,850),Color("244954"),28)
	if intro:
		label("今晚，由你点亮归途。",Vector2(75,290),34,CREAM)
		label("五处潮池，六件遗灯。",Vector2(75,355),26,GOLD)
		label("选遗灯，再点潮池。每次消耗 1 耐久。",Vector2(75,425),23,CREAM)
		label("力量恰好等于强度：",Vector2(75,490),25,GOLD)
		label("返还耐久，护光 +1。",Vector2(75,531),25,GOLD)
		label("红点归零，潮影袭击。",Vector2(75,605),23,CREAM)
		label("盐晶十字连爆，珊瑚回复心火。",Vector2(75,651),23,CREAM)
		label("每关可回溯一步。",Vector2(75,697),23,CREAM)
		button(Rect2(75,790,610,85),"提灯出发","begin",true,28)
		button(Rect2(75,905,610,85),"返回海岛","exit",false,26)
	elif paused:
		label("让潮声等一会儿",Vector2(75,310),34,CREAM)
		button(Rect2(75,420,610,100),"继续守夜","pause",true,28)
		button(Rect2(75,560,610,100),"重新出发","retry",false,28)
		button(Rect2(75,700,610,100),"返回海岛","exit",false,28)
	elif state.status == "upgrade":
		label("航标点亮 · 漂流礼物",Vector2(75,300),32,GOLD)
		label("遗灯全部修复。选择下一夜的力量。",Vector2(75,355),23,CREAM)
		button(Rect2(75,420,610,125),"温暖灯芯：上限 +3，回复 7","upgrade0",false,25)
		button(Rect2(75,585,610,125),"铜环加固：耐久 +1，回复 3","upgrade1",false,25)
		button(Rect2(75,750,610,125),"结晶共鸣：爆炸 +1，回复 3","upgrade2",false,25)
	else:
		label("归途已有光" if state.status == "won" else "潮水带走了微光",Vector2(75,310),36,GOLD)
		label("旅程 %d / 5    行动 %d" % [state.room+1,state.moves],Vector2(75,420),28,CREAM)
		label("精准 %d    最佳 %d" % [state.exact,profile.best_exact],Vector2(75,480),28,TEAL)
		button(Rect2(75,640,610,100),"再守一夜","retry",true,28)
		button(Rect2(75,790,610,100),"返回海岛","exit",false,28)

func _exit_tree() -> void:
	if is_instance_valid(audio): audio.stop(); audio.stream = null

func save_run() -> void:
	if started and not intro: Store.save_run(state,undo_state,undo_used)
func restore_run() -> void:
	var data=Store.load_run()
	if data.is_empty(): return
	state=data.state; undo_state=data.undo; undo_used=data.undo_used; intro=false
	state.log="守夜记录已恢复。潮水在等你。"
