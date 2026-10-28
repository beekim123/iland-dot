extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var world=load("res://modules/pelican_pedal/world.gd").new();root.add_child(world);await process_frame
	var mesh:ArrayMesh=world.get_node("StaticSeasideBatch").mesh
	var floor_surfaces:=0
	for i in mesh.get_surface_count():
		var material:StandardMaterial3D=mesh.surface_get_material(i)
		if material.albedo_color.to_html(false) not in ["839b65","b9a581"]:continue
		floor_surfaces+=1
		var arrays:=mesh.surface_get_arrays(i)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		for normal in normals:check(normal.y>.9,"ground/road surface faces sky")
		var count:=indices.size() if not indices.is_empty() else vertices.size()
		for n in range(0,count,3):
			var a:=vertices[indices[n] if not indices.is_empty() else n]
			var b:=vertices[indices[n+1] if not indices.is_empty() else n+1]
			var c:=vertices[indices[n+2] if not indices.is_empty() else n+2]
			check((b-a).cross(c-a).y<-.000001,"Godot clockwise upward front faces, never invisible floor")
	check(floor_surfaces==2,"both lawn and road batches present")
	check(world.find_children("*","MeshInstance3D",true,false).size()<=8 and mesh.get_surface_count()<=50,"static batching bounds draw surfaces")
	var triangles:=0
	for node:MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var arrays:=node.mesh.surface_get_arrays(surface)
			triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size())/3
	print("WORLD RENDER GEOMETRY meshes=",world.find_children("*","MeshInstance3D",true,false).size()," static_surfaces=",mesh.get_surface_count()," triangles=",triangles," (not an FPS claim)")
	world.queue_free();await process_frame
	print("PELICAN WORLD ",checks," checks; ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
