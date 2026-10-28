extends SceneTree
const Sim=preload("res://modules/fruit_gummy_snake/sim.gd")
var checks:=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:
 var a=Sim.new();var b=Sim.new();a.start(271);b.start(271)
 var target_id:=-1;var eats:=0
 for frame in 9000:
  if not a.alive or eats>=10:break
  var target:Dictionary={}
  for f in a.foods:
   if f.id==target_id:target=f
  if target.is_empty():
   var best:=INF
   for f in a.foods:
    var d:Vector3=f.position-a.head
    var cost:float=d.length()+8*(1-a.forward.dot(d.normalized()))
    if cost<best:best=cost;target=f
   target_id=int(target.id)
  var offset:Vector3=target.position-a.head
  var desired_yaw:float=-atan2(offset.x,-offset.z)
  var desired_pitch:float=atan2(offset.y,Vector2(offset.x,offset.z).length())
  var yaw_error:float=wrapf(desired_yaw-a.yaw,-PI,PI)
  var yaw_control:=clampf(-yaw_error*2,-1,1);var pitch_control:=clampf((desired_pitch-a.pitch)*2,-1,1)
  a.set_controls(yaw_control,pitch_control,-1);b.set_controls(yaw_control,pitch_control,-1)
  a.tick(1.0/30)
  for i in 4:b.tick(1.0/120)
  var events:Array=a.drain_events();var replay:Array=b.drain_events()
  for event in events:
   if event.type=="eat":eats+=1
  ck(events==replay,"same timestamped controls produce identical contact events")
  ck(a.head.distance_to(b.head)<.0001 and a.body==b.body,"live growth replay body matches across frame subdivision")
  ck(a.foods==b.foods and a.score==b.score,"spawn RNG and score replay match after eating")
 ck(eats>=10,"ordinary replay really exercised ten fruit contacts")
 print("INDEPENDENT UNDERWATER REPLAY GROWTH: ",checks," checks; ",failures.size()," failures; eats=",eats)
 quit(0 if failures.is_empty() else 1)
