extends Node2D
signal exit_requested
const Model = preload("res://modules/apprentice_yokai_king/run_model.gd")
const Store = preload("res://modules/apprentice_yokai_king/profile_store.gd")
const FONT = preload("res://modules/apprentice_yokai_king/ui/yokai-sans.otf")
const INK = Color("494354")
const PAPER = Color("fff9e7")
const TEAL = Color("82cdb6")
const ROSE = Color("ecacba")
const BASE = "res://modules/apprentice_yokai_king/"
var model = Model.new()
var profile = Store.new()
var started = false
var hosted = false
var exiting = false
var buttons: Array = []
var textures: Dictionary = {}
var edges: Dictionary = {}
var held_keys: Dictionary = {}
var paused_from = "combat"
var show_settings = false
var quit_confirm = false
var rebind = ""
var assist = false
var skip_practice = false
var run_id = ""
var recorded = false
var audio: Node
var visual_time = 0.0
var last_phase = "title"
var bindings = {"up":KEY_W,"down":KEY_S,"left":KEY_A,"right":KEY_D,"dodge":KEY_SPACE,"pause":KEY_ESCAPE}
var previous_auto_accept_quit = true
var art_ready = false
var reset_confirm = false
var shake_time = 0.0
var pointer = Vector2(900,400)
var audio_track = "theme"
const CARD_ART = {"ayk_core_wind":"wind_core","ayk_wind_step":"wind_step","ayk_wind_return":"wind_return","ayk_core_thunder":"thunder_core","ayk_thunder_chain":"thunder_chain","ayk_thunder_charge":"thunder_charge","ayk_core_quake":"quake_core","ayk_quake_slow":"quake_slow","ayk_quake_echo":"quake_echo","ayk_fast":"fast_handle","ayk_elastic":"elastic_head","ayk_roll":"round_roll"}

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
	if not hosted:
		previous_auto_accept_quit = get_tree().auto_accept_quit
		get_tree().auto_accept_quit = false
	if context.get("game_id","apprentice_yokai_king") != "apprentice_yokai_king" or context.get("save_root","user://games/apprentice_yokai_king") not in ["user://games/apprentice_yokai_king","user://games/apprentice_yokai_king/"]:
		push_warning("Yokai King rejected foreign context; fixed private save namespace remains in use.")
	profile.load_profile()
	for key in profile.data.settings.get("bindings",{}): bindings[key] = int(profile.data.settings.bindings[key])
	for key in ["hero","grunt","shield","spring","bubble","sleeper","elite","boss","arena"]:
		var path = BASE+"art/"+key+".png"
		if key in ["grunt","shield","spring","bubble","sleeper","boss"] and ResourceLoader.exists(BASE+"art/"+key+"-strip.png"): path = BASE+"art/"+key+"-strip.png"
		if key == "elite" and ResourceLoader.exists(BASE+"art/grunt-strip.png"): path = BASE+"art/grunt-strip.png"
		if ResourceLoader.exists(path): textures[key] = load(path)
	for id in CARD_ART:
		var path = BASE+"art/ui/"+CARD_ART[id]+".png"
		if ResourceLoader.exists(path): textures[id] = load(path)
	if ResourceLoader.exists(BASE+"art/ui/heart.png"): textures["heart"] = load(BASE+"art/ui/heart.png")
	art_ready = textures.has("hero")
	if ResourceLoader.exists(BASE+"audio/audio_director.gd"):
		audio = load(BASE+"audio/audio_director.gd").new(); add_child(audio); audio.start(); audio.set_volume(0.6 if profile.data.settings.sound else 0.0)
	queue_redraw()

func resize():
	var viewport_size = get_viewport_rect().size
	var factor = minf(viewport_size.x/1280.0,viewport_size.y/800.0)
	scale = Vector2.ONE*factor
	position = (viewport_size-Vector2(1280,800)*factor)/2

func _exit_tree():
	if started and not hosted: get_tree().auto_accept_quit = previous_auto_accept_quit

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST and started and not hosted: exit_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and model.phase in ["combat","practice","countdown"]: pause_run()

func new_run():
	model.reset(int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec(),"assist" if assist else "standard",not skip_practice)
	run_id = "%d-%d" % [Time.get_unix_time_from_system(),Time.get_ticks_usec()]
	recorded = false; quit_confirm = false; show_settings = false; edges.clear(); held_keys.clear()
	if audio:
		audio.set_paused(false); audio.start("theme"); audio_track = "theme"

func _process(delta):
	if not started or exiting: return
	visual_time += delta
	shake_time = maxf(0,shake_time-delta)
	var movement = Vector2(float(key_down("right",KEY_RIGHT))-float(key_down("left",KEY_LEFT)),float(key_down("down",KEY_DOWN))-float(key_down("up",KEY_UP)))
	var aim = pointer-model.player
	if profile.data.settings.aim_assist:
		var nearest = 180.0
		for enemy in model.enemies:
			var offset: Vector2 = enemy.pos-model.player
			if offset.length() < nearest and aim.normalized().dot(offset.normalized()) > 0.6: nearest = offset.length(); aim = offset
	var input = edges.duplicate(); input.move = movement; input.aim = aim
	edges.clear()
	model.advance(delta,input)
	if audio and model.wave == 6 and audio_track != "boss":
		audio.start("boss"); audio_track = "boss"
	for event in model.events:
		if event == "hurt" and profile.data.settings.screen_shake: shake_time = 0.15
		if audio: audio.cue(event)
	model.events.clear()
	if model.phase in ["won","lost"] and not recorded:
		recorded = true
		profile.record_result(model.mode,model.phase == "won",model.wave,model.elapsed,model.build.core,model.seen,run_id)
	if last_phase != model.phase:
		held_keys.clear(); edges.clear(); last_phase = model.phase
	queue_redraw()

func key_down(action: String, alternate: int) -> bool:
	return held_keys.get(bindings[action],false) or held_keys.get(alternate,false)

func _input(event):
	if exiting or not started: return
	if event is InputEventMouseMotion:
		pointer = get_global_transform_with_canvas().affine_inverse()*event.position
		return
	if event is InputEventKey:
		if event.echo: return
		if rebind != "" and event.pressed:
			bindings[rebind] = event.physical_keycode; rebind = ""; save_settings(); get_viewport().set_input_as_handled(); return
		held_keys[event.physical_keycode] = event.pressed
		if event.pressed:
			if event.physical_keycode == bindings.pause:
				if show_settings: show_settings = false
				elif quit_confirm: quit_confirm = false
				elif model.phase == "paused": resume_run()
				elif model.phase in ["combat","practice","countdown","choice"]: pause_run()
			elif event.physical_keycode == bindings.dodge: edges.dodge = true
			elif event.physical_keycode == KEY_ENTER and model.phase == "practice": edges.skip = true
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var p = get_global_transform_with_canvas().affine_inverse()*event.position
		pointer = p
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for button in buttons:
				if button.rect.has_point(p): action(button.id); get_viewport().set_input_as_handled(); return
		if show_settings or quit_confirm:
			get_viewport().set_input_as_handled(); return
		if model.phase in ["combat","practice"]:
			if profile.data.settings.charge_mode == "hold_primary" and event.button_index == MOUSE_BUTTON_LEFT:
				edges["press" if event.pressed else "release"] = true
			elif profile.data.settings.charge_mode == "right_charge":
				if event.button_index == MOUSE_BUTTON_LEFT and event.pressed: edges.press = true; edges.release = true
				elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
					edges["release" if model.charge >= 0 else "press"] = true
		get_viewport().set_input_as_handled()

func pause_run():
	if not model.phase in ["combat","practice","countdown","choice"]: return
	paused_from = model.phase; model.phase = "paused"; model.charge = -1; edges.clear(); held_keys.clear(); model.queued.clear(); model.accumulator = 0
	if audio: audio.set_paused(true)

func resume_run():
	if model.phase != "paused": return
	model.phase = paused_from; edges.clear(); held_keys.clear(); model.queued.clear(); model.accumulator = 0
	if audio: audio.set_paused(false)

func save_settings():
	profile.data.settings.bindings = bindings.duplicate()
	profile.save_profile()
	if audio: audio.set_volume(0.6 if profile.data.settings.sound else 0.0)

func action(id: String):
	buttons.clear() # Invalidate old hit targets immediately, including same-frame double clicks.
	if id.begins_with("card:"):
		model.select_card(id.substr(5)); return
	if id.begins_with("bind:"): rebind = id.substr(5); return
	if id.begins_with("setting:"):
		var setting = id.substr(8); profile.data.settings[setting] = not profile.data.settings[setting]; save_settings(); return
	match id:
		"start", "retry":
			if model.phase in ["title","won","lost"]: new_run()
		"assist": assist = not assist
		"practice": skip_practice = not skip_practice
		"skip": edges.skip = true
		"pause": pause_run()
		"resume": resume_run()
		"settings": show_settings = true
		"back": show_settings = false; rebind = ""; reset_confirm = false
		"reset_profile":
			if reset_confirm: profile.reset_profile(true); reset_confirm = false
			else: reset_confirm = true
		"charge_mode": profile.data.settings.charge_mode = "right_charge" if profile.data.settings.charge_mode == "hold_primary" else "hold_primary"; save_settings()
		"reroll": model.build.reroll()
		"exit":
			if model.phase in ["title","won","lost"]: exit_game()
			else: quit_confirm = true
		"cancel_exit": quit_confirm = false
		"confirm_exit": exit_game()
		"title": model.phase = "title"; show_settings = false

func exit_game():
	if exiting: return
	exiting = true; edges.clear(); held_keys.clear(); set_process_input(false)
	if audio: await audio.shutdown()
	if hosted: exit_requested.emit()
	else: get_tree().quit()

func text_at(text: String, p: Vector2, size: int = 22, color: Color = INK):
	draw_string(FONT,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func centered(text: String, y: float, size: int = 24, color: Color = INK):
	text_at(text,Vector2((1280-FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)/2,y),size,color)

func panel(rect: Rect2, color: Color = PAPER):
	var style = StyleBoxFlat.new(); style.bg_color = color; style.border_color = INK; style.set_border_width_all(3); style.set_corner_radius_all(22); style.shadow_color = Color(INK,0.12); style.shadow_size = 5; style.shadow_offset = Vector2(0,5)
	draw_style_box(style,rect)

func button(id: String,label: String,rect: Rect2,color: Color = TEAL):
	buttons.append({"id":id,"rect":rect})
	panel(rect,color.lightened(0.12) if rect.has_point(pointer) else color)
	var size = 22
	text_at(label,rect.position+Vector2((rect.size.x-FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)/2,rect.size.y/2+8),size)

func wrapped(text: String, rect: Rect2, size: int = 20):
	var line = ""; var y = rect.position.y
	for c in text:
		if c == "\n" or FONT.get_string_size(line+c,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x > rect.size.x:
			text_at(line,Vector2(rect.position.x,y),size); y += size*1.5; line = ""
		if c != "\n": line += c
	text_at(line,Vector2(rect.position.x,y),size)

func _draw():
	buttons.clear()
	draw_rect(Rect2(-2000,-2000,5280,4800),Color("dfe8d2"))
	if textures.has("arena"): draw_texture_rect(textures.arena,Rect2(0,0,1280,800),false)
	else:
		draw_rect(Rect2(36,135,1208,620),Color("c4d9ad"))
		for i in range(80):
			var p = Vector2(60+(i*137)%1160,155+(i*73)%570)
			draw_line(p,p+Vector2(3,-6),Color("b1c79a"),2)
	panel(Rect2(28,20,1224,96))
	text_at("见习小妖王",Vector2(53,62),28)
	text_at("APPRENTICE YOKAI KING",Vector2(54,88),12,Color("86798d"))
	if model.phase == "title": draw_title()
	else:
		draw_set_transform(Vector2(sin(visual_time*71)*3,cos(visual_time*61)*3) if shake_time > 0 else Vector2.ZERO)
		draw_world(); draw_set_transform(Vector2.ZERO); draw_hud()
	if model.phase == "practice":
		panel(Rect2(290,155,700,102))
		centered("先试试大木槌！安全练习 %d 秒" % ceil(model.practice_time),191,24)
		centered("移动 WASD · 左键短按挥槌 / 长按释放砸地 · 空格闪避",225,18)
		button("skip","准备好啦 →",Rect2(1010,670,220,54))
	elif model.phase == "countdown":
		panel(Rect2(440,320,400,145)); centered("第 %d 波 · 准备" % model.wave,372,30); centered(str(ceili(model.countdown)),430,40)
	elif model.phase == "choice": draw_choices()
	elif model.phase == "paused": draw_pause()
	elif model.phase in ["won","lost"]: draw_result()
	if show_settings:
		buttons.clear(); draw_settings()
	if quit_confirm:
		buttons.clear()
		draw_rect(Rect2(0,0,1280,800),Color(INK,0.45)); panel(Rect2(340,250,600,280)); centered("要回去休息吗？",315,30); centered("本局进度不保存；中途退出不计失败。",365,22)
		button("cancel_exit","继续玩",Rect2(390,425,220,60)); button("confirm_exit","退出本局",Rect2(670,425,220,60),ROSE)
	if not profile.warning.is_empty(): text_at(profile.warning,Vector2(40,783),15,Color("825c62"))

func draw_title():
	panel(Rect2(110,165,1060,555))
	text_at("小小妖王，",Vector2(170,254),48); text_at("今天也要威风！",Vector2(170,320),48)
	text_at("主动挥大槌 · 灵巧躲包围 · 五次选择成就你的流派",Vector2(172,375),22)
	text_at("六波有限战斗，最后挑战鼓肚大王。只需保护自己。",Vector2(172,413),20)
	draw_actor("hero",Vector2(1000,415),"idle",1.1,1)
	button("start","出发，练习当大王",Rect2(170,458,420,72))
	button("assist","难度：辅助 +50%时限" if assist else "难度：标准",Rect2(650,458,450,58),Color("e4d4ed"))
	button("practice","安全练习：跳过" if skip_practice else "安全练习：20 秒",Rect2(650,533,450,58),Color("e4d4ed"))
	button("settings","设置 / 按键",Rect2(170,558,198,58),Color("f4d58a")); button("exit","返回" if hosted else "退出",Rect2(392,558,198,58),ROSE)
	var record = profile.data.records["assist" if assist else "standard"]
	text_at("本难度：完成 %d 局 · 胜利 %d · 最远第 %d 波" % [record.runs_finished,record.wins,record.best_wave],Vector2(172,664),20)

func draw_hud():
	var hearts = ""
	for i in range(model.max_hp): hearts += "● " if i < model.hp else "○ "
	if textures.has("heart"):
		for i in range(model.max_hp):
			draw_texture_rect(textures.heart,Rect2(325+i*38,35,32,32),false,Color.WHITE if i < model.hp else Color(1,1,1,0.2))
	else: text_at(hearts,Vector2(325,62),27,Color("bd647f"))
	text_at("第 %d / 6 波  ·  待击退 %d" % [model.wave,model.enemies.size()+model.pending.size()],Vector2(325,91),18)
	var remaining = maxi(0,ceili(model.limit()-model.wave_time))
	text_at("%02d:%02d" % [remaining/60,remaining%60],Vector2(790,65),34,Color("b85a58") if remaining <= 30 else INK)
	text_at("闪避就绪" if model.dodge_cd <= 0 else "闪避 %.1f s" % model.dodge_cd,Vector2(790,92),17)
	if model.phase in ["combat","practice","countdown","choice"]: button("pause","暂停 Esc",Rect2(1055,41,166,49),Color("e4d4ed"))
	text_at("WASD 移动  ·  左键挥槌 / 蓄力  ·  空格翻滚",Vector2(40,760),18)
	if model.build.core != "": text_at(model.build.card_title(model.build.core),Vector2(870,760),19)
	if remaining <= 30 and model.phase == "combat": centered("最后 %d 秒！主动击退全部敌人才能过关" % remaining,145,20,Color("9a464e"))

func draw_world():
	for p in model.pending:
		if p.at-model.spawn_clock <= 1.2:
			draw_arc(p.pos,30,0,TAU,24,Color("aa705d"),3); text_at("!",p.pos+Vector2(-4,7),25)
	for e in model.enemies: draw_danger(e)
	for effect in model.effects:
		var col = Color("f4dd98")
		if effect.kind == "ayk_core_wind": col = Color("82d6cd")
		elif effect.kind == "ayk_core_thunder": col = Color("c8a8e5")
		elif effect.kind == "ayk_core_quake": col = Color("e9bc86")
		col.a = 0.25 if profile.data.settings.reduced_flashes else 0.4
		if effect.kind == "swing":
			var angle: float = effect.direction.angle()
			draw_arc(effect.pos,118,angle-deg_to_rad(55),angle+deg_to_rad(55),32,col,12)
		else: draw_arc(effect.pos,effect.radius,0,TAU,48,col,5)
		if effect.kind == "ayk_core_wind": draw_line(effect.pos,effect.pos+effect.direction*240,col,18)
	for p in model.projectiles:
		draw_circle(p.pos,14,Color("c4daf1")); draw_arc(p.pos,14,0,TAU,20,INK,2); draw_circle(p.pos+Vector2(-4,-4),4,Color.WHITE)
	var actors = model.enemies.duplicate(); actors.append({"kind":"hero","pos":model.player})
	actors.sort_custom(func(a,b): return a.pos.y < b.pos.y)
	for e in actors:
		if e.kind == "hero":
			if model.invulnerable <= 0 or profile.data.settings.reduced_flashes or fmod(visual_time,0.12) < 0.08: draw_actor("hero",model.player,"defeat" if model.phase == "lost" else ("hurt" if model.hurt_time > 0 else model.animation),0.55,1 if model.facing.x >= 0 else -1)
		else:
			var anim = "anticipation" if e.state == "windup" else ("attack" if e.state in ["slide","recover"] else ("hurt" if e.vel.length() > 10 else "move"))
			draw_actor(e.kind,e.pos,anim,0.72 if e.kind == "boss" else (0.52 if e.kind == "elite" else 0.38),1 if e.face.x >= 0 else -1)
			var width = 90.0 if e.kind == "boss" else 43.0
			draw_line(e.pos+Vector2(-width/2,10),e.pos+Vector2(width/2,10),Color(INK,0.25),5)
			draw_line(e.pos+Vector2(-width/2,10),e.pos+Vector2(-width/2+width*maxf(0,e.hp/e.max_hp),10),Color("b5799c"),5)
			if e.kind in ["boss","elite"]:
				text_at("硬直 %d/3" % e.stagger,e.pos+Vector2(-34,29),12)
	if model.charge >= 0:
		draw_arc(model.player+Vector2(0,-32),49,-PI/2,-PI/2+TAU*minf(1,model.charge/0.75),32,Color("fff3b2"),6)
		draw_arc(model.player+model.facing*62,94,0,TAU,48,Color(INK,0.18),2)
	if model.shield: draw_arc(model.player+Vector2(0,-25),48,0,TAU,40,Color("a6cfe6"),4)

func draw_actor(kind: String, pos: Vector2, anim: String, factor: float, facing: int):
	draw_set_transform(pos)
	draw_set_transform(pos,0,Vector2(1,0.35)); draw_circle(Vector2.ZERO,32 if kind != "boss" else 55,Color(INK,0.16)); draw_set_transform(Vector2.ZERO)
	if textures.has(kind):
		var texture: Texture2D = textures[kind]
		var source = Rect2(Vector2.ZERO,texture.get_size())
		var frame_size = Vector2(256,256)
		if kind == "hero" and texture.get_width() >= 1024 and texture.get_height() >= 2048:
			var row = ["idle","move","light","charge","slam","dodge","hurt","defeat"].find(anim)
			if row < 0: row = 0
			var frame = int(visual_time*(12 if anim == "move" else 8))%4
			if anim in ["light","slam","dodge","defeat"]: frame = mini(3,int(model.animation_time*12))
			if anim == "hurt": frame = mini(3,int((0.25-model.hurt_time)*16))
			source = Rect2(Vector2(frame*256,row*256),frame_size)
		elif texture.get_width() >= 1024 and texture.get_height() >= 256:
			var frame = 2 if anim == "anticipation" else (3 if anim in ["attack","hurt"] else (int(visual_time*6)%2))
			source = Rect2(Vector2(frame*256,0),frame_size)
			facing *= -1
		else: frame_size = texture.get_size()
		draw_set_transform(pos,0,Vector2(factor*facing,factor))
		draw_texture_rect_region(texture,Rect2(Vector2(-frame_size.x/2,-frame_size.y*220/256),frame_size),source)
		draw_set_transform(Vector2.ZERO)
	else:
		# Explicit engineering-only fallback; acceptance requires actual art assets.
		var color = {"hero":"95cfc0","grunt":"ceacd2","shield":"a9c98d","spring":"efbb82","bubble":"91c7dc","sleeper":"d6bad6","elite":"d89fb9","boss":"e6ba7b"}.get(kind,"ffffff")
		draw_circle(pos+Vector2(0,-28),30 if kind != "boss" else 58,INK); draw_circle(pos+Vector2(0,-28),27 if kind != "boss" else 54,Color(color)); draw_circle(pos+Vector2(-9,-33),4,INK); draw_circle(pos+Vector2(9,-33),4,INK)
		if kind == "hero": draw_line(pos+Vector2(12,-22),pos+Vector2(51,-60),INK,8); draw_rect(Rect2(pos+Vector2(28,-74),Vector2(45,25)),Color("c19870"))

func draw_danger(e: Dictionary):
	if e.state != "windup" and e.state != "slide": return
	var danger = Color("d36d72")
	var fill = Color(danger,0.16)
	if e.kind in ["spring","sleeper"]:
		draw_circle(e.target,65,fill); draw_arc(e.target,65,0,TAU,32,danger,3); draw_line(e.target-Vector2(14,14),e.target+Vector2(14,14),danger,3); draw_line(e.target+Vector2(-14,14),e.target+Vector2(14,-14),danger,3)
	elif e.kind == "boss" and e.move%3 == 1:
		var end: Vector2 = e.pos+e.face*430
		draw_line(e.pos,end,fill,120); draw_line(e.pos,end,danger,3)
		for i in range(5): draw_arc(e.pos+e.face*i*85,16,e.face.angle()-0.7,e.face.angle()+0.7,8,danger,3)
	elif e.kind == "boss" and e.move%3 == 2:
		var radius = 90+e.rings*65
		draw_arc(e.pos,radius,0,TAU,64,fill,56); draw_arc(e.pos,radius-28,0,TAU,64,danger,2); draw_arc(e.pos,radius+28,0,TAU,64,danger,2)
	else:
		var radius = 155 if e.kind == "boss" else (95 if e.kind == "elite" else 64)
		if e.kind == "bubble": draw_line(e.pos,e.target,danger,2); return
		var angle: float = e.face.angle()
		var points = PackedVector2Array([e.pos])
		for i in range(21): points.append(e.pos+Vector2.from_angle(angle-1.45+i*2.9/20)*radius)
		draw_colored_polygon(points,fill); draw_polyline(points,danger,2)
	text_at("!",e.pos+Vector2(-5,-85),28,danger)

func draw_choices():
	draw_rect(Rect2(0,118,1280,682),Color(INK,0.32))
	panel(Rect2(70,150,1140,560)); centered("第 %d 波完成 · 选一个新本领" % model.wave,205,31); centered(model.last_heal,245,20)
	var offers = model.build.offers()
	for i in range(offers.size()):
		var id = offers[i]; var rect = Rect2(110+i*365,280,330,300)
		panel(rect,Color("f8edce") if i == 0 else (Color("e5dcef") if i == 1 else Color("d7eada")))
		text_at("%02d" % (i+1),rect.position+Vector2(22,42),25,Color("99889b"))
		if textures.has(id): draw_texture_rect(textures[id],Rect2(rect.position+Vector2(245,12),Vector2(65,65)),false)
		wrapped(model.build.card_title(id),Rect2(rect.position+Vector2(22,91),Vector2(290,80)),24)
		wrapped(model.build.card_description(id),Rect2(rect.position+Vector2(22,150),Vector2(285,120)),18)
		button("card:"+id,"学会这一招",Rect2(rect.position+Vector2(24,235),Vector2(282,48)))
	if not model.build.reroll_used: button("reroll","免费重抽 · 仅一次",Rect2(450,620,380,55),Color("f4d58a"))
	else: centered("本局重抽已使用 · 选择不限时",655,20)

func draw_pause():
	draw_rect(Rect2(0,118,1280,682),Color(INK,0.38)); panel(Rect2(410,205,460,420)); centered("小妖王歇一会儿",270,30); centered("时间、敌人和招式都已暂停",313,20)
	button("resume","继续战斗",Rect2(460,350,360,60)); button("settings","设置 / 按键",Rect2(460,433,360,60),Color("f4d58a")); button("exit","结束本局并返回",Rect2(460,516,360,60),ROSE)

func draw_result():
	draw_rect(Rect2(0,118,1280,682),Color(INK,0.32)); panel(Rect2(290,190,700,465)); centered("今天正式成为小妖王！" if model.phase == "won" else "休息一下，再来挑战",260,34); centered(model.result_reason,311,23)
	centered("%s · 第 %d 波 · 战斗 %d 分 %d 秒" % ["辅助记录" if model.mode == "assist" else "标准记录",model.wave,int(model.elapsed)/60,int(model.elapsed)%60],365,22)
	centered("本局选择 %d / 5 · 击退 %d 个本波敌人" % [model.build.chosen_count,model.defeated],407,20)
	button("retry","再来一局",Rect2(360,470,250,63)); button("exit","返回" if hosted else "退出",Rect2(670,470,250,63),ROSE)
	button("title","回标题调整难度",Rect2(460,565,360,50),Color("e4d4ed"))

func draw_settings():
	draw_rect(Rect2(0,0,1280,800),Color(INK,0.55)); panel(Rect2(180,105,920,620)); centered("按自己的节奏挥槌",160,30)
	var settings = profile.data.settings
	button("setting:sound","声音："+("开" if settings.sound else "关"),Rect2(225,200,380,52))
	button("setting:aim_assist","瞄准辅助："+("开" if settings.aim_assist else "关"),Rect2(650,200,400,52))
	button("setting:reduced_flashes","低闪光："+("开" if settings.reduced_flashes else "关"),Rect2(225,275,380,52))
	button("setting:screen_shake","震动："+("开" if settings.screen_shake else "关"),Rect2(650,275,400,52))
	button("charge_mode","蓄力：左键长按释放" if settings.charge_mode == "hold_primary" else "蓄力：右键切换，左键轻击",Rect2(225,350,825,52),Color("f4d58a"))
	var keys = ["up","down","left","right","dodge","pause"]
	var names = ["向上","向下","向左","向右","闪避","暂停"]
	for i in range(6): button("bind:"+keys[i],names[i]+" "+OS.get_keycode_string(bindings[keys[i]]),Rect2(225+(i%3)*280,435+(i/3)*65,260,50),Color("e4d4ed"))
	centered("请按新按键："+rebind if rebind != "" else "点击按键即可重设 · 方向键也可移动 · 鼠标不自动攻击",601,18)
	button("back","保存并返回",Rect2(225,640,380,53))
	button("reset_profile","再次点击：确认重置" if reset_confirm else "重置本模块记录",Rect2(650,640,400,53),ROSE)
