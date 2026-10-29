extends RefCounted
## Deterministic, rendering-independent original card rules.
## Public functions are static; apply_action mutates only after complete validation.
const Cards = preload("cards.gd")
const MAX_HP := 20
const MAX_MANA := 6
const MAX_BOARD := 4
const MAX_HAND := 8
const MAX_TURNS := 60
const ONGOING := -2
const DRAW := -1

static func new_match(player_deck: String, ai_deck: String, seed_value: int = 0, first_player: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var chosen: Array[String] = [player_deck, ai_deck]
	var players: Array[Dictionary] = []
	for index in 2:
		if not chosen[index] in Cards.DECK_IDS:
			chosen[index] = "forest"
		var deck: Array[String] = Cards.deck_cards(chosen[index])
		for i in range(deck.size() - 1, 0, -1):
			var swap := rng.randi_range(0, i)
			var old: String = deck[i]
			deck[i] = deck[swap]
			deck[swap] = old
		players.append({"deck_id": chosen[index], "hp": MAX_HP, "mana": 0, "max_mana": 0, "deck": deck, "hand": [], "board": [], "discard": [], "fatigue": 0, "turns_started": 0})
	var first := first_player if first_player in [0, 1] else rng.randi_range(0, 1)
	var state: Dictionary = {"players": players, "current_player": first, "first_player": first, "turn": 1, "winner": ONGOING, "finish_reason": "", "last_events": [], "next_uid": 1, "seed": seed_value, "actions_taken": 0}
	for index in 2:
		for ignored in (3 if index == first else 4):
			_draw(state, index)
	players[1 - first].hand.append("sunlight")
	state.last_events.clear()
	_start_turn(state, true)
	_event(state, "start", "林间牌局开始。%s先手。" % _who(first), first)
	return state

static func valid_targets(state: Dictionary, hand_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.winner != ONGOING:
		return result
	var owner: int = state.current_player
	var hand: Array = state.players[owner].hand
	if hand_index < 0 or hand_index >= hand.size():
		return result
	var definition: Dictionary = Cards.card(hand[hand_index])
	var mode: String = definition.get("target", "none")
	if mode == "none":
		return result
	var target_player: int = owner if mode.begins_with("friendly") else 1 - owner
	if mode.ends_with("character"):
		result.append({"player": target_player, "uid": 0})
	for unit: Dictionary in state.players[target_player].board:
		if unit.hp > 0:
			result.append({"player": target_player, "uid": unit.uid})
	return result

static func attack_targets(state: Dictionary, attacker_uid: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.winner != ONGOING:
		return result
	var owner: int = state.current_player
	var attacker: Dictionary = find_unit(state, owner, attacker_uid)
	if attacker.is_empty() or not attacker.ready or attacker.attack <= 0 or attacker.hp <= 0:
		return result
	var opponent: int = 1 - owner
	var guards: Array[Dictionary] = []
	for unit: Dictionary in state.players[opponent].board:
		if unit.guard and unit.hp > 0:
			guards.append({"player": opponent, "uid": unit.uid})
	if not guards.is_empty():
		return guards
	result.append({"player": opponent, "uid": 0})
	for unit: Dictionary in state.players[opponent].board:
		if unit.hp > 0:
			result.append({"player": opponent, "uid": unit.uid})
	return result

static func legal_actions(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if state.winner != ONGOING:
		return result
	var owner: int = state.current_player
	for i in state.players[owner].hand.size():
		if not _play_error(state, i).is_empty():
			continue
		var definition: Dictionary = Cards.card(state.players[owner].hand[i])
		var targets: Array[Dictionary] = valid_targets(state, i)
		if definition.target == "none" or (definition.type == "minion" and targets.is_empty()):
			result.append({"type": "play", "hand_index": i})
		else:
			for target: Dictionary in targets:
				result.append({"type": "play", "hand_index": i, "target": target})
	for unit: Dictionary in state.players[owner].board:
		for target: Dictionary in attack_targets(state, unit.uid):
			result.append({"type": "attack", "attacker_uid": unit.uid, "target": target})
	result.append({"type": "end_turn"})
	return result

static func apply_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var error := action_error(state, action)
	if not error.is_empty():
		return {"ok": false, "error": error, "events": []}
	state.last_events = []
	state.actions_taken += 1
	var owner: int = state.current_player
	match action.type:
		"play":
			_play(state, int(action.hand_index), action.get("target", {}))
		"attack":
			_attack(state, int(action.attacker_uid), action.target)
		"end_turn":
			_event(state, "end_turn", "%s结束回合。" % _who(owner), owner)
			if state.turn >= MAX_TURNS:
				_finish_by_health(state)
			else:
				state.turn += 1
				state.current_player = 1 - owner
				_start_turn(state, true)
	_resolve_deaths(state)
	_check_winner(state)
	return {"ok": true, "error": "", "events": state.last_events.duplicate(true)}

static func action_error(state: Dictionary, action: Dictionary) -> String:
	if state.winner != ONGOING:
		return "本局已经结束。"
	if not action.get("type") is String:
		return "无效操作。"
	match action.type:
		"end_turn":
			return ""
		"play":
			if not action.get("hand_index") is int:
				return "请选择一张手牌。"
			var issue := _play_error(state, action.hand_index)
			if not issue.is_empty():
				return issue
			var definition: Dictionary = Cards.card(state.players[state.current_player].hand[action.hand_index])
			var targets: Array[Dictionary] = valid_targets(state, action.hand_index)
			if definition.target == "none" or (definition.type == "minion" and targets.is_empty()):
				if action.has("target") and not (action.target is Dictionary and action.target.is_empty()):
					return "这张牌无需选择目标。"
				return ""
			if not _contains_target(targets, action.get("target")):
				return "请选择有效目标。"
			return ""
		"attack":
			if not action.get("attacker_uid") is int:
				return "请选择一名可攻击的随从。"
			if not _contains_target(attack_targets(state, action.attacker_uid), action.get("target")):
				return "无法攻击这个目标：请留意守护与随从的等待状态。"
			return ""
	return "未知操作。"

static func find_unit(state: Dictionary, player: int, uid: int) -> Dictionary:
	if player not in [0, 1] or uid == 0:
		return {}
	for unit: Dictionary in state.players[player].board:
		if unit.uid == uid:
			return unit
	return {}

static func _contains_target(targets: Array[Dictionary], value: Variant) -> bool:
	if not value is Dictionary or not value.get("player") is int or not value.get("uid") is int:
		return false
	for target: Dictionary in targets:
		if target.player == value.player and target.uid == value.uid:
			return true
	return false

static func _play_error(state: Dictionary, hand_index: int) -> String:
	var player: Dictionary = state.players[state.current_player]
	if hand_index < 0 or hand_index >= player.hand.size():
		return "这张手牌已不在手中。"
	var definition: Dictionary = Cards.card(player.hand[hand_index])
	if definition.is_empty():
		return "未知卡牌。"
	if definition.cost > player.mana:
		return "费用不足。"
	if definition.type == "minion" and player.board.size() >= MAX_BOARD:
		return "场上最多容纳 4 名随从。"
	if definition.type == "spell":
		if definition.target != "none" and valid_targets(state, hand_index).is_empty():
			return "没有有效目标。"
		# Pure board effects cannot consume a card when they cannot affect anything.
		if definition.effects.size() == 1:
			match definition.effects[0].kind:
				"summon":
					if player.board.size() >= MAX_BOARD:
						return "没有可用的召唤空位。"
				"buff_all":
					if player.board.is_empty():
						return "场上还没有友方随从。"
				"damage_enemy_minions":
					if state.players[1 - int(state.current_player)].board.is_empty():
						return "场上还没有敌方随从。"
	return ""

static func _play(state: Dictionary, hand_index: int, target: Dictionary) -> void:
	var owner: int = state.current_player
	var player: Dictionary = state.players[owner]
	var card_id: String = player.hand[hand_index]
	var definition: Dictionary = Cards.card(card_id)
	player.hand.remove_at(hand_index)
	player.mana -= definition.cost
	_event(state, "play", "%s打出「%s」。" % [_who(owner), definition.name], owner, {"card_id": card_id, "target": target.duplicate()})
	if definition.type == "minion":
		var unit: Dictionary = _summon(state, owner, card_id)
		_run_effects(state, definition.battlecry, owner, target, unit.get("uid", 0))
	else:
		player.discard.append(card_id)
		_run_effects(state, definition.effects, owner, target, 0)

static func _attack(state: Dictionary, attacker_uid: int, target: Dictionary) -> void:
	var owner: int = state.current_player
	var attacker: Dictionary = find_unit(state, owner, attacker_uid)
	attacker.ready = false
	_event(state, "attack", "「%s」发起攻击。" % Cards.card(attacker.card_id).name, owner, {"uid": attacker_uid, "target": target.duplicate()})
	var retaliation := 0
	if target.uid != 0:
		retaliation = int(find_unit(state, target.player, target.uid).attack)
	_damage(state, target, attacker.attack)
	if target.uid != 0:
		_damage(state, {"player": owner, "uid": attacker_uid}, retaliation)

static func _start_turn(state: Dictionary, draw_card: bool) -> void:
	var owner: int = state.current_player
	var player: Dictionary = state.players[owner]
	player.turns_started += 1
	player.max_mana = mini(MAX_MANA, int(player.max_mana) + 1)
	player.mana = player.max_mana
	for unit: Dictionary in player.board:
		unit.ready = true
	_event(state, "turn", "%s的回合 · %d 点费用。" % [_who(owner), player.mana], owner)
	if draw_card:
		_draw(state, owner)

static func _draw(state: Dictionary, owner: int) -> void:
	var player: Dictionary = state.players[owner]
	if player.deck.is_empty():
		player.fatigue += 1
		_event(state, "fatigue", "%s的牌库已空，受到 %d 点疲劳伤害。" % [_who(owner), player.fatigue], owner, {"amount": player.fatigue})
		_damage(state, {"player": owner, "uid": 0}, player.fatigue)
		return
	var card_id: String = player.deck.pop_back()
	if player.hand.size() >= MAX_HAND:
		player.discard.append(card_id)
		_event(state, "burn", "%s手牌已满，弃掉「%s」。" % [_who(owner), Cards.card(card_id).name], owner, {"card_id": card_id})
	else:
		player.hand.append(card_id)
		# Opponent draw identity stays private, including in the human-readable log.
		_event(state, "draw", "%s抽了 1 张牌。" % _who(owner), owner)

static func _summon(state: Dictionary, owner: int, card_id: String) -> Dictionary:
	if state.players[owner].board.size() >= MAX_BOARD:
		return {}
	var definition: Dictionary = Cards.card(card_id)
	var unit: Dictionary = {"uid": state.next_uid, "card_id": card_id, "attack": definition.attack, "hp": definition.hp, "max_hp": definition.hp, "guard": definition.guard, "ready": false}
	state.next_uid += 1
	state.players[owner].board.append(unit)
	_event(state, "summon", "「%s」来到场上。" % definition.name, owner, {"card_id": card_id, "uid": unit.uid})
	return unit

static func _run_effects(state: Dictionary, effects: Array, owner: int, target: Dictionary, source_uid: int) -> void:
	for effect: Dictionary in effects:
		match effect.kind:
			"damage_target":
				if not target.is_empty():
					_damage(state, target, effect.amount)
			"heal_target":
				if not target.is_empty():
					_heal(state, target, effect.amount)
			"buff_target":
				if not target.is_empty():
					_buff(state, target, effect.attack, effect.hp)
			"heal_hero":
				_heal(state, {"player": owner, "uid": 0}, effect.amount)
			"damage_enemy_hero":
				_damage(state, {"player": 1 - owner, "uid": 0}, effect.amount)
			"draw":
				for ignored in int(effect.amount):
					_draw(state, owner)
			"mana":
				state.players[owner].mana += effect.amount
				_event(state, "mana", "%s本回合额外获得 %d 点费用。" % [_who(owner), effect.amount], owner, {"amount": effect.amount})
			"summon":
				for ignored in int(effect.count):
					_summon(state, owner, effect.card_id)
			"buff_all":
				for unit: Dictionary in state.players[owner].board:
					if effect.get("exclude_source", false) and unit.uid == source_uid:
						continue
					_buff(state, {"player": owner, "uid": unit.uid}, effect.attack, effect.hp)
			"damage_enemy_minions":
				for unit: Dictionary in state.players[1 - owner].board:
					_damage(state, {"player": 1 - owner, "uid": unit.uid}, effect.amount)
			"damage_all_characters":
				for index in 2:
					_damage(state, {"player": index, "uid": 0}, effect.amount)
					for unit: Dictionary in state.players[index].board:
						_damage(state, {"player": index, "uid": unit.uid}, effect.amount)

static func _damage(state: Dictionary, target: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	if target.uid == 0:
		state.players[target.player].hp -= amount
		_event(state, "damage", "%s的英雄受到 %d 点伤害。" % [_who(target.player), amount], target.player, {"target": target.duplicate(), "amount": amount})
	else:
		var unit: Dictionary = find_unit(state, target.player, target.uid)
		if not unit.is_empty():
			unit.hp -= amount
			_event(state, "damage", "「%s」受到 %d 点伤害。" % [Cards.card(unit.card_id).name, amount], target.player, {"target": target.duplicate(), "amount": amount})

static func _heal(state: Dictionary, target: Dictionary, amount: int) -> void:
	var restored := 0
	if target.uid == 0:
		var hero: Dictionary = state.players[target.player]
		restored = mini(amount, MAX_HP - int(hero.hp))
		hero.hp += restored
	else:
		var unit: Dictionary = find_unit(state, target.player, target.uid)
		if unit.is_empty() or unit.hp <= 0:
			return
		restored = mini(amount, int(unit.max_hp) - int(unit.hp))
		unit.hp += restored
	if restored > 0:
		_event(state, "heal", "恢复了 %d 点生命。" % restored, target.player, {"target": target.duplicate(), "amount": restored})

static func _buff(state: Dictionary, target: Dictionary, attack: int, hp: int) -> void:
	var unit: Dictionary = find_unit(state, target.player, target.uid)
	if unit.is_empty() or unit.hp <= 0:
		return
	unit.attack += attack
	unit.hp += hp
	unit.max_hp += hp
	_event(state, "buff", "「%s」获得 +%d/+%d。" % [Cards.card(unit.card_id).name, attack, hp], target.player, {"target": target.duplicate(), "attack": attack, "hp": hp})

static func _resolve_deaths(state: Dictionary) -> void:
	while true:
		var dead: Array[Dictionary] = []
		# Batch removal creates all empty slots before any death effect runs.
		for owner in [int(state.current_player), 1 - int(state.current_player)]:
			var board: Array = state.players[owner].board
			for unit: Dictionary in board:
				if unit.hp <= 0:
					dead.append({"owner": owner, "unit": unit})
			for i in range(board.size() - 1, -1, -1):
				if board[i].hp <= 0:
					board.remove_at(i)
		if dead.is_empty():
			return
		for entry: Dictionary in dead:
			state.players[entry.owner].discard.append(entry.unit.card_id)
			_event(state, "death", "「%s」退场。" % Cards.card(entry.unit.card_id).name, entry.owner, {"uid": entry.unit.uid, "card_id": entry.unit.card_id})
		for entry: Dictionary in dead:
			var definition: Dictionary = Cards.card(entry.unit.card_id)
			_run_effects(state, definition.deathrattle, entry.owner, {}, entry.unit.uid)

static func _check_winner(state: Dictionary) -> void:
	if state.winner != ONGOING:
		return
	var dead0: bool = state.players[0].hp <= 0
	var dead1: bool = state.players[1].hp <= 0
	if not dead0 and not dead1:
		return
	state.winner = DRAW if dead0 and dead1 else (1 if dead0 else 0)
	state.finish_reason = "health"
	_event(state, "finish", _finish_text(state.winner), state.winner)

static func _finish_by_health(state: Dictionary) -> void:
	var hp0: int = state.players[0].hp
	var hp1: int = state.players[1].hp
	state.winner = DRAW if hp0 == hp1 else (0 if hp0 > hp1 else 1)
	state.finish_reason = "turn_limit"
	_event(state, "finish", "达到 60 回合上限，按英雄生命判定。" + _finish_text(state.winner), state.winner)

static func _finish_text(winner: int) -> String:
	return "本局平局。" if winner == DRAW else ("你赢得了林间牌局！" if winner == 0 else "对手赢得了这一局。")

static func _who(player: int) -> String:
	return "你" if player == 0 else "对手"

static func _event(state: Dictionary, type: String, message: String, player: int, extra: Dictionary = {}) -> void:
	var event := {"type": type, "text": message, "player": player}
	event.merge(extra)
	state.last_events.append(event)
