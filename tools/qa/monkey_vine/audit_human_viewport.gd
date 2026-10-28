extends SceneTree
const Game=preload("res://modules/monkey_vine/main.tscn")
var checks=0
var failures=[]
func check(ok,label):
 checks+=1
 if not ok and not label in failures:failures.append(label);print("FAIL ",label)
func key(code,down):
 var e=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down
 root.push_input(e,true)
func _initialize():call_deferred("run")
func run():
 var g=Game.instantiate();root.add_child(g)
 g.start({});g.set_process(false)
 await process_frame
 var start_segment=int(g.snapshot().segment)
 var held=false
 var released_until=-1
 var release_ticks=15 # 125ms, rounded up from human target120ms
 var wins=0
 var grab_ids={}
 key(KEY_D,true)
 for tick in range(2400):
  var s=g.snapshot()
  if s.phase=="segment_clear":
   wins+=1
   if wins==3:break
   key(KEY_ENTER,true);key(KEY_ENTER,false)
   s=g.snapshot()
   held=false
   released_until=-1
   key(KEY_D,true)
  var next=held
  if s.grounded:next=not held and s.player_pos.x>(1.0 if s.player_pos.x<11 else 15.0) and s.player_pos.x<25
  elif s.vine_id!="":
   for v in s.vines:
    if v.id==s.vine_id:next=not(s.player_pos.x>v.anchor.x+.55 and s.player_vel.x>0)
  else:next=true
  if tick<released_until:next=false
  if held and not next:released_until=tick+release_ticks
  if next!=held:key(KEY_SPACE,next)
  held=next
  g._process(1.0/120)
  s=g.snapshot()
  for e in s.events:
   check(e.type!="fail","normal viewport route never fails")
   if e.type=="grab":grab_ids[str(s.segment)+":"+e.id]=true
  if tick%120==0:await process_frame
 check(wins==3,"actual viewport ordinary controls complete 3 stages")
 check(grab_ids.size()>=18,"actual viewport catches 18 vines")
 check(g.snapshot().segment==start_segment+2,"stage progression through actual Enter")
 g.exit_requested.connect(func():root.remove_child(g);g.queue_free())
 g.request_exit()
 await create_timer(.4).timeout
 print(JSON.stringify({"suite":"independent_human_125ms_viewport_route","checks":checks,"wins":wins,"grabs":grab_ids.size(),"failures":failures}))
 quit(0 if failures.is_empty() else 1)
