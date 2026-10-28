extends RefCounted
const ROAD_X := [-24.0,0.0,24.0]
const ROAD_Z := [-24.0,0.0,24.0]
const ROAD_WIDTH := 7.0
const RADIUS := 0.48
const LIMIT := 37.0
const STOP_NAMES := ["灯塔邮亭","花店街角","海风码头","集市广场","贝壳工坊","日光书屋","果汁小铺","海边车站","风铃旅店"]
static func nodes() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for z: float in ROAD_Z:
		for x: float in ROAD_X: out.append(Vector2(x,z))
	return out
static func height_at(p: Vector2) -> float:
	# Northern lighthouse quarter is a smooth, rideable 1.8m rise.
	return 1.8 * smoothstep(3.0,25.0,-p.y)
static func buildings() -> Array[Rect2]:
	return [Rect2(-19,-19,14,14),Rect2(5,-19,14,14),Rect2(-19,5,14,14),Rect2(5,5,14,14)]
static func road(p: Vector2) -> bool:
	for x: float in ROAD_X:
		if absf(p.x-x) <= ROAD_WIDTH*.5 and absf(p.y)<=29: return true
	for z: float in ROAD_Z:
		if absf(p.y-z) <= ROAD_WIDTH*.5 and absf(p.x)<=29: return true
	return false
static func clear(p: Vector2) -> bool:
	if not p.is_finite() or absf(p.x)>LIMIT-RADIUS or absf(p.y)>LIMIT-RADIUS: return false
	for box: Rect2 in collision_boxes():
		var nearest := Vector2(clampf(p.x,box.position.x,box.end.x),clampf(p.y,box.position.y,box.end.y))
		if p.distance_to(nearest) < RADIUS: return false
	for node: Vector2 in nodes():
		if p.distance_to(node+Vector2(4.1,4.1))<RADIUS+.13:return false
	for side in [-1,1]:
		for k in 9:
			if p.distance_to(Vector2(side*33.5,-30+k*7.5))<RADIUS+.2:return false
	return true
static func collision_boxes() -> Array[Rect2]:
	var result:=buildings()
	result.append(Rect2(-5.6,28,1.8,2))
	result.append(Rect2(-7.5,30.5,1,1));result.append(Rect2(-6.2,30.5,1,1))
	for building: Rect2 in buildings():
		var centre:=building.get_center()
		for side in [-1,1]:result.append(Rect2(centre+Vector2(side*4.5-.8,7.4-.325),Vector2(1.6,.65)))
	return result
static func stop_name(index: int) -> String: return STOP_NAMES[clampi(index,0,8)]
static func traffic_position(time: float, index: int) -> Vector2:
	var progress := fposmod(time*(1.0+index*.12)+index*17.0,96.0)
	if progress<24: return Vector2(-24+progress,-1.35)
	if progress<48: return Vector2(1.35,progress-24)
	if progress<72: return Vector2(24-(progress-48),25.35)
	return Vector2(-1.35,24-(progress-72))
