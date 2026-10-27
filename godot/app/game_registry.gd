extends RefCounted
## Only the shell knows the catalog. Modules never import this file.
const GAMES := [
 {"id":"gummy_bomber","title":"软糖爆爆岛","enabled":true,"scene_path":"res://modules/gummy_bomber/main.tscn","color":Color("ff439c"),"description":"糖果迷宫 · 无限波次"},
 {"id":"bloom_skirmish","title":"绒芽争园","enabled":true,"scene_path":"res://modules/bloom_skirmish/main.tscn","color":Color("23dcca"),"description":"2 对 2 花园争地 · 三分钟一局"},
 {"id":"tide_gulp","title":"逐潮小鱼","enabled":true,"scene_path":"res://modules/tide_gulp/main.tscn","color":Color("9864ff"),"description":"水彩海洋 · 吞食成长"},
 {"id":"cloud_hop","title":"云朵跳跳","enabled":false,"scene_path":"","color":Color("c9a3f2"),"description":"规划中 · 未开放"}
]
func list_games() -> Array:
 return GAMES.duplicate(true)
func find_game(id: String) -> Dictionary:
 for game in GAMES:
  if game.id == id: return game.duplicate(true)
 return {}
