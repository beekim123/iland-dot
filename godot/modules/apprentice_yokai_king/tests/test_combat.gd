extends SceneTree
## Isolated rule fixtures, not a real-input clear or playthrough claim.
## Fixtures intentionally construct combat states to exercise invariants.
const Model = preload("res://modules/apprentice_yokai_king/run_model.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String):
 checks += 1
 if not ok:
  failures.append(label)
  printerr("FAIL: "+label)

func fixture():
 var m = Model.new()
 m.reset(947, "standard", false)
 m.phase = "combat"
 m.pending = [{"kind":"grunt", "at":1000.0,"pos":Vector2(90,190)}]
 return m

func _initialize():
 test_rates()
 test_input_and_pause()
 test_damage()
 test_budget_and_choice()
 test_spatial_chain()
 print("AYK isolated combat rules: %d checks, %d failures (not gameplay-clear evidence)" % [checks,failures.size()])
 quit(0 if failures.is_empty() else 1)

func test_rates():
 var snapshots: Array[String] = []
 for hz in [30,60,120]:
  var m = Model.new()
  m.reset(775,"standard",false)
  for i in range(hz*12):
   var input := {"move":Vector2.RIGHT if i < hz*6 else Vector2.LEFT,"aim":Vector2.LEFT}
   if i == hz*4: input.press = true
   if i == hz*4+int(hz*0.8): input.release = true
   if i == hz*7: input.dodge = true
   m.advance(1.0/hz,input)
  snapshots.append(var_to_str([m.player,m.enemies,m.hp,m.phase,m.wave,m.spawned,m.attack_id,m.core_triggers,m.pending,m.rng.state]))
 check(snapshots[0] == snapshots[1] and snapshots[1] == snapshots[2], "30/60/120 Hz deterministic fixed-step results")
 var waiting = Model.new()
 waiting.reset(88,"standard",false)
 waiting.invulnerable = 1000 # Deadline isolation; not a survival/playability claim.
 for i in range(126*30): waiting.advance(1.0/30.0,{})
 check(waiting.phase == "lost" and waiting.wave == 1 and waiting.result_reason == "本波时间用尽", "without attacks cannot progress; explicit deadline loses")
 check(waiting.attack_id == 0 and waiting.defeated == 0 and waiting.spawned == 20, "no auto attack and finite first wave budget")

func test_input_and_pause():
 var m = fixture()
 m.advance(0.1,{"press":true})
 check(m.charge > 0 and m.attack_id == 0, "holding does not auto fire")
 for i in range(8): m.advance(0.1,{})
 check(m.charge >= 0.75 and m.attack_id == 0, "full charge still requires release")
 m.advance(1.0/120,{"dodge":true,"release":true})
 check(m.charge < 0 and m.attack_id == 0 and m.dodge_time > 0, "dodge cancels charge without free release attack")
 var previous := var_to_str([m.player,m.enemies,m.wave_time,m.cooldown,m.dodge_cd,m.invulnerable,m.accumulator])
 m.phase = "paused"
 for i in range(50): m.advance(0.1,{"press":true,"release":true,"dodge":true,"move":Vector2.ONE})
 check(previous == var_to_str([m.player,m.enemies,m.wave_time,m.cooldown,m.dodge_cd,m.invulnerable,m.accumulator]), "pause freezes complete simulation")
 m.phase = "combat"
 m.advance(1.0/120,{})
 check(m.attack_id == 0 and m.wave_time < 1.0, "resume does not replay paused edges or elapsed wall time")
 m = fixture()
 m.advance(1.0/120,{"press":true,"release":true})
 check(m.attack_id == 1 and not m.attack.heavy, "same-frame click makes one light swing")
 m = fixture()
 m.perform_attack(0.449)
 check(not m.attack.heavy, "below .45 seconds remains light")
 m.perform_attack(0.45)
 check(m.attack.heavy and not m.attack.full, ".45 seconds enters partial heavy")
 m.perform_attack(0.75)
 check(m.attack.full, ".75 seconds reaches full heavy")

func test_damage():
 var m = fixture()
 m.spawn_enemy("grunt",m.player+Vector2(90,0))
 m.enemies[0].hp = 50.0
 m.perform_attack(0.0)
 for i in range(30): m.advance(1.0/120,{})
 check(m.enemies[0].hp == 49.0, "attack active window never repeats direct damage")
 check(m.attack_id == 1 and m.hit_chain == 1, "unique attack ID and one hit chain increment")
 m.damage_player(); m.damage_player(); m.damage_player()
 check(m.hp == 4, "same-step incoming damage deducts only one heart")
 m.invulnerable = 0; m.shield = true
 m.damage_player(); m.damage_player()
 check(m.hp == 4 and not m.shield and m.invulnerable == 1.0, "one-use shield and non-stacked protection")
 m = fixture()
 m.spawn_enemy("grunt",Vector2(500,400))
 for i in range(5): m.spawn_enemy("grunt",Vector2(503+i,400))
 m.enemies[0].vel = Vector2(100,0); m.enemies[0].launch = 42
 m.build.choose("ayk_core_thunder")
 for i in range(5): m.step_enemy(m.enemies[0],1.0/120)
 var targets_hit := 0
 for i in range(1,6):
  if m.enemies[i].hp < 3.0: targets_hit += 1
  check(m.enemies[i].launch == 0, "collision does not relaunch target")
 check(targets_hit == 3 and m.enemies[0].collided.size() == 3, "launch collision hard cap three distinct targets")
 check(m.core_triggers == 0 and m.effects.is_empty(), "collision does not recursively trigger core")
 m = fixture()
 for i in range(8): m.spawn_enemy("grunt",m.player+Vector2(70+i,0))
 m.build.choose("ayk_core_thunder")
 m.trigger_core(m.player+Vector2(62,0),Vector2.RIGHT)
 var effect: Dictionary = m.effects[0]
 m.resolve_secondary(effect)
 targets_hit = 0
 for enemy in m.enemies:
  if enemy.hp < 3: targets_hit += 1
 check(targets_hit == 3 and m.core_triggers == 1 and m.effects.size() == 1, "thunder cap and secondary non-recursion")
 m = fixture()
 m.spawn_enemy("shield",m.player+Vector2(70,0))
 m.perform_attack(0.75); m.resolve_attack()
 check(m.enemies[0].hp < 5 and m.enemies[0].hp > 4, "front shield mitigates without immunity")
 m = fixture()
 m.spawn_enemy("boss",m.player+Vector2(80,0))
 for i in range(3): m.perform_attack(0.75); m.resolve_attack()
 check(m.enemies[0].state == "stunned" and m.enemies[0].vel == Vector2.ZERO, "boss stagger without launch")
 var resistance: float = m.enemies[0].resist
 for i in range(5): m.perform_attack(0.75); m.resolve_attack()
 check(m.enemies[0].stagger == 0 and m.enemies[0].resist == resistance, "stagger resistance prevents permanent stun chain")
 m = fixture()
 m.wave = 6; m.hp = 1
 m.spawn_enemy("boss",m.player+Vector2(80,0)); m.enemies[0].hp = 0
 m.projectiles.append({"pos":m.player,"vel":Vector2.ZERO,"life":1.0})
 m.advance(1.0/120,{})
 check(m.phase == "lost", "same-step player zero takes precedence over boss zero")
 var result_events: int = m.events.count("result")
 m.finish(true,"invalid repeated outcome")
 check(m.phase == "lost" and m.events.count("result") == result_events, "terminal settlement exactly once")

func test_budget_and_choice():
 var totals := [20,26,25,31,44,1]
 for index in range(6):
  var m = Model.new()
  m.reset(10,"standard",false)
  m.wave = index
  m.begin_wave()
  check(m.wave == index+1 and m.total == totals[index] and m.pending.size()+m.reserved_summons == totals[index], "wave %d finite hand-authored budget" % (index+1))
 var model = fixture()
 model.pending = [{"kind":"grunt","at":30.0,"pos":Vector2(90,190)}]
 model.advance(0.1,{})
 check(model.phase == "combat", "temporarily empty arena cannot clear while pending remains")
 model.pending = [{"kind":"grunt","at":0.0,"pos":model.player}]
 model.advance(0.1,{})
 check(model.enemies.is_empty() and model.pending.size() == 1, "unsafe spawn postponed instead of appearing beside player")
 model = fixture()
 model.pending.clear(); model.total = 1
 model.spawn_enemy("boss",Vector2(1000,600))
 model.enemies[0].hp = 20.0 # Cross both reinforcement thresholds in one isolated fixture.
 for i in range(1000): model.step_enemy(model.enemies[0],1.0/120)
 check(model.boss_reinforcements == 2 and model.pending.size() == 12 and model.total == 13, "crossed boss thresholds each spawn six only once")
 var again_count: int = model.pending.size()
 for i in range(1000): model.step_enemy(model.enemies[0],1.0/120)
 check(model.pending.size() == again_count, "boss cannot replenish reinforcement budget indefinitely")
 model = fixture()
 for round_index in range(5):
  model.phase = "combat"; model.pending.clear(); model.enemies.clear()
  model.advance(1.0/120,{})
  check(model.phase == "choice" and model.build.chosen_count == round_index, "cleared fixture enters mandatory upgrade %d" % (round_index+1))
  var card: String = model.build.offers()[0]
  check(model.select_card(card) and model.phase == "countdown" and model.wave == round_index+2, "upgrade explicitly starts next wave countdown")
 check(model.wave == 6 and model.build.chosen_count == 5, "all five upgrade phases before final wave")
 var assist = Model.new()
 assist.reset(10,"assist",false)
 check(assist.limit() == 180, "assist standard-wave deadline +50 percent")
 assist.wave = 6
 check(assist.limit() == 270, "assist boss deadline +50 percent")

func test_spatial_chain():
 var m = fixture()
 var center = Vector2(300,400)
 for x in [380,490,600,710]: m.spawn_enemy("grunt",Vector2(x,400))
 var effect = {"kind":"ayk_core_thunder","pos":center,"direction":Vector2.RIGHT,"radius":115.0,"cap":5,"damage":1.0}
 m.resolve_secondary(effect)
 check(m.enemies[0].hp == 2 and m.enemies[1].hp == 2 and m.enemies[2].hp == 2, "thunder chain reaches two unique neighbors outside original circle")
 check(m.enemies[3].hp == 3 and m.core_triggers == 0, "chain stops after two extras and never recursively triggers core")
