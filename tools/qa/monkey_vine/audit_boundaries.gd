extends SceneTree
# ONLY labelled boundary fixtures below mutate state; these do not prove playability.
const R=preload("res://modules/monkey_vine/rules/rules.gd")
const H=1.0/120
var checks=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok and not label in failures: failures.append(label);print("FAIL ",label)
func _initialize():
 for axis in [Vector2(1,0),Vector2(-1,0),Vector2(0,-1),Vector2(0,1)]:
  var r=R.new();r.configure(1)
  r.level.platforms=[{"id":"block","rect":Rect2(-1,-1,2,2)}]
  r.grounded=false
  var begin=-axis*5
  r.player_vel=axis*100
  var end=r._sweep(begin,axis*5)
  check(absf(end.dot(axis)+1.32)<.0001,"sweep fixture stops at expanded face "+str(axis))
  check(r.player_vel.dot(axis)<=.0001,"sweep fixture removes into-solid velocity")
 for kind in ["fixed","moving","fragile"]:
  var r=R.new();r.configure(1)
  r.level.platforms=[]
  r.level.vines=[{"id":"test","anchor":Vector2(0,5),"length":3.0,"type":kind,"warning_duration":1.2}]
  r.player_pos=Vector2(0,1.55);r.grounded=false
  var s=r.step(H,{"grab_held":true,"grab_pressed":true})
  check(s.vine_id=="test","nearby fixture catch "+kind)
  var warning_t=-1.0
  var broken=false
  var grab_count=1
  for tick in range(300):
   s=r.step(H,{"grab_held":true})
   for e in s.events:
    if e.type=="grab": grab_count+=1
    if e.type=="break_warning": warning_t=s.time
    if e.type=="vine_break":
     broken=true
     check(warning_t>=0 and s.time-warning_t>=1.2-H-.00001,"fragile full warning duration")
  if kind=="fragile":
   check(broken,"fragile breaks")
   check(grab_count==1,"held cannot recatch broken vine")
  else:
   check(grab_count==1,"held no repeated grab/energy farm "+kind)
   var pre=r.snapshot()
   var post=r.step(H,{"grab_held":false,"grab_released":true})
   check(post.vine_id=="","release detaches "+kind)
   check(post.player_vel.distance_to(pre.player_vel)<.2,"release preserves velocity "+kind)
   s=r.step(H,{"grab_held":true,"grab_pressed":true})
   check(s.vine_id=="","same vine cooldown "+kind)
 # This is a true ordinary input continuous 3-stage route, not a boundary fixture.
 var r=R.new();r.configure(99)
 var held=false
 var wins=0
 for tick in range(2200):
  var s=r.snapshot()
  if s.phase=="segment_clear":
   wins+=1
   if wins==3: break
   r.advance_segment();held=false;s=r.snapshot()
  var next=held
  if s.grounded: next=not held and s.player_pos.x>(1.0 if s.player_pos.x<11 else 15.0) and s.player_pos.x<25
  elif s.vine_id!="":
   for v in s.vines:
    if v.id==s.vine_id: next=not(s.player_pos.x>v.anchor.x+.65 and s.player_vel.x>0)
  else: next=true
  s=r.step(H,{"right":true,"grab_held":next,"grab_pressed":next and not held,"grab_released":held and not next})
  held=next
  for e in s.events: check(e.type!="fail","continuous ordinary route no failure")
 check(wins==3,"continuous ordinary 3-stage completion")
 print(JSON.stringify({"suite":"independent_boundaries_and_seams","checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
