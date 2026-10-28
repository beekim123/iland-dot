extends SceneTree
const Model = preload("res://modules/apprentice_yokai_king/run_model.gd")
func _initialize():
 var failed = false
 for route in ["wind","thunder","quake"]:
  var m = Model.new()
  m.reset(782113,"standard",false)
  var max_alive = 0
  var frames = 0
  var max_wave_spawned = 0
  while frames < 120*1000 and m.phase not in ["won","lost"]:
   frames += 1
   max_alive = maxi(max_alive,m.enemies.size())
   max_wave_spawned = maxi(max_wave_spawned,m.spawned)
   if m.phase == "choice":
    var cards = m.build.offers()
    var picked = "ayk_core_"+route if m.build.core == "" else cards[0]
    if "ayk_fast" in cards: picked = "ayk_fast"
    assert(m.select_card(picked))
    assert(not m.select_card(picked))
   var input = {}
   var closest = {}
   var distance = INF
   for e in m.enemies:
    if e.hp > 0 and m.player.distance_to(e.pos) < distance:
     closest = e
     distance = m.player.distance_to(e.pos)
   if not closest.is_empty():
    var toward = (closest.pos-m.player).normalized()
    input.aim = toward
    input.move = toward if distance > 106 else Vector2.ZERO
    if m.cooldown > 0 and distance < 150: input.move = -toward
    if closest.kind == "shield": input.move = toward.rotated(PI/2) if distance < 130 else toward
    if m.charge < 0 and m.cooldown <= 0: input.press = true
    if m.charge >= 0.8 and distance <= 132: input.release = true
    var danger = false
    for e in m.enemies:
     if e.state == "slide" and e.pos.distance_to(m.player) < 160: danger = true
     if e.state == "windup" and e.timer < 0.15:
      if e.kind in ["spring","sleeper"] and e.target.distance_to(m.player) < 90: danger = true
      elif e.kind == "boss" and e.move%3 == 2 and absf(e.pos.distance_to(m.player)-(90+e.rings*65)) < 40: danger = true
      elif e.pos.distance_to(m.player)<(180 if e.kind == "boss" else 110): danger = true
    if danger and m.dodge_cd <= 0:
     input.dodge = true
     input.move = -toward
   m.advance(1.0/120,input)
  print("INPUT_ONLY route=",route," phase=",m.phase," wave=",m.wave," elapsed=",m.elapsed," hp=",m.hp," choices=",m.build.chosen_count," max_alive=",max_alive," max_wave_spawned=",max_wave_spawned," reason=",m.result_reason)
  if m.phase != "won": failed = true
 quit(1 if failed else 0)
