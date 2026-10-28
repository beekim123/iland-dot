extends SceneTree
const Rules = preload("res://modules/monkey_vine/rules/rules.gd")
const H = 1.0/120.0
var checks = 0
var failures: Array = []
func check(ok: bool, label: String):
 checks += 1
 if not ok and not label in failures:
  failures.append(label)
  print("FAIL ",label)
func _initialize():
 for seed_value in [1,271828,-19]:
  for segment in range(4):
   for release_offset in [.55,.65,.75]:
    route(seed_value,segment,release_offset)
 timing()
 print(JSON.stringify({"suite":"independent_rules","checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
func route(seed_value: int, segment: int, release_offset: float):
 var r = Rules.new()
 r.configure(seed_value,segment)
 var held = false
 var grabs = {}
 var landed = {}
 var cleared = false
 var max_x = 0.0
 for tick in range(1800):
  var old = r.snapshot()
  var next = held
  if old.grounded: next = not held and old.player_pos.x > (1.0 if old.player_pos.x < 11 else 15.0)
  elif old.vine_id != "":
   for vine in old.vines:
    if vine.id == old.vine_id: next = not (old.player_pos.x > vine.anchor.x+release_offset and old.player_vel.x>0)
  else: next = true
  var s = r.step(H,{"right":true,"left":false,"grab_held":next,"grab_pressed":next and not held,"grab_released":held and not next})
  held = next
  check(absf(float(s.get("wind_x",NAN))-(.35*sin(s.time*1.5) if segment==3 else 0.0))<.000001,"wind cue matches actual force")
  max_x=maxf(max_x,s.player_pos.x)
  check(s.player_pos.is_finite() and s.player_vel.is_finite(),"finite state")
  check(s.player_vel.length() <= 8.001,"speed bounded")
  var reset = false
  for e in s.events:
   if e.type in ["restart","segment_start"]: reset=true
   if e.type == "grab":
    grabs[e.id]=true
    for v in s.vines:
     if v.id == e.id:
      var unheld_tip: Vector2 = v.anchor + Vector2(0,-v.length)
      check(s.grip_pos.distance_to(unheld_tip)<=.35001,"true grab radius")
   if e.type == "land": landed[s.checkpoint]=true
   if e.type == "segment_clear": cleared=true
   check(e.type != "fail","normal route fail seed=%s segment=%s release=%s"%[seed_value,segment,release_offset])
  if not reset:
   check(s.player_pos.distance_to(old.player_pos)<=.10,"no teleport ordinary trajectory")
  if s.vine_id != "":
   for v in s.vines:
    if v.id == s.vine_id: check(absf(s.grip_pos.distance_to(v.anchor)-s.rope_length)<.0001,"rope length invariant")
  for p in s.platforms:
   check(not p.rect.grow(.3199).has_point(s.player_pos),"solid platform penetration")
  if cleared: break
 check(cleared,"route completes seed=%s segment=%s release=%s x=%s"%[seed_value,segment,release_offset,max_x])
 check(grabs.size()>=6,"route uses all six vines")
 check(landed.size()>=1,"route lands normally")
func timing():
 for dt in [1.0/240,1.0/120,1.0/60,.5,2.0]:
  var r = Rules.new()
  r.configure(1)
  var n = int(round(2.0/dt))
  for i in range(n): r.step(dt,{})
  check(absf(r.snapshot().time-2.0)<.00001,"time conservation dt="+str(dt))
 for dt in [0.0,-1.0,INF,NAN]:
  var r=Rules.new()
  r.configure(1)
  var old=r.snapshot()
  r.step(dt,{"grab_pressed":true,"grab_held":true})
  check(r.snapshot()==old,"invalid dt no mutation")
