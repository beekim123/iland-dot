extends RefCounted
## Shell-owned catalogue. A configured title is not playable until its entry scene
## loads, instantiates and implements the module interface. Modules never import this.
const GAMES := [
 {"id":"gummy_bomber","title":"软糖爆爆岛","enabled":true,"scene_path":"res://modules/gummy_bomber/main.tscn","color":Color("ff439c"),"description":"糖果迷宫 · 无限波次","category":"action","category_label":"动作"},
 {"id":"bloom_skirmish","title":"绒芽争园","enabled":true,"scene_path":"res://modules/bloom_skirmish/main.tscn","color":Color("23dcca"),"description":"2 对 2 花园争地 · 三分钟一局","category":"action","category_label":"动作"},
 {"id":"tide_gulp","title":"逐潮小鱼","enabled":true,"scene_path":"res://modules/tide_gulp/main.tscn","color":Color("9864ff"),"description":"水彩海洋 · 吞食成长","category":"relax","category_label":"休闲"},
 {"id":"beach_cleanup","title":"拾光海滩","enabled":true,"scene_path":"res://modules/beach_cleanup/main.tscn","color":Color("ffd36a"),"description":"驾驶清洁小车 · 让海滩重新闪亮","category":"relax","category_label":"休闲"},
 {"id":"volcano_escape","title":"火山岛逃生","enabled":true,"scene_path":"res://modules/volcano_escape/main.tscn","color":Color("e65d72"),"description":"寻找避难处 · 抓住撤离窗口","category":"adventure","category_label":"冒险"},
 {"id":"pelican_pedal","title":"鹈鹕顺风车","enabled":false,"scene_path":"","color":Color("ff9b62"),"description":"第一人称海滨骑行与配送","category":"adventure","category_label":"冒险","status_label":"重做中"},
 {"id":"fruit_gummy_snake","title":"果园长长蛇","enabled":false,"scene_path":"","color":Color("b5e278"),"description":"水果软糖 · 越吃越长","category":"relax","category_label":"休闲","status_label":"筹备中"}
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
