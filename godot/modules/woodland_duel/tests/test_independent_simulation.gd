extends SceneTree
# All matches use production new_match/legal_actions/apply_action, without state injection.
# This measures model turns and choices, not human play time or native UI performance.
const Rules = preload("res://modules/woodland_duel/rules.gd")
const AI = preload("res://modules/woodland_duel/ai.gd")
const DECKS := ["forest", "toys", "spores"]
var failures := 0
var checks := 0
var records: Array = []

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL independent simulation: " + label)

func run() -> void:
	var seeds := 24
	var mode := "normal"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="): seeds = int(arg.trim_prefix("seeds="))
		if arg.begins_with("mode="): mode = arg.trim_prefix("mode=")
	for deck_a in DECKS:
		for deck_b in DECKS:
			for seed_index in range(seeds):
				for first in [0, 1]:
					simulate(deck_a, deck_b, 20261029 + seed_index, first, mode)
	print("INDEPENDENT_SIMULATION_JSON=" + JSON.stringify({"mode":mode,"seeds_per_pair":seeds,"games":records,"checks":checks,"failures":failures}))
	print("WOODLAND INDEPENDENT SIMULATION: %d games, %d checks, %d failures" % [records.size(), checks, failures])
	quit(0 if failures == 0 else 1)

func simulate(deck_a: String, deck_b: String, seed_value: int, first: int, mode: String) -> void:
	var state: Dictionary = Rules.new_match(deck_a, deck_b, seed_value, first)
	var choices := 0
	var replay: Array = []
	var local_failures := failures
	var random := RandomNumberGenerator.new()
	random.seed = seed_value * 31 + first
	while int(state.winner) == -2 and choices < 900:
		var before := state.duplicate(true)
		var legal: Array = Rules.legal_actions(state)
		check(state == before, "enumerating legal actions is read only")
		check(not legal.is_empty(), "active player always has an action")
		if legal.is_empty(): break
		var action: Dictionary
		if mode == "mixed" and state.current_player == 0:
			action = baseline_action(legal, random)
		else:
			action = AI.choose_action(state)
		check(state == before, "AI decision is read only")
		check(legal.has(action), "selected action appears in legal enumeration")
		replay.append(action.duplicate(true))
		var result: Dictionary = Rules.apply_action(state, action)
		check(result.get("ok",false), "selected action applies successfully")
		if not result.get("ok",false): break
		check_invariants(state)
		choices += 1
	check(state.winner != -2, "legal match finishes under 900 decisions")
	var record := {"deck0":deck_a,"deck1":deck_b,"seed":seed_value,"first":first,"winner":state.winner,"turns":state.turn,"decisions":choices,"hp0":state.players[0].hp,"hp1":state.players[1].hp,"failures":failures-local_failures}
	records.append(record)
	if failures != local_failures:
		printerr("REPLAY_FAILURE=" + JSON.stringify({"record":record,"actions":replay}))

func baseline_action(legal: Array, random: RandomNumberGenerator) -> Dictionary:
	# Independent policy: prefer a uniformly selected legal non-pass action.
	# It never examines hidden hands/decks, scores cards or uses private model APIs.
	var non_pass: Array = []
	for action in legal:
		if action.get("type","") != "end_turn": non_pass.append(action)
	return legal[0] if non_pass.is_empty() else non_pass[random.randi_range(0,non_pass.size()-1)]

func check_invariants(state: Dictionary) -> void:
	check(int(state.current_player) in [0,1], "current side valid")
	check(int(state.winner) in [-2,-1,0,1], "winner valid")
	var seen_uids: Array = []
	for player in state.players:
		check(player.hand.size() <= 8, "hand cap never exceeded")
		check(player.board.size() <= 4, "board cap never exceeded")
		check(player.mana >= 0 and player.mana <= 7, "available mana bounded including temporary bonus")
		check(player.max_mana >= 0 and player.max_mana <= 6, "permanent mana cap never exceeded")
		check(player.hp <= 20, "hero does not heal above cap")
		check(player.fatigue >= 0, "fatigue nonnegative")
		for unit in player.board:
			check(unit.hp > 0 and unit.hp <= unit.max_hp, "living unit health valid")
			check(unit.attack >= 0, "unit attack nonnegative")
			check(unit.uid > 0 and not seen_uids.has(unit.uid), "unit UID positive and globally unique")
			seen_uids.append(unit.uid)
