extends SceneTree
# Independent XYZ audit. Only public controls mutate gameplay. No manufactured body/food.
const Sim=preload("res://modules/fruit_gummy_snake/sim.gd")
var checks:=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func advance(s,seconds:float,frame:float)->void:
 var left:=seconds
 while left>0.00000001:
  var dt:=minf(left,frame);s.tick(dt);left-=dt
 # If implementation bounds work per frame, give its retained backlog time to drain.
 for i in 200:s.tick(0.0)
func _initialize()->void:
 var s=Sim.new();s.start(271)
 ck(typeof(s.head)==TYPE_VECTOR3 and typeof(s.forward)==TYPE_VECTOR3,"actual Vector3 state")
 var before:Dictionary=s.snapshot()
 for dt in [NAN,INF,-INF,-1.0]:s.tick(dt);ck(s.snapshot()==before,"invalid dt safe")
 for throttle in [-1.0,0.0,1.0]:
  var speed_sim=Sim.new();speed_sim.start(42);speed_sim.set_controls(0,0,throttle)
  var expected:float=1.7 if throttle<0 else (4.6 if throttle>0 else 3.9)
  ck(absf(float(speed_sim.snapshot().speed)-expected)<.00001,"HUD speed matches new S/normal/W contract")
  var p:Vector3=speed_sim.head;advance(speed_sim,1.0,1.0/120)
  ck(absf(p.distance_to(speed_sim.head)-expected)<.0001,"actual displacement matches new S/normal/W speed")
 var origin:Vector3=s.head
 s.set_controls(.6,.5,0.0);advance(s,2.0,1.0/60)
 var change:Vector3=s.head-origin
 ck(absf(change.x)>.1 and absf(change.y)>.1 and absf(change.z)>.1,"ordinary steering displaces all XYZ axes")
 ck(absf(s.forward.length()-1.0)<.0001,"heading normalized")
 ck(s.alive,"ordinary 2s swim survives")
 for frame in [1.0/30,1.0/60,1.0/144,1.0/3,1.0]:
  var a=Sim.new();var b=Sim.new();a.start(867);b.start(867)
  for control in [Vector3(.5,.3,0),Vector3(-.25,-.45,.5),Vector3(.2,.1,-.5)]:
   a.set_controls(control.x,control.y,control.z);b.set_controls(control.x,control.y,control.z)
   advance(a,1.0,1.0/120);advance(b,1.0,frame)
  ck(a.head.distance_to(b.head)<.002,"3D path dt consistent "+str(frame))
  ck(absf(a.elapsed-b.elapsed)<.0001,"no dropped elapsed "+str(frame))
  ck(a.alive==b.alive and a.score==b.score and a.body.size()==b.body.size(),"outcomes/growth dt consistent "+str(frame))
  ck(a.body.size()==b.body.size(),"same segment count")
  for i in mini(a.body.size(),b.body.size()):ck(a.body[i].distance_to(b.body[i])<.002,"arc history dt consistent")
 # Normal curve gives arc-length upper bound; short chord deficit is expected at bends.
 for i in range(1,s.body.size()):
  var d:float=s.body[i].distance_to(s.body[i-1])
  ck(d<=.551 and d>.50,"arc-spaced body follows curved trail")
 # Seed distribution and spawning invariants are tested without injected food positions.
 var min_y:=INF;var max_y:=-INF
 for seed in range(100):
  s.start(seed);ck(s.foods.size()==6,"six initial volumetric foods")
  for food in s.foods:
   var p:Vector3=food.position;min_y=minf(min_y,p.y);max_y=maxf(max_y,p.y)
   ck(absf(p.x)<=22 and absf(p.z)<=22 and p.y>=4 and p.y<=24,"food inside accessible volume")
   for q in s.body:ck(p.distance_to(q)>=1.6-.0001,"food clears body")
   for other in s.foods:
    if other.id!=food.id:ck(p.distance_to(other.position)>=2.0-.0001,"food separates in XYZ")
 ck(max_y-min_y>10,"seeded food has meaningful depth distribution")
 print("INDEPENDENT UNDERWATER KINEMATICS: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
