extends SceneTree
const Sim=preload("res://modules/fruit_gummy_snake/sim.gd")
var checks:=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:
 var total_eats:=0;var above:=0;var below:=0;var wins:=0
 for seed in [271,867,1909,421]:
  var s=Sim.new();s.start(seed);var meals:=0;var ledger:=0;var expected_length:=8;var target_id:=-1;var target_age:=0.0;var reason:="running";var blocked_id:=-1
  for step in 45000:
   if not s.alive:break
   target_age+=1.0/30
   if target_age>12:blocked_id=target_id;target_id=-1;target_age=0
   var target:Dictionary={}
   for f in s.foods:
    if f.id==target_id:target=f
   if target.is_empty():
    var best:=INF
    for f in s.foods:
     if f.id==blocked_id:continue
     var offset:Vector3=f.position-s.head
     var cost:float=offset.length()+8*(1-s.forward.dot(offset.normalized()))
     if cost<best:best=cost;target=f
    target_id=int(target.id)
   var delta:Vector3=target.position-s.head
   var avoid:=Vector3.ZERO
   var look:Vector3=s.head+s.forward*2.0
   for i in range(7,s.body.size()):
    var separation:Vector3=look-s.body[i]
    if separation.length()<2.0 and separation.length()>.001:avoid+=separation.normalized()*(2.0-separation.length())
   if avoid.length()>.01:delta=delta.normalized()*3.0+avoid*3.0
   var desired_yaw:float=-atan2(delta.x,-delta.z)
   var desired_pitch:float=atan2(delta.y,Vector2(delta.x,delta.z).length())
   var yaw_error:float=wrapf(desired_yaw-s.yaw,-PI,PI)
   s.set_controls(clampf(-yaw_error*2.0,-1,1),clampf((desired_pitch-s.pitch)*2.0,-1,1),-1)
   s.tick(1.0/30)
   for event in s.drain_events():
    if event.type=="eat":
     meals+=1;total_eats+=1;ledger+=int(event.points);expected_length+=2 if int(event.kind)>=3 else 1
     if s.head.y>12.5:above+=1
     if s.head.y<11.5:below+=1
    elif event.type=="salad":ledger+=30
    elif event.type=="result":reason=event.reason
   ck(s.trail.size()<=int(ceil((s.body.size()+4)*.55/(1.7/120)))+10,"arc history memory bounded by supported body length")
   ck(s.score==ledger,"3D contact score derives from events")
   ck(s.body.size()==mini(120,expected_length),"real consumed fruit extends body")
   for i in range(1,s.body.size()):
    var distance:float=s.body[i].distance_to(s.body[i-1])
    ck(distance>.48 and distance<=.551,"growing body remains spaced along path")
  if s.won:
   wins+=1
   var terminal:Dictionary=s.snapshot();s.tick(100.0)
   ck(s.snapshot()==terminal,"full growth victory is immutable")
  print("INDEPENDENT XYZ NORMAL NAVIGATION seed=",seed," eats=",meals," score=",s.score," length=",s.body.size()," elapsed=",s.elapsed," alive=",s.alive," won=",s.won," reason=",reason)
 ck(wins>=1,"ordinary unmodified simulation reaches full 120-segment victory")
 ck(total_eats>=12,"ordinary navigation collects multiple fruits without state injection")
 ck(above>0 and below>0,"ordinary contacts above and below start depth")
 print("INDEPENDENT UNDERWATER NAVIGATION: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
