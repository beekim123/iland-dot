extends SceneTree
const Sea = preload("res://modules/tide_gulp/art/tide_environment.gd")
func _initialize() -> void:
	var cases := [Rect2(-12,-7,24,14), Rect2(-6,-3,12,6), Rect2(240,-7,24,14)]
	for bounds: Rect2 in cases:
		for biome in range(3):
			var obstacle := Rect2(bounds.position + Vector2(2,0), Vector2(2.6,3.4))
			var env := Sea.make_environment(biome,bounds,[obstacle])
			root.add_child(env)
			for child: MeshInstance3D in env.get_children():
				var aabb: AABB = child.mesh.get_aabb()
				if child.name == "TrueCollisionReefs":
					assert(absf(aabb.position.x-obstacle.position.x)<0.0001)
					assert(absf(aabb.position.y-obstacle.position.y)<0.0001)
					assert(absf(aabb.size.x-obstacle.size.x)<0.0001)
					assert(absf(aabb.size.y-obstacle.size.y)<0.0001)
				elif child.name in ["SeaFansAndShells","Meadow","SwayingKelp"]:
					assert(aabb.end.z < -2.0, str(child.name)+" visual lane intrusion")
				var arrays: Array = child.mesh.surface_get_arrays(0)
				for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					assert(v.is_finite())
				for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
					assert(n.is_finite())
					assert(n.length_squared()>0.9)
			Sea.animate_environment(env,17.25,-1.0)
			env.queue_free()
	print("PASS: 9 biome/bounds cases; exact blocker XY AABB; decorative z<-2; finite vertices, unit normals; animated material API.")
	quit()
