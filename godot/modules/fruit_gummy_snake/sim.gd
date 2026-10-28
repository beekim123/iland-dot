extends RefCounted
const STEP:=1.0/120.0
const SPACING:=0.55
const MAX_LENGTH:=120
const POINTS:=[10,12,15,24,40]
var head:=Vector3(0,12,0)
var forward:=Vector3.FORWARD
var body:Array[Vector3]=[]
var trail:Array[Vector3]=[]
var foods:Array[Dictionary]=[]
var alive:=true
var won:=false
var score:=0
var reason:=""
var meals:=0
var longest:=8
var elapsed:=0.0
var collected:=[0,0,0,0,0]
var yaw:=0.0
var pitch:=0.0
var controls:=Vector3.ZERO
var accumulator:=0.0
var length_value:=8
var next_id:=0
var combo:Array[int]=[]
var events:Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()

func start(seed_value:int=1)->void:
	rng.seed=seed_value;head=Vector3(0,12,0);forward=Vector3.FORWARD;yaw=0;pitch=0;controls=Vector3.ZERO;accumulator=0;elapsed=0;length_value=8;longest=8;score=0;alive=true;won=false;next_id=0
	reason="";meals=0;collected=[0,0,0,0,0];foods.clear();events.clear();combo.clear();trail.clear();body.clear()
	# A real gently curved initial history, sampled by the same arc-length routine.
	# Curvature <= .313/m; no cosmetic offset from the collision body.
	for i in 61:
		var z:=float(i)*.1;trail.append(head+Vector3(.20*(1-cos(z*1.25)),0,z))
	_sample_body()
	# Normal-product onboarding for every seed, not a preview/debug placement.
	next_id=1;foods.append({"id":1,"kind":0,"position":head+forward*4+Vector3.UP*.4,"expires":-1.0,"intro":true})
	_fill_foods()

func set_controls(turn:float,tilt:float,throttle:float)->void:
	controls=Vector3(clampf(turn,-1,1) if is_finite(turn) else 0.0,clampf(tilt,-1,1) if is_finite(tilt) else 0.0,clampf(throttle,-1,1) if is_finite(throttle) else 0.0)

func current_speed()->float:
	return 3.9+controls.z*(.7 if controls.z>=0 else 2.2)

func tick(delta:float)->void:
	if not alive or not is_finite(delta) or delta<=0:return
	accumulator+=delta
	var steps:=0
	while accumulator+1e-10>=STEP and alive and steps<1200:
		accumulator-=STEP;steps+=1;_step()

func _step()->void:
	elapsed+=STEP;yaw-=controls.x*1.55*STEP;pitch=clampf(pitch+controls.y*1.15*STEP,-deg_to_rad(75),deg_to_rad(75))
	forward=Vector3(-sin(yaw)*cos(pitch),sin(pitch),-cos(yaw)*cos(pitch)).normalized()
	# Right input increases world X when initially facing -Z.
	var old:=head;head+=forward*(current_speed())*STEP
	if absf(head.x)>24 or absf(head.z)>24 or head.y<2 or head.y>26:_finish(false,"boundary");return
	for i in range(4,body.size()-1):
		if segment_distance(old,head,body[i],body[i+1])<.56:_finish(false,"self");return
	trail.push_front(head);_sample_body()
	for i in range(foods.size()-1,-1,-1):
		var food:Dictionary=foods[i]
		if point_segment_distance(food.position,old,head)<.8:
			meals+=1
			var kind:int=food.kind;score+=POINTS[kind];collected[kind]+=1;length_value=mini(MAX_LENGTH,length_value+(2 if kind>=3 else 1));longest=maxi(longest,length_value)
			if combo.has(kind):combo.clear()
			combo.append(kind);events.append({"type":"eat","kind":kind,"points":POINTS[kind]})
			if combo.size()==3:score+=30;combo.clear();events.append({"type":"salad"})
			foods.remove_at(i)
			if length_value==MAX_LENGTH:_sample_body();_finish(true,"grown");return
		elif food.expires>0 and elapsed>=food.expires:foods.remove_at(i)
	_sample_body();_fill_foods()

func _sample_body()->void:
	body.clear();body.append(head)
	var distance:=0.0;var next_sample:=SPACING;var keep:=trail.size()
	for i in range(1,trail.size()):
		var a:=trail[i-1];var b:=trail[i];var span:=a.distance_to(b)
		while next_sample<=distance+span and body.size()<length_value:
			body.append(a.lerp(b,(next_sample-distance)/span if span>0 else 0));next_sample+=SPACING
		distance+=span
		if distance>float(length_value+3)*SPACING:keep=i+1;break
	if keep<trail.size():trail.resize(keep)
	while body.size()<length_value:body.append(trail.back())

func _fill_foods()->void:
	while foods.size()<6:
		var found:=false;var p:=Vector3.ZERO
		for attempt in 256:
			p=Vector3(rng.randf_range(-22,22),rng.randf_range(4,24),rng.randf_range(-22,22))
			if _free(p):found=true;break
		if not found:
			for index in 1331:
				p=Vector3(-20+(index%11)*4,4+((index/11)%11)*2,-20+(index/121)*4)
				if _free(p):found=true;break
		if not found:return
		var kind:=rng.randi_range(0,4);next_id+=1
		foods.append({"id":next_id,"kind":kind,"position":p,"expires":elapsed+12 if kind==4 else -1.0,"intro":false})

func _free(p:Vector3)->bool:
	for b in body:
		if b.distance_to(p)<1.6:return false
	for food in foods:
		if food.position.distance_to(p)<2:return false
	return true

func _finish(success:bool,result_reason:String)->void:
	reason=result_reason;alive=false;won=success;controls=Vector3.ZERO;events.append({"type":"result","reason":reason})

func drain_events()->Array[Dictionary]:
	var result:=events.duplicate(true);events.clear();return result

func snapshot()->Dictionary:
	return {"reason":reason,"meals":meals,"head":head,"forward":forward,"body":body.duplicate(),"foods":foods.duplicate(true),"alive":alive,"won":won,"score":score,"length":length_value,"longest":longest,"elapsed":elapsed,"combo":combo.duplicate(),"collected":collected.duplicate(),"speed":current_speed(),"depth":28-head.y,"boundary_distance":minf(24-absf(head.x),minf(24-absf(head.z),minf(head.y-2,26-head.y)))}

static func point_segment_distance(p:Vector3,a:Vector3,b:Vector3)->float:
	var ab:=b-a;return p.distance_to(a+ab*clampf((p-a).dot(ab)/ab.length_squared(),0,1)) if ab.length_squared()>1e-12 else p.distance_to(a)

static func segment_distance(p1:Vector3,q1:Vector3,p2:Vector3,q2:Vector3)->float:
	var d1:=q1-p1;var d2:=q2-p2;var r:=p1-p2;var a:=d1.dot(d1);var e:=d2.dot(d2);var f:=d2.dot(r);var s:=0.0;var t:=0.0
	if a<=1e-12:return point_segment_distance(p1,p2,q2)
	if e<=1e-12:return point_segment_distance(p2,p1,q1)
	var c:=d1.dot(r);var b:=d1.dot(d2);var denom:=a*e-b*b
	if absf(denom)>1e-12:s=clampf((b*f-c*e)/denom,0,1)
	t=(b*s+f)/e
	if t<0:t=0;s=clampf(-c/a,0,1)
	elif t>1:t=1;s=clampf((b-c)/a,0,1)
	return (p1+d1*s).distance_to(p2+d2*t)
