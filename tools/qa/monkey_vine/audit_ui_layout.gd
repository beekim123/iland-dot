extends SceneTree
const HUD=preload("res://modules/monkey_vine/ui/jungle_hud.gd")
var checks=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok and not label in failures:failures.append(label);print("FAIL ",label)
func scan(node:Node,bounds:Rect2):
 if node is Button and node.is_visible_in_tree():
  check(bounds.encloses(node.get_global_rect()),"visible button inside viewport: "+node.text)
 for child in node.get_children():scan(child,bounds)
func _initialize():call_deferred("run")
func run():
 var hud=HUD.new();root.add_child(hud)
 for size in [Vector2i(640,360),Vector2i(1280,720),Vector2i(1920,1080)]:
  root.size=size
  root.content_scale_size=size
  await process_frame
  hud.set_paused(true)
  hud.show_status("存档损坏；已保留原文件，本次不会覆盖")
  await process_frame
  await process_frame
  var bounds=Rect2(Vector2.ZERO,Vector2(size))
  print("LAYOUT ",size," actual=",root.get_visible_rect()," modal=",hud.modal.get_global_rect()," status=",hud.status_label.get_global_rect())
  scan(hud,bounds)
  check(bounds.encloses(hud.modal.get_global_rect()),"modal fits "+str(size))
  check(bounds.encloses(hud.status_label.get_global_rect()),"warning fits "+str(size))
  check(not hud.status_label.get_global_rect().intersects(hud.modal.get_global_rect()),"warning does not cover modal "+str(size))
  for wind in [-.3,.3,0.0]:
   hud.update_snapshot({"wind_x":wind})
   check(("←" in hud.wind_label.text) if wind<0 else (("→" in hud.wind_label.text) if wind>0 else hud.wind_label.text.is_empty()),"wind direction display")
  hud.set_paused(false)
 root.remove_child(hud);hud.queue_free()
 await process_frame
 print(JSON.stringify({"suite":"independent_ui_layout","checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
