extends RefCounted
## Shell-owned catalogue. A configured title is not playable until its entry scene
## loads, instantiates and implements the module interface. Modules never import this.
const GAMES := [
 {"id":"gummy_bomber","title":"软糖爆爆岛","enabled":true,"scene_path":"res://modules/gummy_bomber/main.tscn","color":Color("ff439c"),"description":"糖果迷宫 · 无限波次","category":"action","category_label":"动作"},
 {"id":"bloom_skirmish","title":"绒芽争园","enabled":true,"scene_path":"res://modules/bloom_skirmish/main.tscn","color":Color("23dcca"),"description":"2 对 2 花园争地 · 三分钟一局","category":"action","category_label":"动作"},
 {"id":"tide_gulp","title":"逐潮小鱼","enabled":true,"scene_path":"res://modules/tide_gulp/main.tscn","color":Color("9864ff"),"description":"水彩海洋 · 吞食成长","category":"relax","category_label":"休闲"},
 {"id":"beach_cleanup","title":"拾光海滩","enabled":true,"scene_path":"res://modules/beach_cleanup/main.tscn","color":Color("ffd36a"),"description":"驾驶清洁小车 · 让海滩重新闪亮","category":"relax","category_label":"休闲"},
 {"id":"volcano_escape","title":"火山岛逃生","enabled":true,"scene_path":"res://modules/volcano_escape/main.tscn","color":Color("e65d72"),"description":"寻找避难处 · 抓住撤离窗口","category":"adventure","category_label":"冒险"},
 {"id":"pelican_pedal","title":"鹈鹕顺风车","enabled":true,"scene_path":"res://modules/pelican_pedal/main.tscn","color":Color("ff9b62"),"description":"第一人称海滨骑行与配送","category":"adventure","category_label":"冒险"},
 {"id":"fruit_gummy_snake","title":"海底软糖水蛇","enabled":true,"scene_path":"res://modules/fruit_gummy_snake/main.tscn","color":Color("b5e278"),"description":"WASD 游动 · Space 上浮 · C 下潜","category":"relax","category_label":"休闲"},
 {"id":"monkey_vine","title":"猴子荡荡","enabled":true,"scene_path":"res://modules/monkey_vine/main.tscn","color":Color("73b85d"),"description":"2.5D 丛林冒险 · 抓藤摆荡 · 松手飞跃","category":"adventure","category_label":"冒险"},
 {"id":"dawn_sword","title":"晨曦之剑","enabled":true,"scene_path":"res://modules/dawn_sword/main.tscn","color":Color("f6c66d"),"description":"横版勇者冒险 · 探索与剑技","category":"adventure","category_label":"冒险"},
 {"id":"apprentice_yokai_king","title":"见习小妖王","enabled":true,"scene_path":"res://modules/apprentice_yokai_king/main.tscn","color":Color("9ad4bd"),"description":"大地图妖怪冒险 · 巨槌与流派","category":"action","category_label":"动作"}
]
var _availability: Dictionary = {}

func list_games() -> Array:
	var result: Array = []
	for definition in GAMES:
		var game: Dictionary = definition.duplicate(true)
		game.enabled = is_available(str(game.id))
		if bool(definition.enabled) and not game.enabled: game.status_label = "暂不可用"
		elif game.enabled: game.status_label = "开始游玩"
		result.append(game)
	return result

func find_game(id: String) -> Dictionary:
	for game in list_games():
		if game.id == id: return game
	return {}

func playable_games() -> Array:
	return list_games().filter(func(game: Dictionary): return game.enabled)

func is_available(id: String) -> bool:
	if _availability.has(id): return bool(_availability[id])
	var definition: Dictionary = {}
	for game in GAMES:
		if game.id == id: definition = game; break
	var valid := not definition.is_empty() and bool(definition.get("enabled",false))
	if valid:
		var path := str(definition.get("scene_path",""))
		valid = path == "res://modules/"+id+"/main.tscn" and ResourceLoader.exists(path)
		if valid:
			var scene := ResourceLoader.load(path) as PackedScene
			valid = scene != null and scene.can_instantiate()
			if valid:
				var candidate := scene.instantiate()
				valid = candidate != null and candidate.has_signal("exit_requested") and candidate.has_method("start")
				if candidate != null: candidate.free()
	_availability[id] = valid
	return valid

func mark_unavailable(id: String) -> void:
	_availability[id] = false
