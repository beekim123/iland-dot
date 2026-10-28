extends SceneTree
const R = preload("res://modules/dawn_sword/scripts/rules.gd")
func _initialize():
 var r = R.new()
 var sections = {}
 var deaths = 0
 for frame in range(120*3600):
  sections[str(r.chapter)+":"+str(r.segment)] = true
  if r.mode == "dead":
   deaths += 1
   if deaths > 12: break
   r.retry()
  var input = {"move":1.0,"interact_pressed":frame%6==0,"jump":true}
  var foe = {}
  var distance = INF
  for e in r.enemies:
   if e.hp > 0 and absf(e.x-r.hero.x) < distance:
    foe = e
    distance = absf(e.x-r.hero.x)
  if not foe.is_empty() and distance < 200:
   input.move = signf(foe.x-r.hero.x)
   if distance < 90:
    input.attack_pressed = frame%16==0
    if foe.state == "windup" and foe.timer < 0.2: input.roll_pressed = true
   if r.hero.grounded and r.hero.y < foe.y-70:
    input.down = true
    input.jump_pressed = true
   if foe.kind in ["shield","bridge_guard"] and frame%50==0: input.jump_pressed = true
   if r.flags.dawn and distance < 140: input.dawn_pressed = frame%24==0
  if r.hero.hp < 55 and r.hero.heals > 0: input.heal_pressed = true
  for hazard in r.level.hazards:
   if r.hero.x > hazard.x-70 and r.hero.x < hazard.x+hazard.w and r.hero.grounded:
    input.move = 1.0
    input.jump_pressed = true
    input.down = false
  if r.hero.x > r.level.exit_x-100:
   input.interact_pressed = true
   if r.chapter == 4 and r.segment == 1: input.dawn_pressed = true
  r.tick(input)
  if r.mode == "ending":
   assert(sections.size() == 20 and r.flags.rescued and r.flags.completed and r.flags.princess_safe)
   print("INPUT_ONLY Dawn ending sections=",sections.size()," simulated_seconds=",frame*R.STEP," deaths=",deaths)
   quit(0)
   return
 print("INCONCLUSIVE independent Dawn policy did not finish; chapter=",r.chapter," segment=",r.segment," deaths=",deaths)
 quit(2)
