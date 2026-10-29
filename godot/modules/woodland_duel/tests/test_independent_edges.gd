extends SceneTree
# Deliberate boundary fixtures isolate production rule transitions.
# These are NOT used as evidence for balance or duration; those use untouched legal games.
const Rules = preload("res://modules/woodland_duel/rules.gd")
const Cards = preload("res://modules/woodland_duel/cards.gd")
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL independent edges: " + label)
func fresh(hand: Array = []) -> Dictionary:
	var state: Dictionary = Rules.new_match("forest","toys",441,0)
	state.players[0].hand = hand.duplicate()
	state.players[0].mana = 6
	state.players[0].max_mana = 6
	return state
func unit(card_id: String, uid: int, hp: int = -1, ready: bool = true) -> Dictionary:
	var card: Dictionary = Cards.card(card_id)
	return {"uid":uid,"card_id":card_id,"attack":card.attack,"hp":card.hp if hp < 0 else hp,"max_hp":card.hp,"guard":card.guard,"ready":ready}
func play(state: Dictionary, index: int = 0, target: Dictionary = {}) -> Dictionary:
	return Rules.apply_action(state,{"type":"play","hand_index":index,"target":target})
func reject(state: Dictionary, action: Dictionary, label: String) -> void:
	var before := state.duplicate(true)
	check(not Rules.apply_action(state,action).ok,label+" rejected")
	check(state == before,label+" is transactional")
func run() -> void:
	catalog_checks()
	mana_and_readiness()
	target_and_guard_checks()
	capacity_and_effect_checks()
	death_checks()
	draw_and_fatigue_checks()
	extra_target_and_limit_checks()
	print("WOODLAND INDEPENDENT EDGES: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
func catalog_checks() -> void:
	check(Cards.decks().size() == 3,"three premade decks")
	var all_ids: Array = []
	for deck in Cards.decks():
		var ids: Array = Cards.deck_cards(deck.id)
		check(ids.size() == 20,"each deck has twenty cards")
		var counts: Dictionary = {}
		for id in ids:
			counts[id] = counts.get(id,0) + 1
			var card: Dictionary = Cards.card(id)
			check(not card.is_empty() and card.faction == deck.id,"deck card exists and belongs to faction")
			check(card.cost >= 0 and card.cost <= 6,"card fits mana curve")
		check(counts.size() == 10,"ten distinct cards per premade")
		for count in counts.values(): check(count == 2,"exactly two copies per card")
		all_ids.append_array(counts.keys())
	check(all_ids.size() == 30 and Cards.all_cards().size() == 30,"thirty non-token cards")
	var isolated: Dictionary = Cards.card("forest_squirrel")
	isolated.attack = 999
	check(Cards.card("forest_squirrel").attack == 2,"catalog caller cannot mutate shared definitions")
func mana_and_readiness() -> void:
	var state := fresh(["forest_squirrel","forest_bear"])
	state.players[0].mana = 1
	check(play(state).ok,"exact cost playable")
	check(state.players[0].mana == 0 and state.players[0].hand.size() == 1,"cost and card consumed once")
	check(not state.players[0].board[0].ready,"summoning sickness")
	var attacker: int = state.players[0].board[0].uid
	reject(state,{"type":"attack","attacker_uid":attacker,"target":{"player":1,"uid":0}},"new unit attack")
	reject(state,{"type":"play","hand_index":0},"insufficient cost")
	check(Rules.apply_action(state,{"type":"end_turn"}).ok,"end first turn")
	check(Rules.apply_action(state,{"type":"end_turn"}).ok,"end opposing turn")
	check(state.players[0].board[0].ready,"unit refreshes on own turn")
	check(Rules.apply_action(state,{"type":"attack","attacker_uid":attacker,"target":{"player":1,"uid":0}}).ok,"ready unit attacks")
	check(state.players[1].hp == 18 and state.players[0].board[0].hp == 1,"hero does not counterattack")
	reject(state,{"type":"attack","attacker_uid":attacker,"target":{"player":1,"uid":0}},"second attack")
	state = fresh(["sunlight"])
	check(play(state).ok and state.players[0].mana == 7 and state.players[0].max_mana == 6,"sunlight grants temporary mana above permanent cap")
	Rules.apply_action(state,{"type":"end_turn"}); Rules.apply_action(state,{"type":"end_turn"})
	check(state.players[0].mana == 6 and state.players[0].max_mana == 6,"temporary mana expires and cap remains six")
func target_and_guard_checks() -> void:
	var state := fresh(["forest_acorn","toy_spark","forest_growth"])
	state.players[0].board = [unit("forest_squirrel",101)]
	state.players[1].board = [unit("forest_hedgehog",201),unit("toy_rabbit",202)]
	for target in [{"player":1,"uid":0},{"player":0,"uid":101},{"player":1,"uid":999},{"player":5,"uid":201}]:
		reject(state,{"type":"play","hand_index":0,"target":target},"enemy-minion target restriction")
	for target in [{"player":1,"uid":0},{"player":1,"uid":202}]:
		reject(state,{"type":"attack","attacker_uid":101,"target":target},"guard redirects attack")
	check(play(state,1,{"player":1,"uid":0}).ok and state.players[1].hp == 17,"spell bypasses guard")
	check(play(state,0,{"player":1,"uid":202}).ok,"spell may target non-guard enemy")
	check(state.players[1].board.size() == 1,"lethal damage removes target")
	check(play(state,0,{"player":0,"uid":101}).ok,"friendly growth target accepted")
	check(state.players[0].board[0].attack == 4 and state.players[0].board[0].hp == 3 and state.players[0].board[0].max_hp == 3,"growth increases current and maximum health")
	check(Rules.apply_action(state,{"type":"attack","attacker_uid":101,"target":{"player":1,"uid":201}}).ok,"guard may be attacked")
	check(state.players[1].board.is_empty() and state.players[0].board[0].hp == 2,"unit combat deals simultaneous damage")
func capacity_and_effect_checks() -> void:
	var state := fresh(["spore_spitter"])
	check(play(state).ok and state.players[0].board.size() == 1,"targeted battlecry can be played with no enemy target")
	state = fresh(["toy_parts"])
	for i in 3: state.players[0].board.append(unit("forest_hedgehog",101+i))
	check(play(state).ok and state.players[0].board.size() == 4,"summon fills only final free slot")
	check(state.players[0].board[3].card_id == "token_part" and not state.players[0].board[3].ready,"summon uses specified token with sickness")
	state.players[0].hand = ["toy_parts","forest_squirrel"]
	reject(state,{"type":"play","hand_index":0},"summon spell on full board")
	reject(state,{"type":"play","hand_index":1},"minion on full board")
	state = fresh(["toy_reinforce"])
	reject(state,{"type":"play","hand_index":0},"pure all-friendly buff on empty board")
	state = fresh(["forest_stag"])
	state.players[0].hp = 19
	check(play(state).ok and state.players[0].hp == 20,"battlecry heal caps at twenty")
func death_checks() -> void:
	var state := fresh()
	state.players[0].hp = 1; state.players[1].hp = 1
	state.players[0].board = [unit("toy_box",101,1)]
	state.players[1].board = [unit("forest_squirrel",201)]
	check(Rules.apply_action(state,{"type":"attack","attacker_uid":101,"target":{"player":1,"uid":201}}).ok,"mutual-combat death resolves")
	check(state.winner == -1,"simultaneous hero death from deathrattle is draw")
	check(state.players[0].board.is_empty() and state.players[1].board.is_empty(),"dead units are removed")
	state = fresh()
	state.players[0].hp = 1; state.players[1].hp = 1
	state.players[0].board = [unit("toy_box",101,1),unit("forest_fox",102,1)]
	state.players[1].board = [unit("toy_box",201,1)]
	check(Rules.apply_action(state,{"type":"attack","attacker_uid":101,"target":{"player":1,"uid":201}}).ok,"two deathrattles plus healing death chain resolve")
	check(state.winner == 0 and state.players[0].hp == 1 and state.players[1].hp == -1,"later death healing resolves before terminal adjudication")
	state = fresh(["spore_mist"])
	state.players[1].board = [unit("spore_twin",201,1),unit("forest_squirrel",202),unit("forest_squirrel",203),unit("forest_squirrel",204)]
	check(play(state).ok,"simultaneous area deaths resolve")
	check(state.players[1].board.size() == 2,"all dead units removed before token deathrattle fills spaces")
	for remaining in state.players[1].board:
		check(remaining.card_id == "token_spore" and remaining.hp == 1 and not remaining.ready,"deathrattle creates living unready tokens")
func draw_and_fatigue_checks() -> void:
	var state := fresh(["forest_trail","forest_squirrel","forest_squirrel","forest_squirrel","forest_squirrel","forest_squirrel","forest_squirrel","forest_squirrel"])
	var deck_before: int = state.players[0].deck.size()
	check(play(state).ok,"draw at near full hand legal")
	check(state.players[0].hand.size() == 8 and state.players[0].deck.size() == deck_before-2,"draw burns overflow but consumes both deck cards")
	state = fresh()
	state.players[0].deck = []; state.players[1].deck = []
	for pair in range(3):
		Rules.apply_action(state,{"type":"end_turn"})
		Rules.apply_action(state,{"type":"end_turn"})
		var damage := (pair+1)*(pair+2)/2
		check(state.players[0].hp == 20-damage and state.players[1].hp == 20-damage,"fatigue escalates independently for both players")
		check(state.players[0].fatigue == pair+1 and state.players[1].fatigue == pair+1,"fatigue counter increments")
	state = fresh(["forest_trail"])
	state.players[0].deck = []; state.players[0].hp = 2
	check(play(state).ok and state.winner == 1 and state.players[0].hp == -1,"multiple empty draws apply escalating lethal fatigue")

func extra_target_and_limit_checks() -> void:
	var state := fresh(["forest_rally"])
	check(play(state).ok and state.players[1].hp == 18,"mixed buff/hero-damage spell remains useful on empty board")
	state = fresh(["spore_mist"])
	reject(state,{"type":"play","hand_index":0},"pure area damage on empty enemy board")
	state = fresh(["toy_repair"])
	check(play(state,0,{"player":0,"uid":0}).ok and state.players[0].hp == 20,"explicit full-health targeted healing may be wasted but never overheals")
	state = fresh(["spore_spitter"])
	state.players[1].board = [unit("forest_hedgehog",201)]
	reject(state,{"type":"play","hand_index":0},"targeted battlecry requires target when available")
	check(play(state,0,{"player":1,"uid":201}).ok and state.players[1].board[0].hp == 3,"battlecry applies to chosen existing enemy")
	state = fresh(["spore_elder"])
	state.players[0].board = [unit("forest_hedgehog",101,2)]
	check(play(state).ok,"other-friendly battlecry plays")
	check(state.players[0].board[0].attack == 2 and state.players[0].board[0].hp == 3 and state.players[0].board[0].max_hp == 5,"other-friendly growth preserves existing wound")
	check(state.players[0].board[1].attack == 4 and state.players[0].board[1].hp == 5,"elder does not buff itself")
	for health in [[10,10],[11,10],[10,11]]:
		state = fresh()
		state.turn = 60
		state.players[0].hp = health[0]; state.players[1].hp = health[1]
		var expected: int = -1 if health[0] == health[1] else (0 if health[0] > health[1] else 1)
		check(Rules.apply_action(state,{"type":"end_turn"}).ok and state.winner == expected,"turn-limit adjudication compares HP including draw")
		check(state.turn == 60 and state.finish_reason == "turn_limit","turn-limit outcome explains exact cap")
	state = fresh(["forest_trail"])
	state.players[0].deck = ["forest_bear","forest_owl","forest_squirrel"]
	check(play(state).ok and state.players[0].hand == ["forest_squirrel","forest_owl"],"draw consumes deterministic top-of-deck order")
	for event in state.last_events:
		if event.type == "draw":
			check(not event.has("card_id") and not event.text.contains("松鼠") and not event.text.contains("猫头鹰"),"draw events never reveal hidden drawn card identity")
