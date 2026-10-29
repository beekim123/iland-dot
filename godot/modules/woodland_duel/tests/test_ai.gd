extends SceneTree
const Rules = preload("../rules.gd")
const Cards = preload("../cards.gd")
const AI = preload("../ai.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_test_tactics()
	_test_information_boundary()
	_test_natural_matches()
	print("WOODLAND_AI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _blank() -> Dictionary:
	var state: Dictionary = Rules.new_match("forest", "toys", 321, 0)
	for player: Dictionary in state.players:
		player.hand = []
		player.board = []
		player.mana = 6
		player.max_mana = 6
	return state

func _unit(state: Dictionary, owner: int, id: String) -> Dictionary:
	var definition: Dictionary = Cards.card(id)
	var result: Dictionary = {"uid": state.next_uid, "card_id": id, "attack": definition.attack, "hp": definition.hp, "max_hp": definition.hp, "guard": definition.guard, "ready": true}
	state.next_uid += 1
	state.players[owner].board.append(result)
	return result

func _test_tactics() -> void:
	var state := _blank()
	state.players[0].hand = ["toy_spark", "forest_bear"]
	state.players[1].hp = 3
	_unit(state, 1, "forest_hedgehog")
	var action: Dictionary = AI.choose_action(state)
	_check(action.get("type") == "play" and action.get("hand_index") == 0 and action.get("target", {}).get("uid") == 0, "AI finds spell lethal through guard")
	Rules.apply_action(state, action)
	_check(state.winner == 0, "AI lethal actually wins")
	_check(AI.choose_action(state).is_empty(), "AI inactive after terminal state")
	state = _blank()
	state.players[0].mana = 5
	state.players[0].hand = ["sunlight", "forest_bear"]
	action = AI.choose_action(state)
	_check(action.get("type") == "play" and action.get("hand_index") == 0, "AI plans compensation into six-cost minion")
	Rules.apply_action(state, action)
	action = AI.choose_action(state)
	_check(action.get("type") == "play" and action.get("hand_index") == 0, "AI follows through and plays expensive minion")
	state = _blank()
	_unit(state, 0, "toy_rabbit")
	_unit(state, 0, "forest_squirrel")
	state.players[1].hp = 5
	for ignored in 2:
		action = AI.choose_action(state)
		_check(action.get("type") == "attack" and action.get("target", {}).get("uid") == 0, "AI combines attacks for lethal")
		Rules.apply_action(state, action)
	_check(state.winner == 0, "combined attacks win")
	state = _blank()
	var attacker := _unit(state, 0, "toy_rabbit")
	var guard := _unit(state, 1, "forest_hedgehog")
	guard.hp = 1
	action = AI.choose_action(state)
	_check(action.get("type") == "attack" and action.get("attacker_uid") == attacker.uid and action.get("target", {}).get("uid") == guard.uid, "AI respects and removes guard")
	state = _blank()
	state.players[0].hp = 2
	state.players[0].hand = ["forest_hedgehog", "forest_squirrel"]
	_unit(state, 1, "toy_rabbit")
	action = AI.choose_action(state)
	_check(action.get("type") == "play" and action.get("hand_index") == 0, "AI prioritizes guard against lethal threat")

func _test_information_boundary() -> void:
	var state := _blank()
	state.players[0].hand = ["forest_trail", "forest_owl", "forest_squirrel"]
	state.players[1].hand = ["toy_rabbit", "toy_spark"]
	_unit(state, 1, "spore_sprout")
	var before := JSON.stringify(state)
	var first: Dictionary = AI.choose_action(state)
	_check(JSON.stringify(state) == before, "AI selection does not mutate state")
	var hidden: Dictionary = state.duplicate(true)
	hidden.players[1].hand = ["toy_golem", "toy_parts"]
	hidden.players[1].deck.reverse()
	hidden.players[0].deck.reverse()
	var second: Dictionary = AI.choose_action(hidden)
	_check(first == second, "AI independent of enemy hand identities and unseen draw order")
	_check(first == AI.choose_action(state), "AI deterministic for same state")

func _test_natural_matches() -> void:
	var games := 0
	var wins := [0, 0, 0]
	var minimum_turns := 999
	var maximum_turns := 0
	var total_turns := 0
	var maximum_decision_us := 0
	for deck0: String in Cards.DECK_IDS:
		for deck1: String in Cards.DECK_IDS:
			for first in 2:
				var state: Dictionary = Rules.new_match(deck0, deck1, 8700 + games, first)
				var actions := 0
				while state.winner == Rules.ONGOING and actions < 1500:
					var before := JSON.stringify(state)
					var started := Time.get_ticks_usec()
					var action: Dictionary = AI.choose_action(state)
					maximum_decision_us = maxi(maximum_decision_us, Time.get_ticks_usec() - started)
					_check(JSON.stringify(state) == before, "natural AI action selection read-only")
					var legal: Array[Dictionary] = Rules.legal_actions(state)
					_check(action in legal, "natural AI action is in legal set")
					var result: Dictionary = Rules.apply_action(state, action)
					_check(result.ok, "natural AI action accepted")
					for player: Dictionary in state.players:
						_check(player.board.size() <= 4 and player.hand.size() <= 8, "natural slot and hand caps")
						_check(player.mana >= 0 and player.max_mana <= 6, "natural mana valid")
						for unit: Dictionary in player.board:
							_check(unit.hp > 0 and unit.hp <= unit.max_hp, "natural surviving unit hp valid")
					actions += 1
				_check(state.winner in [-1, 0, 1], "natural complete game terminates")
				_check(state.turn <= 60, "natural game respects turn cap")
				_check(state.finish_reason == "health", "natural game reaches health conclusion without artificial timeout")
				if state.winner in [0, 1]:
					wins[state.winner] += 1
				else:
					wins[2] += 1
				minimum_turns = mini(minimum_turns, state.turn)
				maximum_turns = maxi(maximum_turns, state.turn)
				total_turns += state.turn
				games += 1
	print("WOODLAND_AI_NATURAL games=%d player0_wins=%d player1_wins=%d draws=%d half_turns_min=%d max=%d mean=%.1f max_decision_ms=%.2f" % [games, wins[0], wins[1], wins[2], minimum_turns, maximum_turns, float(total_turns) / games, float(maximum_decision_us) / 1000.0])
