extends Node2D
## The module owns only local UI, local audio and its namespaced profile.
signal exit_requested
signal sound_requested(kind: String)
const Cards = preload("cards.gd")
const Rules = preload("rules.gd")
const AI = preload("ai.gd")
const Store = preload("profile_store.gd")
const View = preload("ui/board_view.gd")
var store = Store.new()
var profile: Dictionary = {}
var game_state: Dictionary = {}
var context: Dictionary = {}
var view: Control
var audio: Node
var started := false
var running := false
var paused := false
var exiting := false
var phase := "select"
var modal := ""
var exit_intent := "home"
var selected_deck := "forest"
var opponent_deck := "toys"
var selected_hand := -1
var selected_attacker := -1
var detail_card := ""
var ai_delay := 0.0
var elapsed := 0.0
var notice := "选一副牌，把童话搬上木桌。"
var notice_time := 0.0
var logs: Array[String] = []
var effects: Array[Dictionary] = []
var pop_times: Dictionary = {}
var result_recorded := false
var previous_quit := true
var previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var match_seed := 0

func _ready() -> void:
	view = View.new(); view.game = self; add_child(view)
	call_deferred("_autostart")

func _autostart() -> void:
	if not started and get_tree().current_scene == self: start({})

func start(host_context: Dictionary = {}) -> void:
	if started: return
	started = true; running = true; context = host_context.duplicate()
	previous_quit = get_tree().auto_accept_quit; get_tree().auto_accept_quit = false
	previous_mouse_mode = Input.mouse_mode; Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	profile = store.load_profile(context); selected_deck = profile.selected_deck
	phase = "select"; modal = ""; paused = false
	var audio_path := "res://modules/woodland_duel/audio/audio_director.gd"
	if ResourceLoader.exists(audio_path):
		audio = load(audio_path).new(); add_child(audio)
		audio.set_volume(profile.volume); audio.set_music_enabled(profile.music_enabled); audio.start()
	view.queue_redraw()

func choose_deck(id: String) -> void:
	if not running or phase != "select" or not modal.is_empty(): return
	if id not in ["forest", "toys", "spores"]: return
	selected_deck = id; profile.selected_deck = id; detail_card = ""; sound("select"); save_profile()

func begin_match() -> void:
	if not running or not modal.is_empty(): return
	var deck_ids := ["forest", "toys", "spores"]
	opponent_deck = deck_ids[(deck_ids.find(selected_deck) + 1 + randi_range(0, 1)) % 3]
	match_seed = int(Time.get_ticks_usec() % 2147483646)
	game_state = Rules.new_match(selected_deck, opponent_deck, match_seed)
	phase = "match"; paused = false; result_recorded = false; modal = ""
	selected_hand = -1; selected_attacker = -1; detail_card = ""
	logs.clear(); effects.clear(); pop_times.clear(); ai_delay = 1.0
	_message("你的回合：打出伙伴，下一回合即可攻击。" if game_state.current_player == 0 else "对手先行。观察费用与守护标记。", 5)
	logs.append("林间牌局开始 · 双方 20 生命")
	sound("turn")

func retry_match() -> void:
	if not running: return
	modal = ""; begin_match()

func return_to_selection() -> void:
	if not running: return
	phase = "select"; modal = ""; paused = false; game_state.clear(); effects.clear(); pop_times.clear()
	_clear_selection(); ai_delay = 0; detail_card = ""; notice = "换一副牌，听见另一段森林故事。"
	if is_instance_valid(audio): audio.resume()

func _process(delta: float) -> void:
	if not running: return
	elapsed += delta
	if not paused:
		notice_time = maxf(0, notice_time - delta)
		for fx in effects: fx.life -= delta
		effects = effects.filter(func(fx): return fx.life > 0)
		for uid in pop_times.keys():
			pop_times[uid] -= delta
			if pop_times[uid] <= 0: pop_times.erase(uid)
		if phase == "match" and int(game_state.get("winner", -2)) == -2 and int(game_state.get("current_player", 0)) == 1:
			ai_delay -= delta
			if ai_delay <= 0:
				var action: Dictionary = AI.choose_action(game_state)
				_apply_action(action); ai_delay = 0.8 if action.get("type") != "end_turn" else 1.15
	view.queue_redraw()

func player_can_act() -> bool:
	return running and phase == "match" and not paused and modal.is_empty() and not game_state.is_empty() and game_state.current_player == 0 and game_state.winner == -2

func select_hand(index: int) -> void:
	if not player_can_act(): return
	var hand: Array = game_state.players[0].hand
	if index < 0 or index >= hand.size(): return
	selected_hand = index; selected_attacker = -1; detail_card = hand[index]; sound("select")
	var card: Dictionary = Cards.card(hand[index])
	if int(card.cost) > int(game_state.players[0].mana): _message("费用不足：这张牌需要 %d 颗露珠。" % card.cost)
	elif card.type == "minion" and game_state.players[0].board.size() >= 4: _message("伙伴席位已满，最多上场 4 位。")
	elif _requires_target(card): _message("点选发光目标；再次点卡牌或右键可取消。")
	else: _message("点击「打出卡牌」，或点一下你的伙伴席位。")

func _requires_target(card: Dictionary) -> bool:
	return card.target != "none" and (card.type == "spell" or not Rules.valid_targets(game_state, selected_hand).is_empty())

func play_selected() -> void:
	if not player_can_act() or selected_hand < 0: return
	var card: Dictionary = Cards.card(game_state.players[0].hand[selected_hand])
	if _requires_target(card):
		_message("这张牌需要目标，请点选发光的角色。"); return
	_apply_action({"type":"play", "hand_index":selected_hand})

func select_attacker(uid: int) -> void:
	if not player_can_act(): return
	var unit := find_unit(0, uid)
	if unit.is_empty(): return
	detail_card = unit.card_id
	if selected_hand >= 0:
		var chosen_card: Dictionary = Cards.card(game_state.players[0].hand[selected_hand])
		if chosen_card.target != "none":
			choose_target({"player":0,"uid":uid}); return
	if not unit.ready:
		_message("这位伙伴正在休息：新上场或本回合已攻击。下回合恢复。", 4); sound("error"); return
	selected_attacker = uid; selected_hand = -1; sound("select")
	_message("点选发光的敌人。带「守护」的伙伴必须优先攻击。")

func target_options() -> Array:
	if not player_can_act(): return []
	var result: Array = []
	if selected_hand >= 0:
		for action in Rules.legal_actions(game_state):
			if action.type == "play" and action.hand_index == selected_hand and action.has("target"): result.append(action.target)
		return result
	if selected_attacker >= 0:
		for action in Rules.legal_actions(game_state):
			if action.type == "attack" and action.attacker_uid == selected_attacker: result.append(action.target)
	return result

func choose_target(target: Dictionary) -> void:
	if not player_can_act(): return
	if target not in target_options():
		_message("不能选择这里。先处理守护伙伴，或选择符合卡牌说明的目标。"); sound("error"); return
	if selected_hand >= 0: _apply_action({"type":"play", "hand_index":selected_hand, "target":target})
	elif selected_attacker >= 0: _apply_action({"type":"attack", "attacker_uid":selected_attacker, "target":target})

func end_turn() -> void:
	if player_can_act(): _apply_action({"type":"end_turn"})

func _apply_action(action: Dictionary) -> void:
	if not running or paused or phase != "match": return
	var before := game_state.duplicate(true)
	var result: Dictionary = Rules.apply_action(game_state, action)
	if not result.get("ok", false):
		_message(str(result.get("error", "这个操作暂时不可用"))); sound("error"); return
	_animate_change(before, action)
	var drew_card := false
	for event in result.get("events", []):
		if event.type == "draw": drew_card = true
		elif event.type in ["fatigue", "burn"]:
			_append_log(event.text); _message(event.text, 4.5)
	if drew_card: sound("draw")
	view.hover_hand = -1; view.hover_card = ""
	_clear_selection()
	if game_state.winner != -2: _finish_match()
	elif action.get("type") == "end_turn":
		sound("turn"); ai_delay = 1.1
		_message("你的回合 · 露珠已补满，休息的伙伴醒来了。" if game_state.current_player == 0 else "对手正在思考…", 3)

func _animate_change(before: Dictionary, action: Dictionary) -> void:
	var actor: int = before.current_player
	if action.type == "play":
		var card: Dictionary = Cards.card(before.players[actor].hand[action.hand_index])
		_append_log(("你" if actor == 0 else "对手") + " · " + card.name); sound("play")
	elif action.type == "attack":
		var source: Vector2 = view.target_position({"player":actor,"uid":action.attacker_uid}, before)
		var dest: Vector2 = view.target_position(action.target, before)
		effects.append({"kind":"attack","from":source,"to":dest,"life":0.5,"duration":0.5}); sound("attack")
	elif action.type == "end_turn": _append_log("第 %d 轮 · %s" % [int((game_state.turn + 1) / 2), "你的回合" if game_state.current_player == 0 else "对手回合"])
	for side in [0,1]:
		var hp_delta: int = int(game_state.players[side].hp) - int(before.players[side].hp)
		if hp_delta != 0: _float_number(view.target_position({"player":side,"uid":0}, before), hp_delta)
		for old_unit in before.players[side].board:
			var current := find_unit(side, old_unit.uid)
			if current.is_empty():
				_float_number(view.target_position({"player":side,"uid":old_unit.uid}, before), -int(old_unit.hp)); sound("death")
			elif current.hp != old_unit.hp: _float_number(view.target_position({"player":side,"uid":old_unit.uid}, before), int(current.hp) - int(old_unit.hp))
		for unit in game_state.players[side].board:
			var existed := false
			for old_unit in before.players[side].board:
				if unit.uid == old_unit.uid: existed = true
			if not existed:
				pop_times[unit.uid] = 0.75
				if unit.guard: sound("guard")

func _float_number(at: Vector2, value: int) -> void:
	effects.append({"kind":"number","pos":at,"value":value,"life":1.15,"duration":1.15})
	if value < 0: sound("damage")

func _finish_match() -> void:
	phase = "result"; ai_delay = 0; _clear_selection()
	if result_recorded: return
	result_recorded = true
	profile.matches += 1
	if game_state.winner == 0: profile.wins += 1; sound("win")
	elif game_state.winner == 1: profile.losses += 1; sound("loss")
	else: profile.draws += 1; sound("turn")
	save_profile()

func _append_log(line: String) -> void:
	logs.append(line)
	while logs.size() > 5: logs.pop_front()

func find_unit(side: int, uid: int) -> Dictionary:
	if game_state.is_empty(): return {}
	for unit in game_state.players[side].board:
		if int(unit.uid) == uid: return unit
	return {}

func _clear_selection() -> void:
	selected_hand = -1; selected_attacker = -1

func cancel_selection() -> void:
	_clear_selection(); _message("已取消选择。")

func _message(text: String, duration: float = 3.5) -> void:
	notice = text; notice_time = duration

func sound(kind: String) -> void:
	sound_requested.emit(kind)
	if is_instance_valid(audio): audio.cue(kind)

func set_paused(value: bool) -> void:
	if not running or exiting: return
	paused = value; _clear_selection(); modal = "pause" if value else ""
	if is_instance_valid(audio): audio.set_paused(value)
	if value: save_profile()

func change_volume(value: float) -> void:
	profile.volume = clampf(value, 0, 1)
	if is_instance_valid(audio): audio.set_volume(profile.volume)
	save_profile()

func toggle_music() -> void:
	profile.music_enabled = not profile.music_enabled
	if is_instance_valid(audio): audio.set_music_enabled(profile.music_enabled)
	save_profile()

func toggle_motion() -> void:
	profile.reduce_motion = not profile.reduce_motion; save_profile()

func save_profile() -> bool:
	if profile.is_empty(): return false
	return store.save(profile)

func request_exit(force: bool = false) -> void:
	if not running or exiting: return
	exit_intent = "home"; paused = true; modal = "exit"; _clear_selection()
	if is_instance_valid(audio): audio.pause()
	if force: confirm_exit()

func cancel_exit() -> void:
	if not running or exiting: return
	exit_intent = "home"; set_paused(false)

func confirm_exit() -> void:
	if not running or exiting: return
	exiting = true; running = false; ai_delay = 0; effects.clear(); _clear_selection(); save_profile()
	var tree := get_tree(); var viewport := get_viewport()
	if is_instance_valid(viewport): viewport.set_input_as_handled()
	set_process(false); set_process_unhandled_input(false)
	if is_instance_valid(audio): await audio.shutdown()
	if not is_inside_tree(): return
	Input.mouse_mode = previous_mouse_mode; tree.auto_accept_quit = previous_quit
	view.hide()
	if exit_intent == "window" and context.get("quit_handler") is Callable and context.quit_handler.is_valid():
		context.quit_handler.call(); return
	if tree.current_scene == self: tree.quit()
	else: exit_requested.emit()

func _exit_tree() -> void:
	running = false; ai_delay = 0
	if started:
		Input.mouse_mode = previous_mouse_mode
		if is_instance_valid(get_tree()): get_tree().auto_accept_quit = previous_quit

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and running:
		if context.get("quit_handler") is Callable and context.quit_handler.is_valid():
			if exiting: return
			exiting = true; running = false; ai_delay = 0; save_profile()
			if is_instance_valid(audio): audio.shutdown()
			context.quit_handler.call()
		else: request_exit(); exit_intent = "window"
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and running and phase == "match" and modal.is_empty(): set_paused(true)

func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if modal == "exit": cancel_exit()
			elif modal == "rules": modal = ""; paused = false
			else: set_paused(not paused)
		elif event.keycode == KEY_SPACE and player_can_act():
			get_viewport().set_input_as_handled(); end_turn()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_8 and player_can_act():
			get_viewport().set_input_as_handled(); select_hand(event.keycode - KEY_1)
		elif event.keycode == KEY_ENTER and selected_hand >= 0:
			get_viewport().set_input_as_handled(); play_selected()
	if paused: get_viewport().set_input_as_handled()
