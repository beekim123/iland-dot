extends SceneTree
const R=preload("res://modules/monkey_vine/rules/rules.gd")
const Env=preload("res://modules/monkey_vine/art/environment/jungle_environment.gd")
const Hud=preload("res://modules/monkey_vine/ui/jungle_hud.gd")
var checks=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok and not label in failures:failures.append(label);print("FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var env=Env.new();root.add_child(env)
 for i in range(4):
  var r=R.new();r.configure(1,i)
  var s=r.snapshot();env.build(s)
  var count=env.terrain.get_child_count()
  var key=["fern","fallbase","goldcanopy","ruinstone"][i]
  check(env.mats.has(key),"biome distinctive material "+str(i))
  check(env.current_segment==i,"correct biome rebuild")
  for frame in range(90):env.update_snapshot(s,1.0/60)
  check(env.terrain.get_child_count()==count,"biome no per-frame node leak")
  for v in s.vines:
   var tip=env.ropes[v.id].get_child(8)
   check(tip.position.distance_to(Vector3(v.tip.x,v.tip.y,.04))<.00001,"biome tip follows authority")
 var hud=Hud.new();root.add_child(hud)
 check("起跳" in hud.hint_label.text and "按住抓藤" in hud.hint_label.text and "松开" in hud.hint_label.text,"help explains jump hold release")
 var font=hud.hint_label.get_theme_font("font")
 for cp in "起跳按住抓藤松开微风丛林存档损坏":check(font.has_char(cp.unicode_at(0)),"Chinese glyph "+cp)
 env.queue_free();hud.queue_free()
 await process_frame
 print(JSON.stringify({"suite":"independent_biomes_help_font","checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
