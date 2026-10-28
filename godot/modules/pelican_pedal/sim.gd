extends RefCounted
const Map = preload("data/map.gd")
const SCHEMA := 1
var job_index := 0
var seed_value := 7231
var pos := Vector2(0,29)
var yaw := 0.0
var speed := 0.0
var integrity := 100.0
var elapsed := 0.0
var distance := 0.0
var phase := "pickup"
var deliveries: Array[int] = []
var delivered := 0
var collisions := 0
var resets := 0
var deadline := 130.0
var checkpoint := Vector2(0,29)
var checkpoint_yaw := 0.0
var reset_hold := 0.0
var collision_cooldown := 0.0
var input := {"throttle":0.0,"steer":0.0,"brake":false,"interact":false,"reset":false}
var events: Array[Dictionary] = []
func start(index: int = 0, seed: int = 7231) -> void:
	job_index=maxi(0,index); seed_value=seed
	pos=Vector2(0,29); yaw=0; speed=0; integrity=100; elapsed=0; distance=0
	phase="pickup"; delivered=0; collisions=0; resets=0; reset_hold=0; collision_cooldown=0
	checkpoint=pos; checkpoint_yaw=yaw; events.clear(); command({})
	var routes := [[3,0],[5,8],[1,2,5],[6,7,8],[0,1,2],[8,7,6],[2,5,8],[6,3,0]]
	deliveries.clear()
	for id in routes[job_index%routes.size()]: deliveries.append(int(id))
	deadline=130.0+(deliveries.size()-2)*45.0
func command(value: Dictionary) -> void:
	var throttle := float(value.get("throttle",0)); var steer := float(value.get("steer",0))
	input={"throttle":clampf(throttle,-1,1) if is_finite(throttle) else 0.0,"steer":clampf(steer,-1,1) if is_finite(steer) else 0.0,"brake":bool(value.get("brake",false)),"interact":bool(value.get("interact",false)),"reset":bool(value.get("reset",false))}
func target_index() -> int: return 7 if phase=="pickup" else deliveries[mini(delivered,deliveries.size()-1)]
func target() -> Vector2: return Map.nodes()[target_index()]
func interactable() -> bool: return phase in ["pickup","delivery"] and pos.distance_to(target())<=2.5 and absf(speed)<1.0
func tick(dt: float) -> void:
	if not is_finite(dt) or dt<=0 or phase not in ["pickup","delivery"]: return
	# Bounded fixed-size movement pieces; input edge is consumed once.
	var total := minf(dt,0.5)
	var steps := maxi(1,int(ceil(total/(1.0/60.0))))
	for step in steps:
		_step(total/steps)
		if phase not in ["pickup","delivery"]: break
	input.interact=false
func _step(dt: float) -> void:
	elapsed+=dt; collision_cooldown=maxf(0,collision_cooldown-dt)
	if input.interact and interactable():
		input.interact=false; speed=0
		if phase=="pickup": phase="delivery"; _event({"type":"pickup"})
		else:
			delivered+=1; _event({"type":"delivery","count":delivered})
			if delivered>=deliveries.size(): phase="complete"; _event({"type":"complete","score":score()}); return
	if input.reset:
		reset_hold+=dt
		if reset_hold>=1.3:
			pos=checkpoint; yaw=checkpoint_yaw; speed=0; resets+=1; integrity=maxf(0,integrity-5)
			reset_hold=-1000; _event({"type":"reset"})
	else: reset_hold=0
	var acceleration := float(input.throttle)*4.0
	var drag := 1.4 if is_zero_approx(float(input.throttle)) else .35
	if input.brake: speed=move_toward(speed,0,11*dt)
	else:
		speed=move_toward(speed,0,drag*dt)
		speed=clampf(speed+acceleration*dt,-2.4,8.5 if Map.road(pos) else 3.4)
	if absf(speed)>.08:
		yaw=wrapf(yaw-float(input.steer)*(0.45+minf(absf(speed),6)*.20)*dt*signf(speed),-PI,PI)
	var next := pos+Vector2(-sin(yaw),-cos(yaw))*speed*dt
	if Map.clear(next):
		distance+=pos.distance_to(next); pos=next
	else: _collision(); speed=-speed*.15
	if job_index>0:
		for i in 2:
			if pos.distance_to(Map.traffic_position(elapsed,i))<.9: _collision(); speed=move_toward(speed,0,4*dt)
	if Map.road(pos) and absf(speed)<1.0 and Map.clear(pos):
		checkpoint=pos; checkpoint_yaw=yaw
	if integrity<=0: phase="failed"; speed=0; _event({"type":"failed"})
func _collision() -> void:
	if collision_cooldown>0: return
	collision_cooldown=1.4; collisions+=1
	var loss := 4.0+absf(speed)*2.1
	integrity=maxf(0,integrity-loss); _event({"type":"collision","loss":loss})
func score() -> int:
	if phase!="complete": return 0
	return maxi(0,delivered*150+int(integrity*1.5)+(100 if elapsed<=deadline else 0)-resets*10)
func drain_events() -> Array[Dictionary]:
	var result := events.duplicate(true); events.clear(); return result
func snapshot() -> Dictionary:
	return {"schema":SCHEMA,"job_index":job_index,"seed":seed_value,"pos":[pos.x,pos.y],"yaw":yaw,"speed":speed,"integrity":integrity,"elapsed":elapsed,"distance":distance,"phase":phase,"delivered":delivered,"collisions":collisions,"resets":resets,"checkpoint":[checkpoint.x,checkpoint.y],"checkpoint_yaw":checkpoint_yaw}
func restore(data: Dictionary) -> bool:
	if typeof(data.get("schema")) not in [TYPE_INT,TYPE_FLOAT] or data.get("schema")!=SCHEMA: return false
	for key in ["job_index","seed","delivered","collisions","resets"]:
		if not data.has(key) or typeof(data[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])) or float(data[key])!=floor(float(data[key])): return false
	if int(data.job_index)<0 or int(data.job_index)>1000000 or int(data.collisions)<0 or int(data.collisions)>1000000 or int(data.resets)<0 or int(data.resets)>1000000 or absf(float(data.seed))>2147483647: return false
	for key in ["yaw","speed","integrity","elapsed","distance","checkpoint_yaw"]:
		if not data.has(key) or typeof(data[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data[key])): return false
	for key in ["pos","checkpoint"]:
		if not data.has(key) or not data[key] is Array or data[key].size()!=2: return false
		for v in data[key]:
			if typeof(v) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(v)): return false
		if not Map.clear(Vector2(data[key][0],data[key][1])): return false
	if data.get("phase","") not in ["pickup","delivery","complete","failed"]: return false
	if float(data.integrity)<0 or float(data.integrity)>100 or float(data.elapsed)<0 or float(data.elapsed)>1000000 or float(data.distance)<0 or float(data.distance)>1e9 or absf(float(data.yaw))>PI or absf(float(data.checkpoint_yaw))>PI or absf(float(data.speed))>8.5: return false
	if not Map.road(Vector2(data.checkpoint[0],data.checkpoint[1])): return false
	var probe = get_script().new(); probe.start(int(data.job_index),int(data.seed))
	if int(data.delivered)<0 or int(data.delivered)>probe.deliveries.size(): return false
	if data.phase=="pickup" and int(data.delivered)!=0: return false
	if data.phase=="delivery" and int(data.delivered)>=probe.deliveries.size(): return false
	if data.phase=="complete" and int(data.delivered)!=probe.deliveries.size(): return false
	if data.phase=="failed" and float(data.integrity)>0: return false
	start(int(data.job_index),int(data.seed)); pos=Vector2(data.pos[0],data.pos[1]); yaw=float(data.yaw); speed=0
	integrity=float(data.integrity); elapsed=float(data.elapsed); distance=float(data.distance); phase=data.phase
	delivered=int(data.delivered); collisions=int(data.collisions); resets=int(data.resets); checkpoint=Vector2(data.checkpoint[0],data.checkpoint[1]); checkpoint_yaw=float(data.checkpoint_yaw)
	return true

func _event(value: Dictionary) -> void:
	if events.size()>=128:events.pop_front()
	events.append(value)
