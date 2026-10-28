extends SceneTree
const World=preload("world.gd")
const Island=preload("../../data/island.gd")
const Sim=preload("../../sim.gd")
func _initialize() -> void:
	var world=World.new(); root.add_child(world); world.build(Island.build())
	var report:Dictionary=world.geometry_report()
	print(report)
	assert(report.terrain_contains_walkways)
	assert(report.roads==18 and report.shelters==6 and report.exits==3 and report.beacons==3)
	assert(report.triangles<45000)
	for mesh in _meshes(world):
		if mesh.mesh==null: continue
		for surface in mesh.mesh.get_surface_count():
			var a:Array=mesh.mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
			var normals:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
			assert(vertices.size()%3==0 and normals.size()==vertices.size())
			for n in normals: assert(n.is_finite() and n.length()>0.9)
			for i in range(0,vertices.size(),3):
				var cross_value=(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i])
				assert(cross_value.dot(normals[i]+normals[i+1]+normals[i+2])<=0.0001)
	var sim=Sim.new(); sim.start()
	world.update_state(sim.snapshot())
	assert(not world.road_visuals.DG.warning.visible)
	sim.time=96; sim._schedule(); world.update_state(sim.snapshot())
	assert(world.road_visuals.DG.warning.visible and not world.road_visuals.DG.lava.visible)
	sim.time=116; sim._schedule(); world.update_state(sim.snapshot())
	assert(not world.road_visuals.DG.warning.visible and world.road_visuals.DG.lava.visible)
	sim.pos=Island.NODES.A; world.update_state(sim.snapshot())
	assert(not world.shelter_visuals.shelter_A.roof.visible)
	sim.time=36; world.update_state(sim.snapshot())
	assert(world.rock_visuals.rock_00.root.visible)
	sim.start()
	var maximum_draws:=0
	for sec in range(331):
		sim.time=float(sec); sim._schedule(); world.update_state(sim.snapshot())
		var draws:=0
		for item in _meshes(world):
			if item.is_visible_in_tree() and item.mesh!=null: draws+=item.mesh.get_surface_count()
		maximum_draws=maxi(maximum_draws,draws)
	assert(maximum_draws<100)
	print("ENVIRONMENT_PASS ",report," max visible surface draws=",maximum_draws)
	quit()
func _meshes(node:Node) -> Array:
	var out:Array=[]
	if node is MeshInstance3D: out.append(node)
	for child in node.get_children(): out.append_array(_meshes(child))
	return out
