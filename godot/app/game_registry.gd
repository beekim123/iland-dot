extends RefCounted
## Only the shell knows the catalog. Modules never import this file.
const GAMES := [
 {"id":"gummy_bomber","title":"软糖爆爆岛","enabled":true,"scene_path":"res://modules/gummy_bomber/main.tscn","color":Color("ff439c"),"description":"糖果迷宫 · 无限波次"},
 {"id":"bloom_skirmish","title":"绒芽争园","enabled":true,"scene_path":"res://modules/bloom_skirmish/main.tscn","color":Color("23dcca"),"description":"2 对 2 花园争地 · 三分钟一局"},
 {"id":"reef_memory","title":"珊瑚记忆","enabled":false,"scene_path":"","color":Color("9864ff"),"description":"规划中 · 未开放"},
 {"id":"cloud_hop","title":"云朵跳跳","enabled":false,"scene_path":"","color":Color("c9a3f2"),"description":"规划中 · 未开放"}
]
func list_games() -> Array:
 return GAMES.duplicate(true)
func find_game(id: String) -> Dictionary:
 for game in GAMES:
  if game.id == id: return game.duplicate(true)
 return {}
