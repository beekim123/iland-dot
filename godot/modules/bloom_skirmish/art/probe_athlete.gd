extends SceneTree
## Historical bind-mesh diagnostic; not a deformed-skin sole/contact proof.
## Use validate_art.gd and independent CPU skin QA for current animal motion.
const Art=preload("res://modules/bloom_skirmish/art/bloom_art.gd")
var low_y:=INF
func scan(n:Node3D, parent:Transform3D=Transform3D.IDENTITY)->void:
	var tr:=parent*n.transform
	if n is MeshInstance3D:
		for s in n.mesh.get_surface_count():
			var data:Array=n.mesh.surface_get_arrays(s)
			for p:Vector3 in data[Mesh.ARRAY_VERTEX]: low_y=minf(low_y,(tr*p).y)
	for c in n.get_children():
		if c is Node3D:scan(c,tr)
func _initialize()->void:
	for team in 2:
		var rig:=Art.make_gardener(team)
		Art.animate_gardener(rig,0,0,false,false)
		low_y=INF;scan(rig)
		print("BIND MESH MIN_Y (not posed skin) ",team," = ",low_y)
		for motion in [[.2,.6,true,false],[.8,1.0,true,true],[1.3,0.0,false,false]]:
			Art.animate_gardener(rig,motion[0],motion[1],motion[2],motion[3])
			var tip:Vector3=rig.get_node("Weapon").transform*rig.get_node("Weapon/Muzzle").position
			var world:=tip*1.3+Vector3(0,.04,0)
			assert(world.distance_to(Vector3(.403,.884,-1.04))<.00001)
		print("MUZZLE PASS team",team," idle/run/shoot/dash exact physical anchor")
		rig.free()
	quit()
