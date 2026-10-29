extends RefCounted
## A small deterministic tactical search: all legal first actions, then a beam of
## own-turn followups. It values survival, trades, guarding and lethal damage.
## It never examines opponent hand identities or future deck order in evaluation.
const Rules = preload("rules.gd")
const Cards = preload("cards.gd")
const BEAM_WIDTH := 6
const SEARCH_DEPTH := 3

static func choose_action(state: Dictionary, difficulty: String = "normal") -> Dictionary:
	var legal: Array[Dictionary] = Rules.legal_actions(state)
	if legal.is_empty():
		return {}
	var owner: int = state.current_player
	var best_action: Dictionary = {"type": "end_turn"}
	var best_score := -INF
	var frontier: Array[Dictionary] = []
	for action: Dictionary in legal:
		var simulated: Dictionary = state.duplicate(true)
		var result: Dictionary = Rules.apply_action(simulated, action)
		if not result.ok:
			continue
		var score := _evaluate(simulated, owner) - 0.015
		if score > best_score:
			best_score = score
			best_action = action
		if simulated.winner == owner:
			return action.duplicate(true)
		if _can_expand(simulated, owner, result.events):
			frontier.append({"state": simulated, "first": action, "score": score})
	if difficulty == "easy":
		return best_action.duplicate(true)
	# A card drawn during a hypothetical branch is never used for planning. This
	# makes the decision independent of unknown future draw order, without cheating.
	for depth in range(1, SEARCH_DEPTH):
		frontier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score)
		if frontier.size() > BEAM_WIDTH:
			frontier.resize(BEAM_WIDTH)
		var next: Array[Dictionary] = []
		for node: Dictionary in frontier:
			for action: Dictionary in Rules.legal_actions(node.state):
				if action.type == "end_turn":
					continue
				var simulated: Dictionary = node.state.duplicate(true)
				var result: Dictionary = Rules.apply_action(simulated, action)
				if not result.ok:
					continue
				var score := _evaluate(simulated, owner) - 0.015 * float(depth + 1)
				if score > best_score:
					best_score = score
					best_action = node.first
				if simulated.winner == owner:
					return node.first.duplicate(true)
				if _can_expand(simulated, owner, result.events):
					next.append({"state": simulated, "first": node.first, "score": score})
		frontier = next
		if frontier.is_empty():
			break
	return best_action.duplicate(true)

static func _can_expand(state: Dictionary, owner: int, events: Array) -> bool:
	if state.winner != Rules.ONGOING or state.current_player != owner:
		return false
	for event: Dictionary in events:
		if event.type in ["draw", "burn", "fatigue"]:
			return false
	return true

static func _evaluate(state: Dictionary, owner: int) -> float:
	if state.winner != Rules.ONGOING:
		if state.winner == Rules.DRAW:
			return -150.0
		return 100000.0 if state.winner == owner else -100000.0
	var mine: Dictionary = state.players[owner]
	var theirs: Dictionary = state.players[1 - owner]
	var result := _health_value(mine.hp) - _health_value(theirs.hp)
	result += 0.85 * float(mine.hand.size()) - 0.65 * float(theirs.hand.size())
	result += 0.12 * float(mine.mana)
	result += 0.06 * float(mine.deck.size() - theirs.deck.size())
	var guard_health := 0
	var incoming_attack := 0
	for unit: Dictionary in mine.board:
		result += _unit_value(unit)
		if unit.guard:
			guard_health += unit.hp
	for unit: Dictionary in theirs.board:
		result -= _unit_value(unit) * 1.10
		incoming_attack += unit.attack
	var exposed_damage := maxi(0, incoming_attack - guard_health)
	if exposed_damage >= mine.hp:
		result -= 60.0 + float(exposed_damage - int(mine.hp)) * 2.0
	elif exposed_damage > int(mine.hp) / 2:
		result -= 0.6 * float(exposed_damage)
	return result

static func _unit_value(unit: Dictionary) -> float:
	var result := 1.5 * float(unit.attack) + 0.8 * float(unit.hp) + 0.7
	if unit.guard:
		result += 0.85
	if unit.ready:
		result += 0.12
	var deathrattle: Array = Cards.card(unit.card_id).deathrattle
	for effect: Dictionary in deathrattle:
		match effect.kind:
			"summon":
				result += 1.0 * float(effect.count)
			"heal_hero", "damage_enemy_hero":
				result += 0.35 * float(effect.amount)
			"damage_all_characters":
				result += 0.2
	return result

static func _health_value(hp: int) -> float:
	return 0.65 * float(hp) - 0.8 * float(maxi(0, 8 - hp))
