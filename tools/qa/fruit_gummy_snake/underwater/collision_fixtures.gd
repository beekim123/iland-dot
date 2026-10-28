extends SceneTree
# Explicit geometric boundary fixtures, not normal-play evidence.
const Sim=preload("res://modules/fruit_gummy_snake/sim.gd")
var checks:=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:
 for height in [0.0,.55,.57,1.0,-1.0]:
  var s=Sim.new();s.start(271)
  s.body.assign([s.head,Vector3(0,12,.55),Vector3(0,12,1.1),Vector3(0,12,1.65),Vector3(-1,12+height,-.02),Vector3(1,12+height,-.02)])
  s.tick(1.0/120)
  ck(s.alive==(absf(height)>=.56),"swept head detects XYZ radius; depth="+str(height))
 var s=Sim.new();s.start(271)
 s.body.assign([s.head,Vector3(0,12,.55),Vector3(0,12,1.1),Vector3(-1,12,-.02),Vector3(1,12,-.02),Vector3(2,12,-.02)])
 s.tick(1.0/120);ck(s.alive,"only near-neck preceding segment excluded")
 # Segment geometry independently known analytic answers: crossing at depth, parallel, degenerate.
 for height in [0.0,.1,1.0,10.0]:
  var d:float=Sim.segment_distance(Vector3(-1,0,0),Vector3(1,0,0),Vector3(0,height,-1),Vector3(0,height,1))
  ck(absf(d-height)<.00001,"crossing depth distance")
 ck(absf(Sim.segment_distance(Vector3.ZERO,Vector3.RIGHT,Vector3.UP,Vector3(1,1,0))-1)<.00001,"parallel finite segments")
 ck(absf(Sim.segment_distance(Vector3.ZERO,Vector3.ZERO,Vector3.UP,Vector3.UP)-1)<.00001,"degenerate segments")
 # Actual physics at each world wall: manufactured initial head only.
 for p in [Vector3(24.01,12,0),Vector3(-24.01,12,0),Vector3(0,1.99,0),Vector3(0,26.01,0),Vector3(0,12,-24.01)]:
  s.start(271);s.head=p;s.tick(1.0/120);ck(not s.alive,"world boundary is three dimensional")
 print("INDEPENDENT UNDERWATER COLLISION FIXTURES: ",checks," checks; ",failures.size()," failures")
 quit(0 if failures.is_empty() else 1)
