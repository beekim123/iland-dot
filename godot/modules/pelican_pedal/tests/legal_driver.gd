extends RefCounted
var waypoints: Array[Vector2]=[]
var target_key:=""
func command(sim) -> Dictionary:
	var id: String=sim.phase+str(sim.delivered)
	if id!=target_key:
		target_key=id;waypoints=route(sim.pos,sim.target())
	while waypoints.size()>1 and sim.pos.distance_to(waypoints[0])<1.7:waypoints.pop_front()
	if sim.interactable():return {"brake":true,"interact":true}
	if waypoints.is_empty():return {"brake":true}
	var delta: Vector2=waypoints[0]-sim.pos
	var angle:=wrapf(atan2(-delta.x,-delta.y)-sim.yaw,-PI,PI)
	var goal:=5.0
	if absf(angle)>.3:goal=1.3
	if delta.length()<5:goal=minf(goal,2.2)
	if waypoints.size()==1 and delta.length()<3.2:goal=.5
	return {"throttle":1.0 if sim.speed<goal-.15 else 0.0,"brake":sim.speed>goal+.2,"steer":clampf(-angle*2.5,-1,1)}
func route(start: Vector2, finish: Vector2) -> Array[Vector2]:
	var nodes: Array[Vector2]=preload("../data/map.gd").nodes()
	var first:=0;var last:=0
	for i in nodes.size():
		if start.distance_to(nodes[i])<start.distance_to(nodes[first]):first=i
		if finish.distance_to(nodes[i])<finish.distance_to(nodes[last]):last=i
	var frontier: Array[int]=[first];var previous:={first:-1}
	while not frontier.is_empty():
		var current:int=frontier.pop_front()
		if current==last:break
		for neighbor in nodes.size():
			if not previous.has(neighbor) and is_equal_approx(nodes[current].distance_to(nodes[neighbor]),24):previous[neighbor]=current;frontier.append(neighbor)
	var reverse: Array[int]=[];var cursor:=last
	while cursor!=-1:reverse.append(cursor);cursor=previous[cursor]
	reverse.reverse();var result: Array[Vector2]=[]
	for i in reverse:result.append(nodes[i])
	return result
