extends SceneTree
const R=preload("res://modules/monkey_vine/rules/rules.gd")
var checks=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok and not label in failures:failures.append(label);print("FAIL ",label)
func _initialize():
 for template in [1,2]:
  var data=JSON.parse_string(FileAccess.get_file_as_string("res://modules/monkey_vine/data/bonus_witness_%d.json"%template))
  var r=R.new();r.configure(int(data.seed),int(data.segment))
  var held=false
  var air_release=-1
  var target_grab=false
  var golden=false
  var warned=-1
  var released=-1
  var min_gap=999
  for tick in range(data.inputs.size()):
   var input=data.inputs[tick]
   var old=r.snapshot()
   check(input.grab_pressed==(input.grab_held and not held),"witness honest press edge")
   check(input.grab_released==(held and not input.grab_held),"witness honest release edge")
   if input.grab_released and not old.grounded:air_release=tick
   if input.grab_pressed and air_release>=0:
    min_gap=mini(min_gap,tick-air_release)
    check(tick-air_release>=10,"air release minimum83ms")
    air_release=-1
   held=input.grab_held
   var s=r.step(1.0/120,input)
   check(s.player_pos.distance_to(old.player_pos)<.10,"bonus no teleport")
   for e in s.events:
    check(e.type not in ["fail","restart","vine_break"],"bonus no failure/restart/break")
    if e.type=="grab":
     for v in s.vines:
      if v.id==e.id:check(s.grip_pos.distance_to(v.anchor+Vector2(0,-v.length))<=.35001,"bonus legal grab range")
     if e.id==("bonus_moving" if template==1 else "bonus_fragile"):target_grab=true
    if e.type=="collect" and e.id=="golden":golden=true
    if e.type=="break_warning":warned=tick
    if e.type=="release" and e.id=="bonus_fragile":released=tick
  var final=r.snapshot()
  check(target_grab,"reaches optional vine")
  check(final.grounded and final.checkpoint==("rest" if template==1 else "exit"),"bonus real safe landing")
  if template==1:check(golden,"golden collected normally")
  else:
   check(final.phase=="segment_clear","fragile route completes stage")
   check(warned>=0 and released>warned,"warning precedes deliberate release")
   check((released-warned)/120.0>=.35 and (released-warned)/120.0<1.2,"visible warning and safe release window")
  print("BONUS_SUMMARY ",JSON.stringify({"template":template,"frames":data.inputs.size(),"min_air_release_ticks":min_gap,"warning":warned,"release":released,"checkpoint":final.checkpoint}))
 print(JSON.stringify({"suite":"independent_bonus","checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
