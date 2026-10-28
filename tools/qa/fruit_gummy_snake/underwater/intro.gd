extends SceneTree
const Sim=preload("res://modules/fruit_gummy_snake/sim.gd")
var checks:=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:
 for seed in range(40):
  var s=Sim.new();s.start(seed);var intro_count:=0
  for f in s.foods:
   if f.get("intro",false):
    intro_count+=1
    ck(f.kind==0 and f.id==1 and f.expires<0,"one ordinary persistent introductory apple")
    ck(f.position.distance_to(s.head+s.forward*4+Vector3.UP*.4)<.0001,"intro position matches public start rule")
  ck(intro_count==1 and s.foods.size()==6,"intro replaces one slot, not extra resource")
  var contacts:=0
  for i in 120:
   s.tick(1.0/120)
   for event in s.drain_events():
    if event.type=="eat":
     contacts+=1
     ck(event.kind==0 and event.points==10,"normal swept contact emits actual apple reward")
  ck(contacts==1 and s.score==10 and s.body.size()==9,"ordinary forward swim eats apple and grows, no injected success")
  for f in s.foods:ck(not f.get("intro",false) and f.id!=1,"replacement food never repeats intro")
  # Continue ordinary movement; no public restart means no second intro.
  s.set_controls(.7,.15,-1)
  for i in 240:s.tick(1.0/120)
  for f in s.foods:ck(not f.get("intro",false),"intro stays absent after subsequent swimming")
 print("INDEPENDENT UNDERWATER INTRO: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
