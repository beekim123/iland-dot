extends SceneTree
const Art=preload("res://modules/bloom_skirmish/art/bloom_art.gd")
var count:=0
func check(n:Node)->void:
	if n is MeshInstance3D:
		for s in n.mesh.get_surface_count():
			var m:StandardMaterial3D=n.mesh.surface_get_material(s)
			var a:Array=n.mesh.surface_get_arrays(s)
			if count<4: print(n.name," vcol=",m.vertex_color_use_as_albedo," srgb=",m.vertex_color_is_srgb," colors=",a[Mesh.ARRAY_COLOR].size() if a[Mesh.ARRAY_COLOR]!=null else 0)
			count+=1
	for c in n.get_children():check(c)
func _initialize()->void:
	var rig:=Art.make_animal("fox",0)
	if rig==null:quit(1);return
	check(rig);rig.free();quit()
