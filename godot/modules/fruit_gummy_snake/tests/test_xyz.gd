extends SceneTree
const Sim=preload("../sim.gd")
var checks:=0
var failures:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures+=1;push_error(label)
func _initialize()->void:
	var a=Sim.new();var b=Sim.new();a.start(42);b.start(42)
	a.set_controls(.25,.2,0);b.set_controls(.25,.2,0)
	for i in 120:a.tick(1.0/60)
	for i in 6:b.tick(1.0/3)
	check(a.head.distance_to(b.head)<.0001,"dt invariant")
	check(a.head.x>1 and a.head.y>12 and a.head.z<0,"all XYZ movement")
	check(a.body.size()==a.longest,"body length after actual movement")
	for i in range(1,a.body.size()):check(absf(a.body[i].distance_to(a.body[i-1])-.55)<.003,"arc spacing")
	check(Sim.segment_distance(Vector3.ZERO,Vector3.RIGHT,Vector3(.5,1,-1),Vector3(.5,1,1))>.99,"height crossing safe")
	check(Sim.segment_distance(Vector3.ZERO,Vector3.RIGHT,Vector3(.5,0,-1),Vector3(.5,0,1))<.001,"XYZ crossing hits")
	for seed_value in 200:
		a.start(seed_value)
		check(a.foods.size()==6,"bounded spawn")
		for food in a.foods:
			var p:Vector3=food.position;check(absf(p.x)<=22 and absf(p.z)<=22 and p.y>=4 and p.y<=24,"XYZ bounds")
	a.start(84)
	check(a.foods[0].get("intro",false) and a.foods[0].kind==0 and a.foods[0].expires<0,"normal intro apple")
	check(a.foods[0].position.distance_to(a.head+a.forward*4+Vector3.UP*.4)<.001,"normal intro location")
	for i in 120:a.tick(1.0/120)
	check(a.collected[0]>=1 and a.score>=10,"ordinary forward movement eats intro")
	var intro_count:=0
	for food in a.foods:
		if food.get("intro",false):intro_count+=1
	check(intro_count==0 and a.foods.size()==6,"intro only once then random refill")
	a.start(1);a.set_controls(0,0,-1)
	check(absf(a.current_speed()-1.7)<.0001,"S precise swim speed")
	check(absf(float(a.snapshot().speed)-1.7)<.0001,"HUD real speed")
	for i in 120:a.tick(1.0/120)
	check(absf(a.head.z+1.7)<.001,"slow swim actual distance")
	a.set_controls(0,0,1);check(absf(a.current_speed()-4.6)<.0001,"W unchanged")
	a.set_controls(0,0,0);check(absf(a.current_speed()-3.9)<.0001,"release normal speed")
	a.start(1);a.foods.clear();a.foods.append({"id":500,"kind":2,"position":a.head+Vector3.FORWARD*.85,"expires":-1.0})
	for i in 60:a.tick(1.0/120)
	check(a.score==15 and a.longest==9,"swept eat and grow")
	a.start(1)
	for i in 1000:a.tick(1.0/120)
	check(not a.alive and a.reason=="boundary","boundary ends")
	print("XYZ AUTHOR ",checks," checks failures=",failures);quit(1 if failures else 0)
