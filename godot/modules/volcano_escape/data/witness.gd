extends RefCounted
## Witnesses never assign simulation state: only ordinary movement, time and E.
const Island = preload("island.gd")
static func wait_until(sim, target: float) -> void:
	sim.command({"move":Vector2.ZERO,"interact":false})
	while sim.time<target-0.000001 and sim.status=="running": sim.tick(minf(0.25,target-sim.time))

static func drive(sim, nodes: Array) -> bool:
	sim.command({"interact":false})
	for node: String in nodes:
		var target: Vector2 = Island.NODES[node]
		var budget := 1000
		while sim.pos.distance_to(target)>0.06 and sim.status=="running" and budget>0:
			var delta: Vector2=target-sim.pos
			sim.command({"move":delta.normalized()})
			sim.tick(minf(1.0/20.0,delta.length()/Island.SPEED)); budget-=1
		if budget==0 or sim.status!="running": return false
	sim.command({"move":Vector2.ZERO})
	return true

static func press(sim, duration: float = 0.05) -> void:
	sim.command({"move":Vector2.ZERO,"interact":false}); sim.tick(0.02)
	sim.command({"interact":true}); sim.tick(duration)
	sim.command({"interact":false})

static func escape(sim, exit_id: String, window: int = 0, alternate: bool = false) -> bool:
	var route: Array
	match exit_id:
		"boat": route=["H","K"] if not alternate else ["F","I","H","K"]
		"balloon": route=["F","C"] if not alternate else ["H","I","F","C"]
		_: route=["H","G","J"] if not alternate else ["D","E","H","G","J"]
	if not drive(sim,route): return false
	if exit_id=="airship": press(sim,1.1)
	var starts := {"boat":[120.1,240.1],"balloon":[135.1,250.1],"airship":[145.1,265.1]}
	wait_until(sim,starts[exit_id][window])
	press(sim,6.1 if exit_id=="balloon" else 0.1)
	return sim.status=="success" and sim.result.exit==exit_id
