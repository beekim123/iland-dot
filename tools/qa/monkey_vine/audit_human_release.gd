extends SceneTree
const R=preload("res://modules/monkey_vine/rules/rules.gd")
const H=1.0/120.0
var results=[]
func _initialize():
 for seed_value in [1,271828,-19]:
  for segment in range(4):
   for offset in [.55,.65,.75]:
    for release_ms in [80,120,180]:
     for strategy in ["baseline","prepare_landing"]:
      results.append(route(seed_value,segment,offset,release_ms,strategy))
 var failed=[]
 for r in results:
  if not r.complete:failed.append(r)
 print(JSON.stringify({"suite":"human_release_spacing","routes":results.size(),"failures":failed,"results":results}))
 quit(0 if failed.is_empty() else 1)
func route(seed_value,segment,offset,release_ms,strategy):
 var r=R.new();r.configure(seed_value,segment)
 var held=false
 var released_until=-1
 var grabs={}
 var completed=false
 var failed=false
 var shortest_release=999.0
 var last_release=-1
 var max_x=0.0
 for tick in range(1800):
  var s=r.snapshot()
  var next=held
  if s.grounded:next=not held and s.player_pos.x>(1.0 if s.player_pos.x<11 else 15.0) and s.player_pos.x<25
  elif s.vine_id!="":
   for v in s.vines:
    if v.id==s.vine_id:next=not(s.player_pos.x>v.anchor.x+offset and s.player_vel.x>0)
  else:next=true
  if strategy=="prepare_landing" and not s.grounded and s.vine_id=="" and ((s.player_pos.x>10.6 and s.player_pos.x<15.0) or s.player_pos.x>24.6): next=false
  if tick<released_until:next=false
  if held and not next:
   released_until=tick+int(ceil(float(release_ms)/1000/H))
   last_release=tick
  if next and not held and last_release>=0:shortest_release=minf(shortest_release,(tick-last_release)*H)
  s=r.step(H,{"right":true,"grab_held":next,"grab_pressed":next and not held,"grab_released":held and not next})
  held=next
  max_x=maxf(max_x,s.player_pos.x)
  for e in s.events:
   if e.type=="grab":grabs[e.id]=true
   if e.type=="fail":failed=true
   if e.type=="segment_clear":completed=true
  if completed or failed:break
 return {"strategy":strategy,"seed":seed_value,"segment":segment,"offset":offset,"release_ms":release_ms,"actual_min_release":shortest_release,"grabs":grabs.size(),"complete":completed,"fell":failed,"max_x":max_x}
