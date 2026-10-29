extends Control
## Original immediate-mode paper theatre. All hit regions use the same design coordinates.
const Cards = preload("../cards.gd")
const INK := Color("283d35")
const PAPER := Color("f8efd9")
const CREAM := Color("fff8e7")
const MOSS := Color("597b60")
const GOLD := Color("dbab5c")
const RED := Color("bd6052")
var game
var font: Font
var images: Dictionary = {}
var card_back: Texture2D
var hits: Array[Dictionary] = []
var pointer := Vector2(-100, -100)
var hover_hand := -1
var hover_card := ""
var keyboard_index := -1
var keyboard_mode := false
var wood_lines: Array[PackedVector2Array] = []
var clock_time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP; focus_mode = Control.FOCUS_ALL; size = Vector2(1280, 800)
	font = load("res://modules/woodland_duel/ui/woodland-font.otf") if ResourceLoader.exists("res://modules/woodland_duel/ui/woodland-font.otf") else ThemeDB.fallback_font
	var rng := RandomNumberGenerator.new(); rng.seed = 18043
	for i in range(42):
		var points := PackedVector2Array()
		var y := rng.randf_range(8, 795)
		for x in range(-20, 1320, 22): points.append(Vector2(x, y + sin(x * 0.005 + i) * rng.randf_range(2, 8)))
		wood_lines.append(points)
	card_back = load("res://modules/woodland_duel/art/card_back.svg")
	grab_focus()

func _process(delta: float) -> void:
	clock_time += delta
	var viewport_size := get_viewport_rect().size
	var factor := minf(viewport_size.x / 1280, viewport_size.y / 800)
	scale = Vector2.ONE * factor; position = (viewport_size - Vector2(1280, 800) * factor) * 0.5
	queue_redraw()

func _draw() -> void:
	hits.clear()
	if game == null: return
	_background()
	if not game.started: return
	if game.phase == "select": _selection()
	else: _match_table()
	if not game.store.status.is_empty():
		_panel(Rect2(18, 752, 1244, 32), Color("632e2ee8"), 8)
		_text(game.store.status, Vector2(32, 774), 16, CREAM)
	if game.phase == "result" and game.modal.is_empty(): _result()
	if not game.modal.is_empty(): _modal()
	if keyboard_mode and keyboard_index >= 0 and keyboard_index < hits.size():
		var rect: Rect2 = hits[keyboard_index].rect
		_border(rect.grow(5), Color("f9dd8b"), 3, 14)

func _background() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("705343"))
	for i in range(8):
		draw_rect(Rect2(0, i * 111, 1280, 108), Color("94715a") if i % 2 == 0 else Color("98765d"))
		draw_line(Vector2(0, i * 111 + 109), Vector2(1280, i * 111 + 109), Color("543f354d"), 3)
	for line in wood_lines: draw_polyline(line, Color("5d44331b"), 1.2, true)
	# Leaves are stacked cut-paper scenery, kept clear of the playable table.
	for corner in [Vector2(14, 26), Vector2(1275, 30), Vector2(1270, 778), Vector2(4, 792)]:
		var inward := Vector2(1 if corner.x < 640 else -1, 1 if corner.y < 400 else -1)
		for i in range(6):
			var center: Vector2 = corner + Vector2((i % 3) * 27, (i / 3) * 36) * inward
			_leaf(center + Vector2(3, 5), 28 + (i % 2) * 8, i * 0.7, Color("302e2928"))
			_leaf(center, 28 + (i % 2) * 8, i * 0.7, Color("637962") if i % 2 == 0 else Color("81906b"))
	# Fine paper flecks add warm material, not a photographic overlay.
	for i in range(48):
		var point := Vector2(53 + (i * 173) % 1190, 24 + (i * 97) % 748)
		draw_circle(point, 1, Color("f2dab329"))

func _selection() -> void:
	_text("林 间 牌 局", Vector2(90, 91), 48, CREAM)
	_text("WOODLAND DUEL  /  一桌童话，三种奇遇", Vector2(92, 126), 17, Color("f2d6ad"))
	_button(Rect2(1030, 41, 164, 44), "设置  /  Esc", "pause", {}, false, Color("624e41"), CREAM)
	_button(Rect2(1030, 98, 164, 40), "回到海岛", "exit", {}, false, Color("624e41"), CREAM)
	_text("挑一副旅伴", Vector2(90, 188), 22, CREAM)
	_text("20 张预组牌  ·  无需收集  ·  轻量回合对战", Vector2(268, 188), 16, Color("f0d6b3"))
	var decks: Array = Cards.decks()
	for i in range(decks.size()):
		var deck: Dictionary = decks[i]
		var box := Rect2(100 + i * 366, 222, 348, 382)
		var selected: bool = game.selected_deck == deck.id
		var color := _faction_color(deck.id)
		_paper(box, PAPER, 27)
		_panel(Rect2(box.position + Vector2(12, 12), Vector2(324, 210)), color.lightened(0.48), 21)
		# Three die-cut silhouettes emerging above a curved paper stage.
		var card_ids: Array = Cards.deck_cards(deck.id)
		var unique: Array = []
		for id in card_ids:
			if id not in unique and Cards.card(id).type == "minion": unique.append(id)
		if not unique.is_empty():
			_art(unique[mini(1, unique.size()-1)], Rect2(box.position + Vector2(4, 36), Vector2(143, 153)), 0.88)
			_art(unique[mini(2, unique.size()-1)], Rect2(box.position + Vector2(205, 36), Vector2(143, 153)), 0.88)
			_art(unique[0], Rect2(box.position + Vector2(74, -3), Vector2(204, 210)))
		_oval(box.position + Vector2(174, 210), Vector2(124, 15), color.darkened(0.2) * Color(1,1,1,0.19))
		_panel(Rect2(box.position + Vector2(19, 194), Vector2(310, 36)), color, 16)
		_text(deck.subtitle, box.position + Vector2(19, 218), 15, CREAM, 310, HORIZONTAL_ALIGNMENT_CENTER)
		_text(deck.name, box.position + Vector2(25, 275), 29, INK)
		_wrap(deck.description, Rect2(box.position + Vector2(25, 296), Vector2(295, 60)), 17, Color("657164"), 25)
		if selected:
			_border(box.grow(5), Color("f2cf86"), 4, 30)
			_badge("已选", box.position + Vector2(300, 34), MOSS, 17, 27)
		hits.append({"rect":box,"id":"deck","data":{"id":deck.id}})
	var wins: int = game.profile.get("wins", 0)
	var matches: int = game.profile.get("matches", 0)
	_text("每一场都从同样的起点出发。", Vector2(100, 653), 19, CREAM)
	_text("20 生命  /  4 个伙伴席位  /  6 费上限", Vector2(100, 685), 16, Color("f2d6ad"))
	_text("已完成 %d 局 · 获胜 %d 局" % [matches, wins], Vector2(100, 731), 15, Color("e4c8a5"))
	_button(Rect2(854, 641, 326, 66), "带上伙伴，开局  →", "begin", {}, false, MOSS, CREAM, 24)
	_button(Rect2(854, 719, 326, 39), "第一次来？看看玩法", "rules", {}, false, Color("725342"), CREAM, 16)

func _match_table() -> void:
	var state: Dictionary = game.game_state
	if state.is_empty(): return
	_text("林间牌局", Vector2(29, 43), 25, CREAM)
	_text("第 %d 轮" % int((state.turn + 1) / 2), Vector2(30, 69), 16, Color("ecd4b4"))
	_button(Rect2(1094, 24, 153, 40), "暂停  /  Esc", "pause", {}, false, Color("665344"), CREAM, 17)
	# A deep moss-green cut-paper clearing on the wood table.
	_paper(Rect2(267, 190, 774, 365), Color("d9d9b8"), 46)
	_panel(Rect2(278, 199, 752, 342), Color("6c8972"), 41)
	_panel(Rect2(287, 207, 734, 325), Color("78917a"), 36)
	for i in range(14):
		var p := Vector2(308 + i * 51, 365 + sin(i * 2.7) * 5)
		_leaf(p, 6, i, Color("c8d2aa63"))
	_text("对手伙伴", Vector2(292, 228), 13, Color("e2e4c1"))
	_text("你的伙伴", Vector2(292, 522), 13, Color("e2e4c1"))
	for side in [1,0]:
		for i in range(4):
			var p := Vector2(391 + i * 174, 298 if side == 1 else 471)
			_oval(p, Vector2(67, 19), Color("345d4728"))
			_oval(p - Vector2(0, 3), Vector2(64, 16), Color("acc29c25"))
		for i in range(state.players[side].board.size()): _unit(state.players[side].board[i], side, i, state.players[side].board.size())
	# Empty friendly row is still a touch-friendly summon destination.
	hits.append({"rect":Rect2(285, 375, 730, 165),"id":"summon","data":{}})
	# Re-add units after summon area so selected friendly targets always win hit-testing.
	for unit in state.players[0].board:
		var p := target_position({"player":0,"uid":unit.uid})
		hits.append({"rect":Rect2(p - Vector2(70, 109), Vector2(140, 153)),"id":"unit","data":{"player":0,"uid":unit.uid,"card_id":unit.card_id}})
	_hero(1, Vector2(650, 100))
	_hero(0, Vector2(149, 636))
	# Opponent cards stay face down, even when hovering.
	var enemy_hand: Array = state.players[1].hand
	for i in range(enemy_hand.size()):
		var pos := Vector2(798 + i * 24, 88 + absf(i - enemy_hand.size() * 0.5) * 2)
		_panel(Rect2(pos + Vector2(3, 4), Vector2(47, 64)), Color("3e352f40"), 6)
		draw_texture_rect(card_back, Rect2(pos, Vector2(47, 66)), false)
	_text("手牌 %d · 牌库 %d" % [enemy_hand.size(), state.players[1].deck.size()], Vector2(800, 176), 14, Color("f1dabc"))
	_text("对手  /  " + _deck_name(state.players[1].deck_id), Vector2(299, 111), 18, CREAM)
	_mana(Vector2(301, 143), state.players[1].mana, state.players[1].max_mana, 12)
	var thinking: bool = state.current_player == 1 and game.phase == "match"
	if thinking:
		var dots := ".".repeat(1 + int(clock_time * 2) % 3)
		_text("对手正在思考" + dots, Vector2(1059, 116), 17, CREAM)
		for i in range(3):
			draw_circle(Vector2(1107 + i * 24, 148 + sin(clock_time * 4 + i) * 4), 5, Color("e2c891"))
	else: _text("轮到你啦", Vector2(1090, 116), 23, CREAM)
	_mana(Vector2(1066, 215), state.players[0].mana, state.players[0].max_mana, 14)
	_text("可用露珠  %d / %d" % [state.players[0].mana, state.players[0].max_mana], Vector2(1064, 252), 16, CREAM)
	_button(Rect2(1061, 280, 187, 66), "结束回合", "end", {}, not game.player_can_act(), GOLD, INK, 24)
	_text("空格  /  SPACE", Vector2(1061, 371), 13, Color("ebd4b4"), 187, HORIZONTAL_ALIGNMENT_CENTER)
	_text("桌边记事", Vector2(1062, 423), 17, Color("f0dcba"))
	var line_y := 455.0
	for line in game.logs:
		_wrap(line, Rect2(1063, line_y - 16, 180, 38), 13, Color("ead7ba"), 19)
		line_y += 44
	var info: String = hover_card if not hover_card.is_empty() else game.detail_card
	if game.selected_hand >= 0 and game.selected_hand < state.players[0].hand.size(): info = state.players[0].hand[game.selected_hand]
	if not info.is_empty(): _detail(info)
	else: _help_note()
	_hand(state.players[0].hand)
	_text("你的牌库 %d" % state.players[0].deck.size(), Vector2(35, 750), 15, Color("f5debd"))
	if state.players[0].fatigue > 0: _text("疲劳 %d" % state.players[0].fatigue, Vector2(35, 775), 15, Color("ffbc9d"))
	var message: String = game.notice if game.notice_time > 0 else "点手牌查看 · 点伙伴再点目标攻击 · 右键取消 · 1–8 选牌"
	_panel(Rect2(290, 558, 741, 38), Color("4a6556ed"), 16)
	_text(message, Vector2(304, 583), 15, CREAM, 713, HORIZONTAL_ALIGNMENT_CENTER)
	_effects()

func _unit(unit: Dictionary, side: int, index: int, count: int) -> void:
	var p := Vector2(650 - (count - 1) * 87 + index * 174, 301 if side == 1 else 475)
	var card: Dictionary = Cards.card(unit.card_id)
	var valid_target: bool = {"player":side,"uid":unit.uid} in game.target_options()
	var selected: bool = game.selected_attacker == unit.uid
	var sway := 0.0 if game.profile.get("reduce_motion", false) or game.paused else sin(clock_time * 1.7 + unit.uid) * 1.4
	var bounce := 0.0
	if game.pop_times.has(unit.uid) and not game.profile.get("reduce_motion", false): bounce = sin(float(game.pop_times[unit.uid]) * PI / 0.75) * 19
	_oval(p + Vector2(0, 8), Vector2(56, 17), Color("223e4155"))
	_oval(p + Vector2(0, 3), Vector2(56, 16), PAPER)
	if valid_target or selected:
		_oval(p + Vector2(0, 3), Vector2(64, 22), Color("e9cd76"))
		_oval(p + Vector2(0, 3), Vector2(57, 16), PAPER)
	var rect := Rect2(p + Vector2(-72, -135 + sway - bounce), Vector2(144, 144))
	_art(unit.card_id, rect)
	if unit.guard:
		var shield := p + Vector2(56, -72)
		var points := PackedVector2Array([shield + Vector2(-14,-17), shield + Vector2(14,-17), shield + Vector2(13,6), shield + Vector2(0,18), shield + Vector2(-13,6)])
		draw_colored_polygon(points, Color("d8b36c")); draw_polyline(points, Color("fff0c3"), 2, true)
		_text("守", shield + Vector2(-9, 5), 17, INK)
	_badge(str(unit.attack), p + Vector2(-43, 5), Color("dcb259"), 20, 21)
	_badge(str(unit.hp), p + Vector2(43, 5), RED, 20, 21)
	_panel(Rect2(p + Vector2(-59, 27), Vector2(118, 25)), PAPER, 10)
	_text(card.name, p + Vector2(-57, 45), 14, INK, 114, HORIZONTAL_ALIGNMENT_CENTER)
	if side == 0:
		if unit.ready:
			draw_circle(p + Vector2(0, 4), 5, MOSS)
			_text("可攻击", p + Vector2(-30, -5), 12, MOSS, 60, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_text("休息", p + Vector2(-20, -6), 12, Color("93887a"), 40, HORIZONTAL_ALIGNMENT_CENTER)
			_text("z", p + Vector2(40, -114), 20, PAPER)
	hits.append({"rect":Rect2(p - Vector2(70, 134), Vector2(140, 181)),"id":"unit","data":{"player":side,"uid":unit.uid,"card_id":unit.card_id}})

func _hero(side: int, p: Vector2) -> void:
	var player: Dictionary = game.game_state.players[side]
	var target := {"player":side,"uid":0}
	var targeted: bool = target in game.target_options()
	_oval(p + Vector2(2, 60), Vector2(65, 16), Color("342f3145"))
	draw_circle(p + Vector2(4, 7), 59, Color("403b3540"))
	draw_circle(p, 59, GOLD if targeted else Color("c9b887"))
	draw_circle(p, 53, PAPER)
	draw_circle(p, 45, _faction_color(player.deck_id).lightened(0.4))
	var deck: Array = Cards.deck_cards(player.deck_id)
	if not deck.is_empty(): _art(deck[0], Rect2(p - Vector2(48, 56), Vector2(96, 96)))
	_badge(str(maxi(0, player.hp)), p + Vector2(0, 49), RED, 27, 27)
	_text("对手" if side == 1 else "你", p + Vector2(-80, 89), 16, CREAM, 160, HORIZONTAL_ALIGNMENT_CENTER)
	if targeted: _border(Rect2(p - Vector2(61, 61), Vector2(122, 122)), Color("ffdc79"), 3, 61)
	hits.append({"rect":Rect2(p - Vector2(62,62),Vector2(124,142)),"id":"target","data":target})

func _hand(hand: Array) -> void:
	var count := hand.size()
	var spacing := minf(110, 665.0 / maxf(1, count - 1))
	var deferred_index: int = hover_hand if hover_hand >= 0 and hover_hand < count else game.selected_hand
	for i in range(count):
		if i == deferred_index: continue
		_hand_card(hand, i, count, spacing, false)
	if deferred_index >= 0: _hand_card(hand, deferred_index, count, spacing, true)

func _hand_card(hand: Array, index: int, count: int, spacing: float, raised: bool) -> void:
	var midpoint := (count - 1) * 0.5
	var shift := index - midpoint
	var y := 603 + absf(shift) * 3 - (33 if raised else 0)
	var center := Vector2(651 + shift * spacing, y)
	var rotation := shift * 0.035 if not raised else 0.0
	var card: Dictionary = Cards.card(hand[index])
	var can_pay: bool = card.cost <= game.game_state.players[0].mana and game.player_can_act()
	draw_set_transform(center, rotation, Vector2.ONE)
	_paper(Rect2(-67, 0, 134, 181), PAPER if can_pay else Color("dfd7c5"), 13)
	if raised: _border(Rect2(-69, -2, 138, 185), GOLD, 3, 15)
	_panel(Rect2(-58, 11, 116, 102), _faction_color(card.faction).lightened(0.5), 9)
	_art(hand[index], Rect2(-57, 9, 114, 106))
	_badge(str(card.cost), Vector2(-50, 18), Color("608ca1"), 20, 20)
	_text(card.name, Vector2(-60, 134), 17, INK, 120, HORIZONTAL_ALIGNMENT_CENTER)
	if card.type == "minion":
		_badge(str(card.attack), Vector2(-43, 159), GOLD, 17, 15)
		_badge(str(card.hp), Vector2(43, 159), RED, 17, 15)
		_text("守护" if card.guard else "伙伴", Vector2(-23, 165), 13, MOSS, 46, HORIZONTAL_ALIGNMENT_CENTER)
	else: _text("法术", Vector2(-36, 163), 15, MOSS, 72, HORIZONTAL_ALIGNMENT_CENTER)
	_text(str(index+1), Vector2(47, 18), 11, Color("637066"))
	draw_set_transform(Vector2.ZERO)
	hits.append({"rect":Rect2(center - Vector2(67, 0),Vector2(134,181)),"id":"hand","data":{"index":index,"card_id":hand[index]}})

func _detail(id: String) -> void:
	var card: Dictionary = Cards.card(id)
	if card.is_empty(): return
	_paper(Rect2(23, 125, 221, 398), PAPER, 18)
	_panel(Rect2(34, 137, 199, 144), _faction_color(card.faction).lightened(0.5), 13)
	_art(id, Rect2(63, 127, 155, 156))
	_badge(str(card.cost), Vector2(51, 153), Color("608ca1"), 21, 22)
	_text(card.name, Vector2(39, 313), 24, INK)
	_text("伙伴 · %d 攻击 / %d 生命" % [card.attack, card.hp] if card.type == "minion" else "法术 · 使用后生效", Vector2(39, 340), 14, MOSS)
	_wrap(card.text if not card.text.is_empty() else "纯粹可靠的林间伙伴。", Rect2(39, 357, 190, 85), 17, INK, 27)
	if card.type == "minion":
		_wrap("新伙伴需休息一回合。" + ("守护：阻挡敌方随从攻击其他目标。" if card.guard else "每回合可攻击一次。"), Rect2(39, 431, 190, 66), 13, Color("7c8373"), 20)
	if game.selected_hand >= 0 and game.player_can_act():
		var label := "打出卡牌"
		var disabled := false
		var fill := MOSS
		if int(card.cost) > int(game.game_state.players[0].mana): label = "露珠不足"; disabled = true
		elif card.type == "minion" and game.game_state.players[0].board.size() >= 4: label = "伙伴席位已满"; disabled = true
		elif card.target != "none" and card.type == "spell" and game.target_options().is_empty(): label = "没有可选目标"; disabled = true
		else:
			var legal := false
			for action in game.Rules.legal_actions(game.game_state):
				if action.type == "play" and action.hand_index == game.selected_hand: legal = true
			if not legal: label = "暂时不能打出"; disabled = true
			elif game._requires_target(card): label = "请点选发光目标"; disabled = true
		if disabled: fill = Color("9b9f87")
		_button(Rect2(37, 477, 193, 35), label, "play", {}, disabled, fill, CREAM, 16)

func _help_note() -> void:
	_paper(Rect2(24, 135, 218, 367), Color("efe5c9"), 15)
	_leaf(Vector2(130, 180), 26, -0.3, MOSS)
	_text("桌边小抄", Vector2(50, 234), 24, INK)
	_wrap("① 点手牌，查看说明与费用。\n② 点「打出卡牌」召唤伙伴。\n③ 点醒着的伙伴，再点敌人。\n④ 用完露珠，结束回合。", Rect2(42, 257, 183, 174), 16, Color("607060"), 28)
	_text("先打守护，再打英雄。", Vector2(43, 460), 15, MOSS)
	_button(Rect2(41, 469, 184, 29), "完整玩法", "rules", {}, false, Color("d3d1ae"), INK, 14)

func _effects() -> void:
	for fx in game.effects:
		var progress := 1 - float(fx.life) / float(fx.duration)
		if fx.kind == "attack":
			var start: Vector2 = fx.from; var finish: Vector2 = fx.to
			var head := start.lerp(finish, minf(1, progress * 2))
			if not game.profile.get("reduce_motion", false):
				draw_line(start, head, Color(1, 0.84, 0.5, 1 - progress), 5, true)
				draw_circle(head, 10 * (1 - progress) + 3, CREAM)
		else:
			var at: Vector2 = fx.pos - Vector2(0, 45 + (0 if game.profile.get("reduce_motion", false) else progress * 45))
			var color := Color("bd4c43") if fx.value < 0 else Color("dff1b5")
			color.a = minf(1, float(fx.life) * 3)
			var label: String = str(fx.value) if fx.value < 0 else "+" + str(fx.value)
			draw_string_outline(font, at - Vector2(30,0), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 38, 6, Color("fff1d6"))
			_text(label, at - Vector2(30,0), 38, color, 60, HORIZONTAL_ALIGNMENT_CENTER)

func _result() -> void:
	hits.clear(); draw_rect(Rect2(0,0,1280,800),Color("1e2d2cc9"))
	_paper(Rect2(391, 163, 498, 470), PAPER, 31)
	var winner: int = game.game_state.winner
	var title := "森林为你鼓掌" if winner == 0 else ("这一局，留给风" if winner == 1 else "不分胜负的午后")
	_leaf(Vector2(640, 221), 33, -0.3, MOSS if winner == 0 else GOLD)
	_text(title, Vector2(418, 302), 35, INK, 444, HORIZONTAL_ALIGNMENT_CENTER)
	_text("获胜" if winner == 0 else ("惜败" if winner == 1 else "平局"), Vector2(418, 342), 22, MOSS, 444, HORIZONTAL_ALIGNMENT_CENTER)
	_text("第 %d 轮 · 你的生命 %d · 对手生命 %d" % [int((game.game_state.turn+1)/2), maxi(0,game.game_state.players[0].hp),maxi(0,game.game_state.players[1].hp)], Vector2(421, 386), 17, Color("6b7766"), 438, HORIZONTAL_ALIGNMENT_CENTER)
	_text("没有奖励负担，每一局都是新的故事。", Vector2(420, 417), 16, Color("7e8675"), 440, HORIZONTAL_ALIGNMENT_CENTER)
	_button(Rect2(428, 450, 424, 54), "再来一局", "retry", {}, false, MOSS, CREAM, 22)
	_button(Rect2(428, 517, 203, 47), "换副牌", "selection", {}, false, Color("ded5b7"), INK, 19)
	_button(Rect2(649, 517, 203, 47), "回到海岛", "exit", {}, false, Color("ded5b7"), INK, 19)

func _modal() -> void:
	hits.clear(); draw_rect(Rect2(0,0,1280,800), Color("1e2d2cc9"))
	if game.modal == "rules":
		_paper(Rect2(307, 95, 666, 622), PAPER, 26)
		_text("一张木桌，一点小策略", Vector2(349, 158), 31, INK)
		_wrap("目标：把对手英雄的 20 点生命降到 0。\n\n每回合获得一颗露珠，上限 6 颗；回合开始补满并抽一张牌。后手额外得到一张临时补费牌。\n\n点手牌看详情，再点「打出卡牌」。法术需要目标时，点选发光的角色。场上最多 4 位伙伴，手牌上限 8 张。\n\n新伙伴休息一回合；之后每回合攻击一次。攻击时双方同时受伤。「守护」会挡住随从，但挡不住法术。\n\n牌库抽空后，每次抽牌受到递增疲劳伤害。第 60 个半回合结束时，生命较高的一方获胜，相同则平局。", Rect2(350, 185, 580, 410), 18, INK, 28)
		_text("键鼠：1–8 选牌 · Enter 打出 · 空格结束回合 · Esc 暂停", Vector2(350, 626), 15, MOSS)
		_button(Rect2(350, 650, 580, 43), "知道了，回到牌桌", "close_rules", {}, false, MOSS, CREAM, 20)
	elif game.modal == "exit":
		_paper(Rect2(394, 245, 492, 299), PAPER, 26)
		_text("要收起这一桌童话吗？", Vector2(431, 308), 29, INK)
		_wrap("本局不会保存，已完成的战绩与设置会保留。" if game.phase == "match" else "战绩与设置会保留，下次再来一起玩。", Rect2(431, 336, 417, 66), 18, Color("687665"), 28)
		_button(Rect2(431, 437, 199, 56), "继续留在这里", "cancel_exit", {}, false, MOSS, CREAM, 19)
		_button(Rect2(649, 437, 199, 56), "确认离开", "confirm_exit", {}, false, Color("ddd1b1"), INK, 19)
	else:
		_paper(Rect2(406, 135, 468, 530), PAPER, 27)
		_text("在树荫下歇一会儿", Vector2(443, 196), 29, INK)
		_text("对局已暂停，对手也会等你。", Vector2(444, 231), 17, Color("6e7b69"))
		_text("音量", Vector2(445, 292), 19, INK)
		_text("%d%%" % int(game.profile.volume * 100), Vector2(777, 292), 18, MOSS)
		_panel(Rect2(449, 314, 380, 10), Color("d5cfb3"), 5)
		_panel(Rect2(449, 314, 380 * float(game.profile.volume), 10), MOSS, 5)
		draw_circle(Vector2(449 + 380 * float(game.profile.volume), 319), 13, MOSS)
		draw_circle(Vector2(449 + 380 * float(game.profile.volume), 319), 6, CREAM)
		hits.append({"rect":Rect2(436, 300, 406, 38),"id":"volume","data":{}})
		_button(Rect2(444, 351, 390, 44), "背景音乐：" + ("开" if game.profile.music_enabled else "关"), "music", {}, false, Color("e1d9bc"), INK, 19)
		_button(Rect2(444, 408, 390, 44), "减少动态效果：" + ("开" if game.profile.reduce_motion else "关"), "motion", {}, false, Color("e1d9bc"), INK, 19)
		_button(Rect2(444, 475, 390, 54), "继续", "resume", {}, false, MOSS, CREAM, 23)
		_button(Rect2(444, 545, 187, 44), "玩法", "rules", {}, false, Color("e1d9bc"), INK, 18)
		_button(Rect2(648, 545, 187, 44), "回到海岛", "exit", {}, false, Color("e1d9bc"), INK, 18)
		_text("本游戏没有付费、养成或解锁。", Vector2(444, 628), 14, Color("79806c"))

func target_position(target: Dictionary, state: Dictionary = {}) -> Vector2:
	if state.is_empty(): state = game.game_state
	var side: int = int(target.get("player",0))
	if int(target.get("uid",0)) == 0: return Vector2(149,636) if side == 0 else Vector2(650,100)
	var board: Array = state.players[side].board
	for i in range(board.size()):
		if board[i].uid == target.uid: return Vector2(650 - (board.size()-1)*87 + i*174, 301 if side == 1 else 475)
	return Vector2(650, 301 if side == 1 else 475)

func _gui_input(event: InputEvent) -> void:
	if not game.running: return
	if event is InputEventMouseMotion:
		pointer = event.position; keyboard_mode = false; _update_hover()
	elif event is InputEventMouseButton:
		if event.device == -1: return # Explicit touch handling avoids double activation from emulated mouse.
		pointer = event.position; keyboard_mode = false
		if event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			game.cancel_selection(); accept_event()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_activate_at(pointer); accept_event()
	elif event is InputEventScreenTouch and not event.pressed:
		pointer = event.position; _activate_at(pointer); accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			keyboard_mode = true; keyboard_index = posmod(keyboard_index + (-1 if event.shift_pressed else 1), maxi(1,hits.size())); accept_event()
		elif event.keycode == KEY_ENTER and keyboard_mode and keyboard_index >= 0 and keyboard_index < hits.size():
			_activate(hits[keyboard_index]); accept_event()
		elif event.keycode in [KEY_LEFT, KEY_RIGHT] and keyboard_mode and keyboard_index >= 0 and keyboard_index < hits.size() and hits[keyboard_index].id == "volume":
			game.change_volume(float(game.profile.volume) + (0.05 if event.keycode == KEY_RIGHT else -0.05)); accept_event()

func _update_hover() -> void:
	hover_hand = -1; hover_card = ""
	for i in range(hits.size()-1,-1,-1):
		if hits[i].rect.has_point(pointer):
			if hits[i].id == "hand": hover_hand = hits[i].data.index; hover_card = hits[i].data.card_id
			elif hits[i].id == "unit": hover_card = hits[i].data.card_id
			break

func _activate_at(at: Vector2) -> void:
	for i in range(hits.size()-1,-1,-1):
		if hits[i].rect.has_point(at): _activate(hits[i]); return

func _activate(hit: Dictionary) -> void:
	if hit.id in ["begin", "pause", "resume", "rules", "close_rules", "exit", "cancel_exit", "retry", "selection"]: keyboard_index = -1
	var data: Dictionary = hit.data
	match hit.id:
		"deck": game.choose_deck(data.id)
		"begin": hover_hand = -1; hover_card = ""; game.begin_match()
		"hand":
			if game.selected_hand == data.index: game.cancel_selection()
			else: game.select_hand(data.index)
		"unit":
			game.detail_card = data.card_id
			if {"player":data.player,"uid":data.uid} in game.target_options(): game.choose_target({"player":data.player,"uid":data.uid})
			elif data.player == 0: game.select_attacker(data.uid)
		"target":
			if game.selected_hand >= 0 or game.selected_attacker >= 0: game.choose_target(data)
		"summon":
			if game.selected_hand >= 0: game.play_selected()
		"play": game.play_selected()
		"end": game.end_turn()
		"pause": game.set_paused(true)
		"resume": game.set_paused(false)
		"rules": game.modal = "rules"; game.paused = true
		"close_rules": game.set_paused(false)
		"exit": game.request_exit()
		"cancel_exit": game.cancel_exit()
		"confirm_exit": game.confirm_exit()
		"retry": hover_hand = -1; hover_card = ""; game.retry_match()
		"selection": hover_hand = -1; hover_card = ""; game.return_to_selection()
		"volume": game.change_volume(clampf((pointer.x - 449) / 380, 0, 1))
		"music": game.toggle_music()
		"motion": game.toggle_motion()

func _button(rect: Rect2, label: String, id: String, data: Dictionary = {}, disabled: bool = false, fill: Color = MOSS, ink: Color = CREAM, font_size: int = 20) -> void:
	var hovered := rect.has_point(pointer) and not disabled
	_panel(Rect2(rect.position + Vector2(0,4),rect.size), Color("2d332e35"), 12)
	_panel(rect, fill.lightened(0.09) if hovered else fill, 12)
	if disabled: draw_style_box(_style(Color("b5b6a07a"),12),rect)
	_text(label, rect.position + Vector2(6, rect.size.y*0.5+font_size*0.36), font_size, ink if not disabled else ink.darkened(0.15), rect.size.x-12, HORIZONTAL_ALIGNMENT_CENTER)
	if not disabled: hits.append({"rect":rect,"id":id,"data":data})

func _art(id: String, rect: Rect2, opacity: float = 1.0) -> void:
	var card: Dictionary = Cards.card(id)
	var key: String = card.get("art_key", id)
	if not images.has(key):
		var path := "res://modules/woodland_duel/art/" + key + ".png"
		images[key] = load(path) if ResourceLoader.exists(path) else null
	var texture: Texture2D = images[key]
	if texture != null:
		draw_texture_rect(texture, rect, false, Color(1,1,1,opacity))
	else:
		# Brief import-time fallback; final runtime art is supplied per card.
		var c := _faction_color(card.get("faction", "forest"))
		_leaf(rect.get_center(), rect.size.x * 0.23, -0.3, Color(c,opacity))
		_leaf(rect.get_center() + Vector2(14, 3), rect.size.x * 0.17, 0.5, Color(c.lightened(0.2),opacity))

func _faction_color(id: String) -> Color:
	return Color("627f5b") if id == "forest" else (Color("6c9690") if id == "toys" else (Color("ad756e") if id == "spores" else Color("9b8f6e")))

func _deck_name(id: String) -> String:
	for deck in Cards.decks():
		if deck.id == id: return deck.name
	return id

func _mana(at: Vector2, current: int, maximum: int, radius: float) -> void:
	for i in range(6):
		var p := at + Vector2(i * (radius * 2 + 4),0)
		var color := Color("91c2cb") if i < current else (Color("647b77") if i < maximum else Color("554e433b"))
		var points := PackedVector2Array([p + Vector2(0,-radius),p + Vector2(radius*0.75,0),p + Vector2(0,radius),p + Vector2(-radius*0.75,0)])
		draw_colored_polygon(points,color)
		if i < current: draw_line(p+Vector2(-2,-radius*.5),p+Vector2(-radius*.4,0),Color("e2f3e2"),2,true)
	if current > 6: _text("+%d" % (current-6),at+Vector2(6*(radius*2+4),6),15,CREAM)

func _badge(label: String, center: Vector2, color: Color, font_size: int, radius: float) -> void:
	draw_circle(center + Vector2(1,3), radius, Color("3b3a3540")); draw_circle(center,radius,color)
	draw_arc(center,radius-2,0,TAU,28,Color("fff0d238"),1,true)
	_text(label,center+Vector2(-radius, font_size*0.36),font_size,CREAM,radius*2,HORIZONTAL_ALIGNMENT_CENTER)

func _paper(rect: Rect2, color: Color, radius: int = 18) -> void:
	_panel(Rect2(rect.position+Vector2(5,9),rect.size),Color("302e2b35"),radius)
	_panel(Rect2(rect.position+Vector2(1,4),rect.size),color.darkened(.15),radius)
	_panel(rect,color,radius)
	_border(rect.grow(-2),Color("fff9e566"),1,radius)

func _panel(rect: Rect2, color: Color, radius: int = 12) -> void:
	draw_style_box(_style(color,radius),rect)

func _style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color=color
	style.set_corner_radius_all(radius); style.corner_detail=12
	return style

func _border(rect: Rect2, color: Color, width: int = 2, radius: int = 12) -> void:
	var style := _style(Color.TRANSPARENT,radius); style.border_color=color; style.set_border_width_all(width)
	draw_style_box(style,rect)

func _text(text: String, at: Vector2, font_size: int = 20, color: Color = INK, width: float = -1, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(font,at,text,alignment,width,font_size,color)

func _wrap(text: String, rect: Rect2, font_size: int, color: Color, line_height: float) -> void:
	var line := ""; var y := rect.position.y + font_size
	for character in text:
		if character == "\n" or font.get_string_size(line + character,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > rect.size.x:
			_text(line,Vector2(rect.position.x,y),font_size,color); line=""; y+=line_height
			if y > rect.end.y + line_height: return
			if character == "\n": continue
		line += character
	if not line.is_empty(): _text(line,Vector2(rect.position.x,y),font_size,color)

func _leaf(center: Vector2, radius: float, angle: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(21):
		var t := TAU * i / 20.0
		points.append(center + Vector2(cos(t)*radius*.48,sin(t)*radius).rotated(angle))
	draw_colored_polygon(points,color)
	draw_line(center+Vector2(0,-radius*.8).rotated(angle),center+Vector2(0,radius*.8).rotated(angle),color.lightened(.18),1,true)

func _oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(40):
		var angle := TAU*i/40
		points.append(center+Vector2(cos(angle),sin(angle))*radii)
	draw_colored_polygon(points,color)
