extends Control
## Read-only instrument layer; all authoritative state belongs to Sim.
signal pause_requested(value: bool)
signal retry_requested
signal home_requested
signal ui_sound(name: String)
const SLATE = Color("233d4a")
const CREAM = Color("fff4d6")
const RED = Color("ed654e")
const CYAN = Color("5ce0d2")
const FONT = preload("res://modules/volcano_escape/ui/rescue-sans.otf")
var snapshot_data: Dictionary = {}
var overlay := ""
var map_visible := false
var selection := 0
var action_latched := false
var _scale := 1.0
var _width := 960.0
var _height := 540.0
var _buttons: Array[Rect2] = []
var _labels: Array[String] = []
var _last_status := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)

func reset() -> void:
	snapshot_data.clear()
	map_visible = false
	overlay = ""
	selection = 0
	action_latched = false
	_last_status = ""
	queue_redraw()

func update_snapshot(data: Dictionary) -> void:
	snapshot_data = _presentation(data)
	var status := str(data.get("status", "playing"))
	if status != _last_status and status in ["success", "rescued", "failed", "won", "lost"]:
		overlay = "result"
		selection = 0
		action_latched = false
	_last_status = status
	queue_redraw()

func show_pause() -> void:
	if overlay == "" and _last_status not in ["success", "rescued", "failed", "won", "lost"]:
		overlay = "pause"
		selection = 0
		pause_requested.emit(true)
		queue_redraw()

func _input(event: InputEvent) -> void:
	# A synchronous intent callback may detach this whole game from the host.
	# Consume against the current viewport BEFORE emitting any such signal.
	var input_viewport := get_viewport()
	if input_viewport == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M and overlay == "":
			input_viewport.set_input_as_handled()
			map_visible = not map_visible
		elif event.keycode == KEY_ESCAPE:
			input_viewport.set_input_as_handled()
			if overlay == "": show_pause()
			elif overlay == "pause": _resume()
			elif overlay in ["retry", "home"]: overlay = "pause"; selection = 0
		elif overlay != "":
			input_viewport.set_input_as_handled()
			if event.keycode in [KEY_UP, KEY_W]: selection = posmod(selection - 1, maxi(1, _labels.size()))
			elif event.keycode in [KEY_DOWN, KEY_S, KEY_TAB]: selection = posmod(selection + 1, maxi(1, _labels.size()))
			elif event.keycode in [KEY_ENTER, KEY_SPACE]: _activate(selection)
		queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.double_click:
		var p: Vector2 = event.position / _scale
		if overlay == "" and Rect2(_width - 44, 12, 32, 32).has_point(p):
			input_viewport.set_input_as_handled()
			show_pause()
		elif overlay != "":
			input_viewport.set_input_as_handled()
			for i in _buttons.size():
				if _buttons[i].has_point(p): _activate(i); break

func _resume() -> void:
	overlay = ""
	pause_requested.emit(false)
	ui_sound.emit("click")
	queue_redraw()

func _activate(index: int) -> void:
	if action_latched: return
	ui_sound.emit("click")
	match overlay:
		"pause":
			if index == 0: _resume()
			elif index == 1: overlay = "retry"; selection = 0
			elif index == 2: overlay = "home"; selection = 0
		"retry", "home":
			if index == 0: overlay = "pause"; selection = 0
			elif index == 1:
				action_latched = true
				if overlay == "retry": retry_requested.emit()
				else: home_requested.emit()
		"result":
			action_latched = true
			if index == 0: retry_requested.emit()
			else: home_requested.emit()
	queue_redraw()

func _text(at: Vector2, value: String, color := CREAM, font_size := 14) -> void:
	draw_string(FONT, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _pill(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	draw_style_box(style, rect)

func _draw() -> void:
	_scale = maxf(1.0, minf(size.x / 960.0, size.y / 540.0))
	_width = size.x / _scale
	_height = size.y / _scale
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * _scale)
	_buttons.clear()
	_labels.clear()
	var t := float(snapshot_data.get("time", 0.0))
	# Folded dispatch badge, not a slide-like card.
	draw_colored_polygon(PackedVector2Array([Vector2(12,12),Vector2(177,12),Vector2(188,23),Vector2(188,84),Vector2(12,84)]), Color(SLATE, .94))
	draw_line(Vector2(177,12),Vector2(177,23),CYAN,2)
	draw_line(Vector2(177,23),Vector2(188,23),CYAN,2)
	draw_arc(Vector2(36,39),17,0,TAU,40,Color("526775"),3,true)
	draw_arc(Vector2(36,39),17,-PI/2,-PI/2+TAU*clampf(1-t/330.0,.01,1),40,CYAN,3,true)
	# Clock hands make the ring semantic; elapsed time is printed only once.
	draw_line(Vector2(36,39),Vector2(36,29),CREAM,2,true)
	draw_line(Vector2(36,39),Vector2(43,43),CREAM,2,true)
	draw_circle(Vector2(36,39),2,CREAM)
	_text(Vector2(62,32), "火山岛 / %02d:%02d" % [int(t)/60,int(t)%60], CREAM, 13)
	for i in 3:
		var p := Vector2(68+i*18,67)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-6,-4),p+Vector2(0,-7),p+Vector2(6,-4),p+Vector2(6,3),p+Vector2(0,7),p+Vector2(-6,3)]), CYAN if i < int(snapshot_data.get("health",3)) else Color("526775"))
	_text(Vector2(126,72), "灯 %d/3" % _beacons(), CREAM, 12)
	_text(Vector2(62,51), str(snapshot_data.get("phase", "观察航线")), CYAN, 14)
	var exits: Array = snapshot_data.get("exits", [])
	var chip_w := minf(123, (_width - 250) / 3.0)
	for i in 3:
		var e: Dictionary = exits[i] if i < exits.size() else {}
		var x := _width - 53 - (3-i)*(chip_w+4)
		var state := str(e.get("state", "closed"))
		var ready := state in ["ready", "open"]
		var soon := state == "soon"
		var needs_call := str(e.get("id",""))=="airship" and float(e.get("called_at",-1))<0
		var color := CYAN if ready else (RED if soon else CREAM)
		_pill(Rect2(x,12,chip_w,44), Color(SLATE,.91))
		_text(Vector2(x+7,29), ["南港渡船","东坡气球","西岸飞艇"][i], CREAM, 13)
		_text(Vector2(x+7,47), ("◇ 待呼叫" if needs_call else ("○ 可撤离" if ready else ("△ 即将" if soon else "× 关闭"))) + (" %ds" % ceili(float(e.get("eta",0))) if float(e.get("eta",-1)) >= 0 else ""), color, 12)
	_pill(Rect2(_width-44,12,32,32), SLATE)
	_text(Vector2(_width-35,34), "Ⅱ", CREAM,18)
	var interaction: Dictionary = snapshot_data.get("interaction",{})
	var prompt := str(interaction.get("label", interaction.get("prompt","")))
	if prompt != "":
		var w := minf(_width-24, maxf(220,FONT.get_string_size(prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+64))
		var r := Rect2((_width-w)/2,_height-52,w,36)
		_pill(r,Color(SLATE,.94))
		_text(r.position+Vector2(10,23),"[E]  "+prompt,CREAM,14)
		var progress := clampf(float(interaction.get("progress",0)),0,1)
		draw_line(r.position+Vector2(8,33),r.position+Vector2(8+(w-16)*progress,33),CYAN,3)
	elif t < 12:
		_pill(Rect2(12,_height-49,minf(_width-24,460),33),Color(SLATE,.9))
		_text(Vector2(22,_height-27),"WASD 移动 · E 操作 · Esc 暂停｜虚构卡通灾害，非现实求生指南",CREAM,12)
	if map_visible and overlay == "": _draw_route_map()
	else:
		_pill(Rect2(_width-106,_height-25,94,20),Color(SLATE,.92))
		_text(Vector2(_width-98,_height-10),"M 查看路线",CREAM,12)
	var warnings: Array = snapshot_data.get("warnings",[])
	for i in mini(3,warnings.size()):
		var warn: Dictionary = warnings[i]
		var message := str(warn.get("label",warn.get("type","预警"))) + " · %ds" % ceili(float(warn.get("eta",0)))
		var w := minf(_width-24,FONT.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x+32)
		var pos := Vector2(12 if map_visible else _width-w-12, 96+i*27 if map_visible else 76+i*27)
		_pill(Rect2(pos,Vector2(w,23)),Color(SLATE,.94))
		_text(pos+Vector2(7,16),"△ "+message,RED,13)
	if overlay != "": _draw_overlay(t)
	var save_notice := str(snapshot_data.get("save_status",""))
	if save_notice != "":
		var notice_w := minf(_width-24,FONT.get_string_size(save_notice,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+24)
		_pill(Rect2(12,_height-23,notice_w,20),Color(SLATE,.96))
		_text(Vector2(20,_height-8),"! "+save_notice,CREAM,12)

func _beacons() -> int:
	var value = snapshot_data.get("beacons",0)
	if value is Array:
		var count := 0
		for b in value:
			if b is Dictionary and b.get("lit",false): count += 1
		return count
	return int(value)

func _draw_overlay(t: float) -> void:
	draw_rect(Rect2(0,0,_width,_height),Color(.05,.13,.17,.65))
	var r := Rect2((_width-340)/2,(_height-278)/2,340,278)
	_pill(r,SLATE)
	draw_line(r.position+Vector2(20,14),r.position+Vector2(80,14),CYAN,3)
	var title := "航线暂停"
	var subtitle := "时间与撤离窗口已冻结"
	_labels.assign(["继续航线", "重新出发…", "回到小岛…"])
	if overlay == "retry" or overlay == "home":
		title = "重新出发？" if overlay == "retry" else "返回小岛？"
		subtitle = "本局进度不会保存，也不会记为通关"
		_labels.assign(["取消，继续查看", "确认重新出发" if overlay == "retry" else "确认回岛"])
	elif overlay == "result":
		var won := _last_status in ["success", "won"]
		title = "撤离成功！" if won else "救援队接住了你"
		subtitle = "%s · %02d:%02d · 求援灯 %d/3" % [str(snapshot_data.get("exit_name", "救援回程")),int(t)/60,int(t)%60,_beacons()]
		_labels.assign(["再走一条航线", "回到小岛"])
	_text(r.position+Vector2(22,48),title,CREAM,24)
	_text(r.position+Vector2(22,76),subtitle,CREAM,13)
	for i in _labels.size():
		var b := Rect2(r.position+Vector2(22,97+i*43),Vector2(296,35))
		_buttons.append(b)
		_pill(b,CYAN if selection==i else Color("375461"))
		_text(b.position+Vector2(12,24),("› " if selection==i else "  ")+_labels[i],SLATE if selection==i else CREAM,15)
	_text(r.position+Vector2(22,257),"↑↓ 选择 · Enter 确认 · Esc 返回",CREAM,12)


func _presentation(source: Dictionary) -> Dictionary:
	var out := source.duplicate(true)
	var t := float(source.get("time",0))
	out.phase = "观察航线" if t < 30 else ("留意预警" if t < 100 else ("选择通路" if t < 220 else "最终撤离"))
	out.warnings = []
	for road: Dictionary in source.get("roads",[]):
		if road.get("state", "") == "warning": out.warnings.append({"label":str(road.id).replace("_", " ") + " 路段关闭", "eta":float(road.closes_at)-t})
	for shelter: Dictionary in source.get("shelters",[]):
		if shelter.get("state", "") == "warning": out.warnings.append({"label":str(shelter.get("node", "")) + "站防护失效", "eta":float(shelter.expires_at)-t})
	for rock: Dictionary in source.get("rocks",[]):
		if rock.get("state", "") == "warning":
			var distance := Vector2(source.get("position",Vector2.ZERO)).distance_to(rock.position)
			var label := ("附近落石" if distance <= 12.0 else "远处落石") + " · %d米" % roundi(distance)
			out.warnings.append({"label":label, "eta":float(rock.impact_at)-t})
	out.warnings.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return float(a.eta)<float(b.eta))
	for e: Dictionary in out.get("exits",[]):
		var eta := -1.0
		var open := bool(e.get("open",false))
		if str(e.id)=="airship": open = open and float(e.get("called_at",-1))>=0 and t>=float(e.get("arrives_at",INF))
		for window: Vector2 in e.get("windows",[]):
			if t < window.x: eta = window.x-t; break
			if t < window.y: eta = window.y-t; break
		if str(e.id) == "airship" and float(e.get("called_at",-1)) >= 0 and float(e.get("arrives_at",-1)) > t:
			eta = maxf(eta,float(e.arrives_at)-t)
		e.eta = eta
		e.state = "ready" if open else ("soon" if eta >= 0 and eta <= 30 else "closed")
	var inter: Dictionary = out.get("interaction",{})
	var kind := str(inter.get("kind",""))
	inter.label = ""
	if kind != "":
		var required := float(inter.get("required",1))
		inter.label = ("持续按住 · 充气撤离" if kind == "balloon" else "持续按住 · 呼叫飞艇")+" %.1fs" % maxf(0,required-float(inter.get("progress",0)))
		inter.progress = float(inter.get("progress",0))/maxf(.001,required)
	else:
		inter.progress = 0.0
		var pos: Vector2 = source.get("position",Vector2.ZERO)
		if str(source.get("shelter_id","")) != "": inter.label = "离开人工避险亭"
		else:
			for e: Dictionary in source.get("exits",[]):
				if pos.distance_to(e.position) > 1.25: continue
				if str(e.id)=="airship" and float(e.get("called_at",-1)) < 0: inter.label = "按住 1 秒 · 呼叫飞艇"
				elif str(e.id)=="airship" and t<float(e.get("arrives_at",INF)): inter.label="等待飞艇抵达 · 看上方时钟"
				elif bool(e.get("open",false)): inter.label = "按住 6 秒 · 充气撤离" if str(e.id)=="balloon" else "登艇撤离"
				else: inter.label = "等待接应窗口 · 看上方时钟"
				break
			if str(inter.label)=="":
				for b: Dictionary in source.get("beacons",[]):
					if pos.distance_to(b.position)<=1.25 and not b.get("lit",false): inter.label="点亮求援灯（可选）"; break
			if str(inter.label)=="":
				for shelter: Dictionary in source.get("shelters",[]):
					if pos.distance_to(shelter.position)<=1.25 and shelter.get("state","")!="expired": inter.label="暂避落石 · 人工避险亭"; break
	out.interaction = inter
	var result: Dictionary = source.get("result",{})
	out.exit_name = {"boat":"南港渡船","balloon":"东坡气球","airship":"西岸飞艇"}.get(str(result.get("exit","")),"救援回程")
	return out


func _map_point(world: Vector2, rect: Rect2, low: Vector2, span: Vector2) -> Vector2:
	var scale_factor := minf(rect.size.x/maxf(1,span.x),rect.size.y/maxf(1,span.y))
	return rect.get_center()+(world-low-span*.5)*scale_factor

func _draw_route_map() -> void:
	var r := Rect2(_width-262,_height-268,250,200)
	# Compact translucent dispatch-chart, no route recommendation or undisclosed hazard.
	draw_colored_polygon(PackedVector2Array([r.position,r.position+Vector2(238,0),r.position+Vector2(250,12),r.end,r.position+Vector2(0,200)]),Color(SLATE,.95))
	_text(r.position+Vector2(12,22),"公开航线图",CREAM,14)
	_text(r.position+Vector2(169,22),"M 收起",CYAN,12)
	var nodes: Dictionary = snapshot_data.get("map",{}).get("nodes",{})
	if nodes.is_empty():
		_text(r.position+Vector2(12,55),"等待航线资料",CREAM,12)
		return
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for value: Vector2 in nodes.values(): low=low.min(value); high=high.max(value)
	var graph := Rect2(r.position+Vector2(20,48),Vector2(92,120))
	var span := high-low
	for road: Dictionary in snapshot_data.get("roads",[]):
		var a := _map_point(road.a,graph,low,span)
		var b := _map_point(road.b,graph,low,span)
		var state := str(road.get("state","open"))
		if state == "closed":
			draw_line(a,b,Color("7a6867"),2,true)
			var mid := (a+b)/2
			draw_line(mid-Vector2(3,3),mid+Vector2(3,3),RED,2,true)
			draw_line(mid+Vector2(-3,3),mid+Vector2(3,-3),RED,2,true)
		elif state == "warning": draw_dashed_line(a,b,RED,3,4,true,true)
		else: draw_line(a,b,Color("8daeb1"),2,true)
	for id in nodes:
		var p := _map_point(nodes[id],graph,low,span)
		draw_circle(p,3,CREAM)
		_text(p+Vector2(4,-3),str(id),CREAM,10)
	for shelter: Dictionary in snapshot_data.get("shelters",[]):
		var p := _map_point(shelter.position,graph,low,span)+Vector2(-7,0)
		var state := str(shelter.get("state","open"))
		var color := CYAN if state=="open" else RED
		draw_polyline(PackedVector2Array([p+Vector2(-4,3),p+Vector2(-4,-2),p+Vector2(0,-5),p+Vector2(4,-2),p+Vector2(4,3),p+Vector2(-4,3)]),color,1.5,true)
		if state=="expired": draw_line(p-Vector2(4,4),p+Vector2(4,4),RED,2,true)
	for e: Dictionary in snapshot_data.get("exits",[]):
		var p := _map_point(e.position,graph,low,span)
		var open := str(e.get("state","closed"))=="ready"
		draw_arc(p,6,0,TAU,16,CYAN if open else CREAM,2,true)
		var id := str(e.id)
		# Dedicated right-hand key: no exit name shares a baseline with nodes or legend.
		var label: String = {"boat":"南港渡船","balloon":"东坡气球","airship":"西岸飞艇"}.get(id,id)
		var detail: String = {"boat":"K站 ↓ 南","balloon":"C站 ↗ 东北","airship":"J站 ← 西南"}.get(id,"")
		var label_y: float = {"boat":144.0,"balloon":56.0,"airship":100.0}.get(id,56.0)
		_text(r.position+Vector2(139,label_y),label,CYAN if open else CREAM,12)
		_text(r.position+Vector2(139,label_y+16),detail,CREAM,11)
	var player := _map_point(snapshot_data.get("position",Vector2.ZERO),graph,low,span)
	draw_circle(player,5,SLATE)
	draw_circle(player,3.5,CYAN)
	draw_arc(player,6,0,TAU,16,CREAM,1,true)
	_text(r.position+Vector2(12,38),"↑ 北",CREAM,11)
	_text(r.position+Vector2(139,178),"● 你的位置",CYAN,11)
	_text(r.position+Vector2(12,193),"— 通路  ┄ 预警  × 封闭  △ 人工亭",CREAM,11)
