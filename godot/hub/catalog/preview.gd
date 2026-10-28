extends Control
const Catalog=preload("game_catalog.gd")
func _ready()->void:
 var c:=Catalog.new();add_child(c)
 var registry=preload("res://app/game_registry.gd").new()
 var games:Array=registry.list_games()
 var ids:Array=[]
 for g in games:ids.append(g.id)
 for item in [{"id":"beach_cleanup","title":"拾光海滩","enabled":true,"scene_path":"res://modules/beach_cleanup/main.tscn","color":Color("e6b95d"),"description":"驾驶小车 · 收集海滩垃圾"},{"id":"volcano_escape","title":"火山岛逃生","enabled":true,"scene_path":"res://modules/volcano_escape/main.tscn","color":Color("ed785d"),"description":"观察预警 · 寻找安全撤离路线"},{"id":"pelican_pedal","title":"鹈鹕顺风车","enabled":false,"scene_path":"","description":"第一人称骑车 · 海滨配送","status_label":"重做中"},{"id":"fruit_gummy_snake","title":"果园长长蛇","enabled":false,"scene_path":"","description":"水果软糖 · 越吃越长","status_label":"筹备中"}]:
  if item.id not in ids:games.append(item)
 games=games.filter(func(g):return g.id!="cloud_hop")
 c.set_games(games);c.set_portal_games(["gummy_bomber","tide_gulp","beach_cleanup","volcano_escape"]);c.open_catalog()
 c.game_requested.connect(func(id):c.set_status("预览模式：已选择 "+id+"，正式游戏由海岛路由启动。"))
 c.close_requested.connect(func():get_tree().quit())
