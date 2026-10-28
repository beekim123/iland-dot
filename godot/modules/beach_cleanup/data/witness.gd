extends RefCounted
## Deterministic accessibility witness. Only commands/tick advance the cart.
## Kept separate from normal gameplay; also usable by headless integration QA.
const CELL := 0.5

static func route(sim, destination: Vector2, pickup_id: String = "") -> PackedVector2Array:
	var grid := AStarGrid2D.new()
	var half: Vector2 = sim.map_data.size * 0.5
	grid.region = Rect2i(Vector2i.ZERO,Vector2i(sim.map_data.size / CELL)+Vector2i.ONE)
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = -half
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for x in grid.region.size.x:
		for y in grid.region.size.y:
			var id := Vector2i(x,y)
			grid.set_point_solid(id,not sim.is_walkable(grid.get_point_position(id)))
	var origin := Vector2i((sim.pos + half) / CELL + Vector2(0.5,0.5))
	if not grid.is_in_boundsv(origin) or grid.is_point_solid(origin): return PackedVector2Array()
	var candidates: Array[Vector2i] = []
	var center := Vector2i((destination + half) / CELL + Vector2(0.5,0.5))
	var radius := 4 if not pickup_id.is_empty() else 3
	for dx in range(-radius,radius+1):
		for dy in range(-radius,radius+1):
			var id := center + Vector2i(dx,dy)
			if not grid.is_in_boundsv(id) or grid.is_point_solid(id): continue
			var p := grid.get_point_position(id)
			var d := p.distance_to(destination)
			if not pickup_id.is_empty():
				if d < 1.15 or d > 1.6 or not sim.line_clear(p,destination,pickup_id): continue
			elif d > 1.45: continue
			candidates.append(id)
	candidates.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	for id in candidates:
		var path := grid.get_point_path(origin,id)
		if not path.is_empty(): return path
	return PackedVector2Array()

static func drive(sim, path: PackedVector2Array) -> bool:
	if path.is_empty(): return false
	sim.command({"grab":false,"unload":false})
	for waypoint in path:
		var guard := 0
		while sim.pos.distance_to(waypoint) > 0.015:
			var delta: Vector2 = waypoint - sim.pos
			sim.command({"move":delta.normalized()})
			sim.tick(minf(1.0/60.0,delta.length()/4.0))
			guard += 1
			if guard > 120: return false
	sim.command({"move":Vector2.ZERO})
	return true

static func unload(sim) -> bool:
	var depots: Array = sim.map_data.depots.duplicate()
	depots.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return sim.pos.distance_squared_to(a.pos) < sim.pos.distance_squared_to(b.pos))
	for depot: Dictionary in depots:
		if drive(sim,route(sim,depot.pos)):
			sim.command({"unload":true}); sim.tick(1.0/60.0); sim.command({"unload":false})
			return sim.cargo.is_empty()
	return false

static func collect_one(sim,id: String) -> bool:
	var item: Dictionary = sim.item_by_id(id)
	if sim.capacity_used() + int(item.cost) > sim.CAPACITY:
		if not unload(sim): return false
	if not drive(sim,route(sim,item.pos,id)): return false
	var aim: Vector2 = item.pos - sim.pos
	sim.command({"move":aim.normalized()}); sim.tick(0.001)
	sim.command({"move":Vector2.ZERO,"grab":true}); sim.tick(0.52)
	sim.command({"grab":false})
	return not sim.remaining.has(id)

static func complete(sim) -> bool:
	while not sim.remaining.is_empty():
		var id: String = sim.nearest_hint().id
		if not collect_one(sim,id): return false
	return unload(sim) and sim.phase == "complete"
