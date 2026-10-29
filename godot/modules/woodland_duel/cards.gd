extends RefCounted
## Original, fixed, freely available decks. All cards are runtime data, never progression.
const DECK_IDS := ["forest", "toys", "spores"]
const DECK_SIZE := 20
static var _catalog: Dictionary = {}

static func decks() -> Array[Dictionary]:
	return [
		{"id": "forest", "name": "林间野兽", "subtitle": "站稳脚跟 · 结伴成长", "description": "守护伙伴挡住进攻，用成长与疗愈建立稳健场面。", "color": Color("6d9465")},
		{"id": "toys", "name": "发条玩具", "subtitle": "火花碰撞 · 灵巧出击", "description": "用小巧玩具抢先出击，搭配定向火花与退场爆炸。", "color": Color("bc8457")},
		{"id": "spores", "name": "蘑菇精灵", "subtitle": "落地生根 · 生生不息", "description": "让退场伙伴留下新芽，以孢子、治疗和群体成长取胜。", "color": Color("a382b5")}
	]

static func _ensure_catalog() -> void:
	if _catalog.is_empty():
		for entry: Dictionary in _definitions():
			_catalog[entry.id] = entry

static func card(card_id: String) -> Dictionary:
	_ensure_catalog()
	return _catalog.get(card_id, {}).duplicate(true)

static func deck_cards(deck_id: String) -> Array[String]:
	var result: Array[String] = []
	_ensure_catalog()
	for entry: Dictionary in _catalog.values():
		if entry.faction == deck_id and not entry.get("token", false):
			result.append(entry.id)
			result.append(entry.id)
	return result

static func all_cards(include_tokens: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_ensure_catalog()
	for entry: Dictionary in _catalog.values():
		if include_tokens or not entry.get("token", false):
			result.append(entry.duplicate(true))
	return result

static func rules_text() -> String:
	return "双方 20 生命，20 张固定套牌，场上最多 4 名随从，手牌最多 8 张。\n先手 3 张牌；后手 4 张牌并获得「一缕晨光」。每个回合开始时抽 1 张牌（包含先手首回合）。\n每个自己的回合，最大费用 +1（最多 6），费用补满。未用费用不保留。晨光仅在当回合额外获得 1 费用。\n随从登场后须等到自己的下个回合，每回合攻击一次。攻击随从时双方同时造成攻击力伤害；攻击英雄不受反击。\n守护：敌方有守护随从时，随从只能攻击守护。法术与登场效果不受守护限制。\n登场：从手牌打出时触发。退场：死亡后触发。定向登场若无合法目标，仍可打出，效果略过。\n伤害同时结算，死亡随从批量离场，再按主动方、另一方的站位顺序触发退场；连锁处理完才判定胜负。\n手满时抽到的牌会被弃掉。空牌库每次抽牌受到递增的 1、2、3… 点疲劳伤害。\n召唤只填充空位；没有空位时不能打出召唤法术。恢复不超过生命上限，成长会同时增加当前与最大生命。\n英雄降到 0 生命则落败，同时降到 0 为平局。60 个回合（双方各 30 个）后，生命较高者胜，相同则平局。"

static func _unit(id: String, faction: String, title: String, cost: int, attack: int, hp: int, text: String = "", guard: bool = false, battlecry: Array = [], deathrattle: Array = [], target: String = "none", art_key: String = "") -> Dictionary:
	return {"id": id, "faction": faction, "name": title, "cost": cost, "type": "minion", "attack": attack, "hp": hp, "guard": guard, "text": text, "target": target, "battlecry": battlecry, "deathrattle": deathrattle, "effects": [], "art_key": id if art_key.is_empty() else art_key}

static func _spell(id: String, faction: String, title: String, cost: int, text: String, effects: Array, target: String = "none", art_key: String = "") -> Dictionary:
	return {"id": id, "faction": faction, "name": title, "cost": cost, "type": "spell", "attack": 0, "hp": 0, "guard": false, "text": text, "target": target, "battlecry": [], "deathrattle": [], "effects": effects, "art_key": faction.trim_suffix("s") + "_magic" if art_key.is_empty() else art_key}

static func _definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		_unit("forest_squirrel", "forest", "橡果松鼠", 1, 2, 1, "轻巧的林间先行者。"),
		_unit("forest_hedgehog", "forest", "苔帽刺猬", 2, 1, 4, "守护", true),
		_unit("forest_fox", "forest", "暖尾小狐", 2, 2, 2, "退场：为己方英雄恢复 2 点生命。", false, [], [{"kind": "heal_hero", "amount": 2}]),
		_unit("forest_owl", "forest", "邮差猫头鹰", 3, 2, 3, "登场：抽 1 张牌。", false, [{"kind": "draw", "amount": 1}]),
		_unit("forest_stag", "forest", "露角小鹿", 4, 3, 5, "登场：为己方英雄恢复 2 点生命。", false, [{"kind": "heal_hero", "amount": 2}]),
		_unit("forest_bear", "forest", "树屋大熊", 6, 5, 7, "守护", true, [], [], "none", "forest_bear"),
		_spell("forest_acorn", "forest", "橡果投掷", 1, "对一名敌方随从造成 2 点伤害。", [{"kind": "damage_target", "amount": 2}], "enemy_minion", "forest_magic"),
		_spell("forest_growth", "forest", "嫩叶祝福", 2, "使一名友方随从获得 +2/+2。", [{"kind": "buff_target", "attack": 2, "hp": 2}], "friendly_minion", "forest_magic"),
		_spell("forest_trail", "forest", "林间寻路", 2, "抽 2 张牌。", [{"kind": "draw", "amount": 2}], "none", "forest_magic"),
		_spell("forest_rally", "forest", "伙伴齐步", 4, "使所有友方随从获得 +1/+1，并对敌方英雄造成 2 点伤害。", [{"kind": "buff_all", "attack": 1, "hp": 1}, {"kind": "damage_enemy_hero", "amount": 2}], "none", "forest_magic"),
		_unit("toy_mouse", "toys", "发条小鼠", 1, 1, 2, "退场：对敌方英雄造成 1 点伤害。", false, [], [{"kind": "damage_enemy_hero", "amount": 1}]),
		_unit("toy_rabbit", "toys", "弹簧兔", 2, 3, 2),
		_unit("toy_bird", "toys", "火花啄木鸟", 3, 2, 3, "登场：对一个敌方目标造成 1 点伤害。", false, [{"kind": "damage_target", "amount": 1}], [], "enemy_character"),
		_unit("toy_bear", "toys", "铁皮小熊", 3, 3, 4, "守护", true),
		_unit("toy_box", "toys", "惊喜玩具盒", 4, 4, 3, "退场：对所有英雄和随从造成 1 点伤害。", false, [], [{"kind": "damage_all_characters", "amount": 1}], "none", "toy_box"),
		_unit("toy_golem", "toys", "积木巨人", 6, 6, 6, "守护", true),
		_spell("toy_spark", "toys", "齿轮火花", 2, "对一个敌方目标造成 3 点伤害。", [{"kind": "damage_target", "amount": 3}], "enemy_character", "toy_magic"),
		_spell("toy_repair", "toys", "暖心修补", 1, "为一个友方目标恢复 3 点生命。", [{"kind": "heal_target", "amount": 3}], "friendly_character", "toy_magic"),
		_spell("toy_reinforce", "toys", "拧紧螺丝", 3, "使所有友方随从获得 +1/+2。", [{"kind": "buff_all", "attack": 1, "hp": 2}], "none", "toy_magic"),
		_spell("toy_parts", "toys", "零件出动", 2, "在空位召唤至多两名 1/1 的小零件。", [{"kind": "summon", "card_id": "token_part", "count": 2}], "none", "toy_magic"),
		_unit("spore_sprout", "spores", "蘑菇芽", 1, 1, 1, "退场：召唤一名 1/1 的小孢子。", false, [], [{"kind": "summon", "card_id": "token_spore", "count": 1}]),
		_unit("spore_guard", "spores", "伞帽护卫", 2, 1, 4, "守护", true),
		_unit("spore_lantern", "spores", "灯笼菇", 3, 2, 3, "登场：为己方英雄恢复 3 点生命。", false, [{"kind": "heal_hero", "amount": 3}]),
		_unit("spore_spitter", "spores", "吐孢小菇", 3, 3, 3, "登场：对一名敌方随从造成 1 点伤害。", false, [{"kind": "damage_target", "amount": 1}], [], "enemy_minion", "spore_spitter"),
		_unit("spore_twin", "spores", "双生蘑菇", 4, 3, 3, "退场：在空位召唤至多两名 1/1 的小孢子。", false, [], [{"kind": "summon", "card_id": "token_spore", "count": 2}], "none", "spore_twin"),
		_unit("spore_elder", "spores", "花伞长老", 5, 4, 5, "登场：使其他友方随从获得 +1/+1。", false, [{"kind": "buff_all", "attack": 1, "hp": 1, "exclude_source": true}]),
		_spell("spore_mist", "spores", "孢子薄雾", 2, "对所有敌方随从造成 1 点伤害。", [{"kind": "damage_enemy_minions", "amount": 1}], "none", "spore_magic"),
		_spell("spore_nourish", "spores", "晨露茶", 2, "为己方英雄恢复 4 点生命，抽 1 张牌。", [{"kind": "heal_hero", "amount": 4}, {"kind": "draw", "amount": 1}], "none", "spore_magic"),
		_spell("spore_roots", "spores", "菌丝缠绕", 3, "对一名敌方随从造成 3 点伤害，为己方英雄恢复 2 点生命。", [{"kind": "damage_target", "amount": 3}, {"kind": "heal_hero", "amount": 2}], "enemy_minion", "spore_magic"),
		_spell("spore_bloom", "spores", "雨后新生", 4, "在空位召唤至多两名 2/2 的花菇。", [{"kind": "summon", "card_id": "token_bloom", "count": 2}], "none", "spore_magic")
	]
	var part := _unit("token_part", "neutral", "小零件", 1, 1, 1, "由零件出动召唤。", false, [], [], "none", "toy_mouse")
	part["token"] = true
	result.append(part)
	var spore := _unit("token_spore", "neutral", "小孢子", 1, 1, 1, "由伙伴的退场效果召唤。", false, [], [], "none", "spore_sprout")
	spore["token"] = true
	result.append(spore)
	var bloom := _unit("token_bloom", "neutral", "花菇", 2, 2, 2, "由雨后新生召唤。", false, [], [], "none", "spore_sprout")
	bloom["token"] = true
	result.append(bloom)
	var coin := _spell("sunlight", "neutral", "一缕晨光", 0, "仅在本回合获得 1 点额外费用，不增加最大费用。", [{"kind": "mana", "amount": 1}], "none", "forest_magic")
	coin["token"] = true
	result.append(coin)
	return result
