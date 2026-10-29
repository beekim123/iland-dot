extends SceneTree
# Independent contract audit. Boundary fixtures are not balance simulations.
const Rules = preload("res://modules/woodland_duel/rules.gd")
const AI = preload("res://modules/woodland_duel/ai.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL independent contract: " + label)

func unchanged_rejection(state: Dictionary, action: Dictionary, label: String) -> void:
	var before := state.duplicate(true)
	var result: Dictionary = Rules.apply_action(state, action)
	check(not result.get("ok", false), label + " rejected")
	check(state == before, label + " leaves exact state unchanged")

func run() -> void:
	for first in [0, 1]:
		var state: Dictionary = Rules.new_match("forest", "forest", 7029, first)
		check(state.current_player == first, "explicit first-player selection")
		check(state.winner == -2, "new match active")
		for side in [0, 1]:
			var player: Dictionary = state.players[side]
			check(player.hp == 20 and player.board.is_empty(), "opening health and board")
			check(player.hand.size() == (4 if side == first else 5), "opening hand plus second-player compensation exact count")
			check(player.deck.size() == 16, "opening deck size exact")
			check(player.mana == (1 if side == first else 0), "opening mana only belongs to first side")
		check(state == Rules.new_match("forest", "forest", 7029, first), "same seed has exact same initial state")
		for action in [{}, {"type":"unknown"}, {"type":false}, {"type":"play","hand_index":0.0}, {"type":"play","hand_index":true}, {"type":"play","hand_index":0,"target":"enemy"}, {"type":"play","hand_index":-1}, {"type":"play","hand_index":999}, {"type":"attack","attacker_uid":0,"target":{"player":1-first,"uid":0}}, {"type":"attack","attacker_uid":9999,"target":{"player":1-first,"uid":0}}]:
			unchanged_rejection(state, action, "malformed or unavailable action " + str(action))
		for outcome in [-1, 0, 1]:
			var terminal := state.duplicate(true)
			terminal.winner = outcome
			check(Rules.legal_actions(terminal).is_empty(), "terminal has no legal actions")
			for action in [{"type":"end_turn"},{"type":"play","hand_index":0},{"type":"attack","attacker_uid":1,"target":{"player":1-first,"uid":0}}]:
				unchanged_rejection(terminal, action, "terminal action")
	for first in [0,1]:
		for deck in ["forest","toys","spores"]:
			for seed_value in [20261029,77123]:
				check_replay_and_hidden_information(deck,seed_value,first)
	print("WOODLAND INDEPENDENT CONTRACT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check_replay_and_hidden_information(deck: String, seed_value: int, first: int) -> void:
	var state: Dictionary = Rules.new_match(deck, "forest", seed_value, first)
	var replay: Dictionary = state.duplicate(true)
	var decisions := 0
	while state.winner == -2 and decisions < 500:
		var before := state.duplicate(true)
		var action: Dictionary = AI.choose_action(state)
		check(state == before, "AI choose does not mutate source")
		var alternate := state.duplicate(true)
		var opponent: Dictionary = alternate.players[1 - int(alternate.current_player)]
		opponent.hand.reverse()
		opponent.deck.reverse()
		# Exchange a hidden real card between hand and deck, preserving all public
		# counts and the deck multiset. The known compensation card stays in hand.
		if not opponent.deck.is_empty():
			for i in opponent.hand.size():
				if opponent.hand[i] != "sunlight":
					var old: String = opponent.hand[i]
					opponent.hand[i] = opponent.deck[0]
					opponent.deck[0] = old
					break
		check(AI.choose_action(alternate) == action, "AI independent of opponent hidden hand/deck composition and order")
		var unknown_draws := state.duplicate(true)
		unknown_draws.players[state.current_player].deck.reverse()
		check(AI.choose_action(unknown_draws) == action, "AI cannot use future own deck order")
		check(AI.choose_action(state) == action, "AI deterministic on identical state")
		check(Rules.legal_actions(state).has(action), "AI returns model-legal action")
		var left: Dictionary = Rules.apply_action(state, action)
		var right: Dictionary = Rules.apply_action(replay, action.duplicate(true))
		check(left.ok and right.ok, "identical replay actions accepted")
		check(state == replay, "identical seed/action replay exact-state equality")
		decisions += 1
	check(state.winner != -2, "complete legal replay reaches a result")
