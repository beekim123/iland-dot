extends SceneTree
const Sim=preload("res://modules/fruit_gummy_snake/sim.gd")
const Scene=preload("res://modules/fruit_gummy_snake/main.tscn")
func _initialize()->void:call_deferred("run")
func run()->void:
 var selected:=-1
 for seed in range(1000):
  var s=Sim.new();s.start(seed)
  for f in s.foods:
   if not f.intro and s.head.distance_to(f.position)<sqrt(16.16):selected=seed;break
  if selected>=0:break
 if selected<0:printerr("FAIL no normal seeded nearer-random-fruit case found");quit(1);return
 var game=Scene.instantiate();root.add_child(game);game.start({"seed":selected});game.set_process(false)
 await process_frame
 var initial_ok:bool=absf(float(game.hud.state.target_distance)-sqrt(16.16))<.0001 and absf(float(game.hud.state.target_height)-.4)<.0001
 game._process(4.0)
 var nearest:=INF
 for food in game.sim.foods:nearest=minf(nearest,game.sim.head.distance_to(food.position))
 var after_ok:bool=absf(float(game.hud.state.target_distance)-nearest)<.0001 and game.sim.collected[0]>=1
 game.leave_game();game.queue_free();await process_frame;await create_timer(.65).timeout
 if not initial_ok or not after_ok:printerr("FAIL intro targeting priority/fallback: ",initial_ok," / ",after_ok);quit(1);return
 print("INDEPENDENT UNDERWATER INTRO TARGET: normal seed=",selected," has nearer random fruit; HUD prioritizes intro then returns to nearest after actual contact")
 quit()
