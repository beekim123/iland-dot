extends SceneTree
const Props = preload("seaside_props.gd")
func _initialize() -> void:
	var checks := 0
	var colors := {}
	for i in 4:
		var shop := Props.make_shop(i)
		for n in shop.find_children("*","MeshInstance3D",true,false):
			colors[n.material_override.albedo_color.to_html()] = true
			if n.mesh is ArrayMesh:
				var arrays: Array = n.mesh.surface_get_arrays(0)
				var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for j in range(0,vs.size(),3):
					assert((vs[j+1]-vs[j]).cross(vs[j+2]-vs[j]).dot(ns[j]) < -.001)
					checks += 1
		shop.free()
	for i in 2:
		var animal := Props.make_animal(i)
		assert(animal.get_child_count()==1)
		var bounds: AABB = animal.get_child(0).mesh.get_aabb()
		assert(bounds.size.x<=1.2 and bounds.size.z<=1.2)
		assert(bounds.position.y>-.02)
		print("animal ",i," bounds ",bounds," surfaces ",animal.get_child(0).mesh.get_surface_count())
		animal.free()
	Props.make_tree().free()
	Props.make_post().free()
	Props.make_lighthouse().free()
	Props.make_flowerbox().free()
	print("PASS roof CW triangles ",checks," shop palette ",colors.size())
	quit()
