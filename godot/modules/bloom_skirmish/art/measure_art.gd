extends SceneTree
const Art = preload("res://modules/bloom_skirmish/art/bloom_art.gd")
func measure(n: Node) -> Dictionary:
	var result := {"triangles":0,"surfaces":0,"vertices":0,"meshes":0,"skinned_meshes":0,"bones":0}
	if n is Skeleton3D: result.bones += n.get_bone_count()
	if n is MeshInstance3D:
		result.meshes += 1
		if n.skin: result.skinned_meshes += 1
		for s in n.mesh.get_surface_count():
			var a: Array = n.mesh.surface_get_arrays(s)
			result.triangles += a[Mesh.ARRAY_INDEX].size()/3
			result.vertices += a[Mesh.ARRAY_VERTEX].size()
			result.surfaces += 1
	for child in n.get_children():
		var c := measure(child)
		for k in result: result[k] += c[k]
	return result
func _initialize() -> void:
	var data := {"authorship":"Original authored cartoon animals, Blender skinning and legacy procedural staging environment; no third-party model assets", "generator":"source/animals/<species>/build_<species>.py + source/animals/rigging/build_rigs.py + bloom_art.gd", "renderer":"Godot 4.7.2 GL Compatibility", "material_pipeline":"rigged animals PBR (fox palette converted in authoring); obsolete unrigged preview conversion removed", "status":"Animal skin integration; no claim of completed environment redesign or Web performance acceptance", "geometry":{}}
	for species: String in ["otter","rabbit","fox","raccoon"]:
		for team in 2:
			var n := Art.make_animal(species,team)
			assert(n != null)
			var entry := measure(n)
			var path: String = n.get_meta("asset_path")
			entry["path"] = path.trim_prefix("res://modules/bloom_skirmish/art/")
			entry["sha256"] = FileAccess.get_sha256(path)
			entry["bytes"] = FileAccess.get_file_as_bytes(path).size()
			var player: AnimationPlayer = n.get_meta("animation_player")
			entry["clips"] = Array(player.get_animation_list())
			data.geometry[species + "_" + ("blue" if team == 0 else "orange")] = entry
			n.free()
	data["historical_asset_policy"] = {"local_only":true,"published":false,"required_for_runtime_or_animal_reproduction":false,"note":"Rejected human binaries and inspection PNGs are retained locally, not shipped in the animal source publication."}
	data["historical_non_runtime_assets"] = []
	for color_name: String in ["blue","orange"]:
		var history_path := "res://modules/bloom_skirmish/art/source/legacy_human/athlete_%s.glb" % color_name
		if not FileAccess.file_exists(history_path): continue
		data.historical_non_runtime_assets.append({"local_only":true,"published":false,"path":history_path.trim_prefix("res://modules/bloom_skirmish/art/"),"sha256":FileAccess.get_sha256(history_path),"bytes":FileAccess.get_file_as_bytes(history_path).size(),"runtime":false})
	var file := FileAccess.open("res://modules/bloom_skirmish/art/art_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t")+"\n")
	print(JSON.stringify(data))
	quit()
