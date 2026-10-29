extends SceneTree
const Rules = preload("../rules.gd")
const Cards = preload("../cards.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_test_catalog()
	_test_opening_and_turns()
	_test_validation()
	_test_guard_and_combat()
	_test_spells_and_battlecries()
	_test_deaths_and_chains()
	_test_draw_fatigue_and_finish()
	print("WOODLAND_RULES checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _blank() -> Dictionary:
	var state: Dictionary = Rules.new_match("forest", "toys", 123, 0)
	for player: Dictionary in state.players:
		player.hand = []
		player.deck = ["forest_squirrel", "forest_squirrel", "forest_squirrel"]
		player.board = []
		player.discard = []
		player.mana = 6
		player.max_mana = 6
		player.hp = 20
	return state

func _unit(state: Dictionary, owner: int, card_id: String, ready: bool = true) -> Dictionary:
	var definition: Dictionary = Cards.card(card_id)
	var unit: Dictionary = {"uid": state.next_uid, "card_id": card_id, "attack": definition.attack, "hp": definition.hp, "max_hp": definition.hp, "guard": definition.guard, "ready": ready}
	state.next_uid += 1
	state.players[owner].board.append(unit)
	return unit

func _play(state: Dictionary, id: String, target: Dictionary = {}) -> Dictionary:
	state.players[state.current_player].hand.append(id)
	var action := {"type": "play", "hand_index": state.players[state.current_player].hand.size() - 1}
	if not target.is_empty():
		action.target = target
	return Rules.apply_action(state, action)

func _end(state: Dictionary) -> void:
	_check(Rules.apply_action(state, {"type": "end_turn"}).ok, "end turn legal")

func _test_catalog() -> void:
	_check(Cards.all_cards().size() == 30, "30 original deck cards")
	for id: String in Cards.DECK_IDS:
		var deck: Array[String] = Cards.deck_cards(id)
		_check(deck.size() == 20, "%s has exactly 20 cards" % id)
		var counts := {}
		for card_id in deck:
			counts[card_id] = counts.get(card_id, 0) + 1
		_check(counts.size() == 10, "%s has 10 unique cards" % id)
		for count: int in counts.values():
			_check(count == 2, "exactly two copies")
	for definition: Dictionary in Cards.all_cards(true):
		_check(not definition.name.is_empty() and not definition.art_key.is_empty(), "card presentation defined")
		_check(definition.cost >= 0 and definition.cost <= 6, "card cost in range")
	var altered: Dictionary = Cards.card("forest_squirrel")
	altered.attack = 99
	_check(Cards.card("forest_squirrel").attack == 2, "catalog cannot mutate through returned dictionary")

func _test_opening_and_turns() -> void:
	for first in 2:
		var state: Dictionary = Rules.new_match("forest", "toys", 42, first)
		_check(state.players[first].hand.size() == 4, "first receives three and draws one at start")
		_check(state.players[1 - first].hand.size() == 5, "second starts four plus compensation")
		_check(state.players[first].deck.size() == 16 and state.players[1 - first].deck.size() == 16, "opening draws from own decks")
		_check(state.players[first].mana == 1 and state.players[1 - first].mana == 0, "opening mana belongs only to active player")
		_check(JSON.stringify(state) == JSON.stringify(Rules.new_match("forest", "toys", 42, first)), "seed determinism")
		_end(state)
		_check(state.players[1 - first].hand.size() == 6, "second player draws on first turn")
		var sunlight_index: int = state.players[state.current_player].hand.find("sunlight")
		_check(Rules.apply_action(state, {"type": "play", "hand_index": sunlight_index}).ok, "compensation playable")
		_check(state.players[state.current_player].mana == 2 and state.players[state.current_player].max_mana == 1, "compensation is temporary")
		_end(state)
		_end(state)
		_check(state.players[1 - first].mana == 2 and state.players[1 - first].max_mana == 2, "temporary mana not retained")
	var state := _blank()
	state.players[0].mana = 0
	_end(state)
	_end(state)
	_check(state.players[0].max_mana == 6 and state.players[0].mana == 6, "mana capped and replenished")
	_check(_play(state, "sunlight").ok and state.players[0].mana == 7, "temporary seventh mana allowed")

func _test_validation() -> void:
	var state := _blank()
	state.players[0].hand = ["forest_bear"]
	state.players[0].mana = 1
	var before := JSON.stringify(state)
	for action in [{"type": "play", "hand_index": 0}, {"type": "play", "hand_index": -1}, {"type": "play", "hand_index": "0"}, {"type": "attack", "attacker_uid": 999, "target": {"player": 1, "uid": 0}}, {"type": "bogus"}, {}]:
		_check(not Rules.apply_action(state, action).ok, "invalid action rejected")
		_check(JSON.stringify(state) == before, "invalid action leaves all state unchanged")
	state.players[0].mana = 6
	for ignored in 4:
		_unit(state, 0, "forest_squirrel")
	state.players[0].hand = ["forest_squirrel", "toy_parts"]
	before = JSON.stringify(state)
	_check(not Rules.apply_action(state, {"type": "play", "hand_index": 0}).ok, "full board blocks minion")
	_check(not Rules.apply_action(state, {"type": "play", "hand_index": 1}).ok, "full board blocks summon spell")
	_check(JSON.stringify(state) == before, "full-board rejection nonmutating")
	state.players[0].board.pop_back()
	_check(Rules.apply_action(state, {"type": "play", "hand_index": 1}).ok and state.players[0].board.size() == 4, "summon fills one remaining slot only")
	_check(not state.players[0].board.back().ready, "summoned token cannot immediately attack")

func _test_guard_and_combat() -> void:
	var state := _blank()
	var attacker := _unit(state, 0, "toy_rabbit")
	_unit(state, 0, "forest_hedgehog")
	var guard := _unit(state, 1, "forest_hedgehog")
	var other := _unit(state, 1, "forest_squirrel")
	var targets: Array[Dictionary] = Rules.attack_targets(state, attacker.uid)
	_check(targets.size() == 1 and targets[0].uid == guard.uid, "enemy guard limits attacks despite friendly guard")
	_check(not Rules.apply_action(state, {"type": "attack", "attacker_uid": attacker.uid, "target": {"player": 1, "uid": other.uid}}).ok, "cannot bypass guard")
	_check(Rules.apply_action(state, {"type": "attack", "attacker_uid": attacker.uid, "target": {"player": 1, "uid": guard.uid}}).ok, "guard attack legal")
	_check(attacker.hp == 1 and guard.hp == 1 and not attacker.ready, "combat simultaneously damages both and exhausts attacker")
	_check(Rules.attack_targets(state, attacker.uid).is_empty(), "only one attack per turn")
	_end(state)
	_end(state)
	_check(attacker.ready, "attack refreshes on own next turn")
	state = _blank()
	attacker = _unit(state, 0, "toy_rabbit")
	other = _unit(state, 1, "toy_rabbit")
	Rules.apply_action(state, {"type": "attack", "attacker_uid": attacker.uid, "target": {"player": 1, "uid": other.uid}})
	_check(state.players[0].board.is_empty() and state.players[1].board.is_empty(), "simultaneous combat deaths")
	state = _blank()
	_check(_play(state, "forest_squirrel").ok, "play minion")
	attacker = state.players[0].board[0]
	_check(Rules.attack_targets(state, attacker.uid).is_empty(), "summoning waiting state")
	_end(state)
	_end(state)
	_check(not Rules.attack_targets(state, attacker.uid).is_empty(), "new unit ready after own turn starts")
	var hp: int = attacker.hp
	Rules.apply_action(state, {"type": "attack", "attacker_uid": attacker.uid, "target": {"player": 1, "uid": 0}})
	_check(state.players[1].hp == 18 and attacker.hp == hp, "heroes do not retaliate")

func _test_spells_and_battlecries() -> void:
	var state := _blank()
	_check(not _play(state, "forest_acorn", {"player": 1, "uid": 0}).ok, "minion-only spell cannot hit hero")
	_check(not _play(state, "toy_reinforce").ok, "pure buff requires a minion")
	_check(not _play(state, "spore_mist").ok, "pure area damage requires enemy minion")
	_check(_play(state, "forest_rally").ok and state.players[1].hp == 18, "rally still affects enemy hero with empty friendly board")
	state = _blank()
	var guard := _unit(state, 1, "forest_hedgehog")
	guard.hp = 1
	var attacker := _unit(state, 0, "forest_squirrel")
	_check(_play(state, "toy_bird", {"player": 1, "uid": guard.uid}).ok, "targeted battlecry")
	_check(Rules.find_unit(state, 1, guard.uid).is_empty(), "battlecry kills guard before next action")
	_check(Rules.attack_targets(state, attacker.uid)[0].uid == 0, "hero exposed after guard death")
	state = _blank()
	_check(_play(state, "spore_spitter").ok, "minion targeted battlecry allowed without targets")
	state = _blank()
	_unit(state, 1, "forest_hedgehog")
	_check(_play(state, "toy_spark", {"player": 1, "uid": 0}).ok and state.players[1].hp == 17, "spells ignore guard")
	state = _blank()
	var ally := _unit(state, 0, "forest_squirrel")
	_check(_play(state, "forest_growth", {"player": 0, "uid": ally.uid}).ok, "friendly buff valid")
	_check(ally.attack == 4 and ally.hp == 3 and ally.max_hp == 3, "buff grows both hp limits")
	ally.hp = 1
	_check(_play(state, "toy_repair", {"player": 0, "uid": ally.uid}).ok and ally.hp == 3, "healing capped at max hp")
	state.players[0].hp = 19
	_check(_play(state, "toy_repair", {"player": 0, "uid": 0}).ok and state.players[0].hp == 20, "hero healing capped at20")
	state = _blank()
	ally = _unit(state, 0, "forest_squirrel")
	_check(_play(state, "spore_elder").ok, "elder playable")
	_check(ally.attack == 3 and state.players[0].board.back().attack == 4, "elder buffs others, not self")

func _test_deaths_and_chains() -> void:
	var state := _blank()
	state.players[0].hp = 2
	state.players[1].hp = 2
	var own_box := _unit(state, 0, "toy_box")
	own_box.hp = 1
	var enemy_box := _unit(state, 1, "toy_box")
	enemy_box.hp = 1
	_check(_play(state, "toy_spark", {"player": 1, "uid": enemy_box.uid}).ok, "trigger death chain legally")
	_check(state.players[0].board.is_empty() and state.players[1].board.is_empty(), "death chain clears both boxes")
	_check(state.winner == Rules.DRAW and state.players[0].hp == 0 and state.players[1].hp == 0, "death chain simultaneous hero lethal is draw")
	for sprout_first in [false, true]:
		state = _blank()
		var first := _unit(state, 0, "spore_sprout" if sprout_first else "toy_box")
		var second := _unit(state, 0, "toy_box" if sprout_first else "spore_sprout")
		first.hp = 1
		second.hp = 1
		enemy_box = _unit(state, 1, "toy_box")
		enemy_box.hp = 1
		_play(state, "toy_spark", {"player": 1, "uid": enemy_box.uid})
		_check(state.players[0].board.size() == (0 if sprout_first else 1), "death effects use original slot order, resolve new deaths next batch")
	state = _blank()
	for ignored in 4:
		_unit(state, 0, "spore_sprout").hp = 1
	enemy_box = _unit(state, 1, "toy_box")
	enemy_box.hp = 1
	_play(state, "toy_spark", {"player": 1, "uid": enemy_box.uid})
	_check(state.players[0].board.size() == 4, "all dead units removed before replacement summons")
	for unit: Dictionary in state.players[0].board:
		_check(unit.card_id == "token_spore" and not unit.ready, "death summons are fresh waiting tokens")

func _test_draw_fatigue_and_finish() -> void:
	var state := _blank()
	state.players[0].hand = ["forest_trail"]
	for ignored in 7:
		state.players[0].hand.append("forest_squirrel")
	state.players[0].deck = ["forest_bear", "forest_owl"]
	Rules.apply_action(state, {"type": "play", "hand_index": 0})
	_check(state.players[0].hand.size() == 8 and state.players[0].deck.is_empty(), "hand cap burns excess draw")
	_check("forest_bear" in state.players[0].discard, "burned card tracked")
	state = _blank()
	state.players[0].deck = []
	state.players[0].hp = 10
	_check(_play(state, "forest_trail").ok and state.players[0].hp == 7 and state.players[0].fatigue == 2, "multiple empty draws deal1 then2")
	state.players[0].mana = 6
	_check(_play(state, "forest_trail").ok and state.players[0].hp == 0 and state.winner == 1, "fatigue3 plus4 causes loss")
	var before := JSON.stringify(state)
	for action in [{"type": "end_turn"}, {"type": "play", "hand_index": 0}]:
		_check(not Rules.apply_action(state, action).ok and JSON.stringify(state) == before, "finished game immutable")
	_check(Rules.legal_actions(state).is_empty(), "no legal actions after finish")
	for hp in [19, 20, 21]:
		state = _blank()
		state.turn = 60
		state.players[0].hp = hp
		_end(state)
		_check(state.winner == (1 if hp < 20 else (0 if hp > 20 else -1)) and state.finish_reason == "turn_limit", "turn limit judges hp with tie draw")
	state = _blank()
	state.players[1].deck = []
	state.players[1].hp = 1
	_end(state)
	_check(state.winner == 0, "start-of-turn fatigue can end match")
