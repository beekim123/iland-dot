extends SceneTree
const Sim=preload("res://modules/pelican_pedal/sim.gd")
const Map=preload("res://modules/pelican_pedal/data/map.gd")
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok: failures.append(label);printerr("FAIL ",label)
func inside_raw(p:Vector2)->bool:
 if not p.is_finite() or absf(p.x)>36.52001 or absf(p.y)>36.52001:return false
 # Independent expanded obstacle signed-distance check, not Map.clear as oracle.
 for origin in [Vector2(-19,-19),Vector2(5,-19),Vector2(-19,5),Vector2(5,5)]:
  var d=(p-(origin+Vector2(7,7))).abs()-Vector2(7,7)
  var outside=Vector2(maxf(d.x,0),maxf(d.y,0)).length()+minf(maxf(d.x,d.y),0)
  if outside<.47999:return false
 return true
func road_route(start:Vector2,finish:Vector2)->Array[Vector2]:
 # Hand-authored grid intersections and independent shortest-path BFS.
 var n:Array[Vector2]=[]
 for z in [-24.0,0.0,24.0]:
  for x in [-24.0,0.0,24.0]:n.append(Vector2(x,z))
 var a:=0;var b:=0
 for i in 9:
  if start.distance_squared_to(n[i])<start.distance_squared_to(n[a]):a=i
  if finish.distance_squared_to(n[i])<finish.distance_squared_to(n[b]):b=i
 var q:Array[int]=[a];var seen:Dictionary={a:-1}
 while not q.is_empty():
  var u:int=q.pop_front()
  for v in 9:
   if seen.has(v):continue
   if abs(n[u].x-n[v].x)+abs(n[u].y-n[v].y)==24:seen[v]=u;q.append(v)
 var result:Array[Vector2]=[];var cursor:int=b
 while cursor!=-1:result.push_front(n[cursor]);cursor=seen[cursor]
 return result
func _initialize()->void:
 for job in 8:
  for step in [1.0/30.0,0.2]:drive(job,step)
 for dt in [NAN,INF,-INF,-1.0,0.0]:
  var s=Sim.new();s.start();var before=s.snapshot();s.command({"throttle":1.0});s.tick(dt)
  check(s.snapshot()==before,"invalid dt cannot advance authoritative state")
 var r=Sim.new();r.start();r.command({"interact":true});r.tick(.1)
 check(r.phase=="pickup","E from spawn outside 2.5m cannot pick up")
 for i in 10000:
  if r.phase=="failed":break
  r.command({"throttle":1.0,"steer":sin(i*.03)});var old:Vector2=r.pos;r.tick(.2)
  check(inside_raw(r.pos),"high-speed steering cannot enter raw building or leave bounds")
  check(r.pos.distance_to(old)<=8.5*.2+.001,"movement obeys speed bound")
 check(r.collisions>0,"collision test reaches real boundary")
 var late=Sim.new();late.start()
 for i in 700:late.command({});late.tick(.2)
 check(late.phase=="pickup" and late.elapsed>late.deadline,"late pickup remains playable")
 var source=late.snapshot();var new=Sim.new();check(new.restore(source),"ordinary late state restores")
 for field in ["job_index","seed","delivered","collisions","resets","yaw","speed","integrity","elapsed","distance","checkpoint_yaw"]:
  for value in [null,true,NAN,INF,"0"]:
   var bad=source.duplicate(true);bad[field]=value
   check(not Sim.new().restore(bad),"invalid snapshot field rejected: "+field)
 print("PELICAN INDEPENDENT RULES: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
func drive(job:int,dt:float)->void:
 var s=Sim.new();s.start(job);var route:Array[Vector2]=[];var key:="";var last_delivered:=0;var meals:=0
 for i in 18000:
  var current:String=s.phase+str(s.delivered)
  if current!=key:key=current;route=road_route(s.pos,s.target())
  while route.size()>1 and s.pos.distance_to(route[0])<1.4:route.pop_front()
  var cmd:Dictionary
  if s.interactable():cmd={"brake":true,"interact":true}
  else:
   var delta:Vector2=route[0]-s.pos
   var error:=wrapf(atan2(-delta.x,-delta.y)-s.yaw,-PI,PI)
   var desired:=4.0 if absf(error)<.22 else 1.1
   if route.size()==1 and delta.length()<4:desired=.4
   cmd={"throttle":1.0 if s.speed<desired-.1 else 0.0,"brake":s.speed>desired+.2,"steer":clampf(-error*2.2,-1,1)}
  var old:Vector2=s.pos;var old_elapsed:float=s.elapsed
  s.command(cmd);s.tick(dt)
  check(inside_raw(s.pos),"route raw clearance")
  check(s.pos.distance_to(old)<=8.5*dt+.0001,"route speed bound")
  check(s.elapsed>=old_elapsed and s.elapsed-old_elapsed<=dt+.0001,"route elapsed bound")
  if s.delivered!=last_delivered:
   check(s.delivered==last_delivered+1,"one delivery per interaction")
   last_delivered=s.delivered
  for e in s.drain_events():
   if e.type=="delivery":meals+=1
  if s.phase in ["failed","complete"]:break
 check(s.phase=="complete","ordinary route completes job%d dt%f"%[job,dt])
 check(meals==s.deliveries.size(),"delivery event count matches full order")
 check(s.integrity>0 and s.score()>0,"legitimate completion has score and surviving cargo")
 var final=s.snapshot()
 for i in 20:s.command({"throttle":1.0,"interact":true});s.tick(dt)
 check(s.snapshot()==final,"terminal immutable")
 print("LEGAL ROUTE job=",job," dt=",dt," time=",s.elapsed," cargo=",s.integrity," collisions=",s.collisions)
