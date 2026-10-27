extends Node3D
## Entry metadata adapter around the user-approved floating magic rift.
const RIFT = preload("res://hub/portal_v2/magic_rift.gd")
var game_id := ""
var enabled := false
var tint := Color("ff439c")
var label: Label3D
var effect: Node3D
var hovered := false
var short_title := ""

func configure(entry: Dictionary) -> void:
	game_id = str(entry.get("id", ""))
	enabled = bool(entry.get("enabled", false))
	# Approved pink / teal / purple family, independent of catalog UI badges.
	var palette := {"gummy_bomber":Color("ff439c"), "bloom_skirmish":Color("23dcca"), "reef_memory":Color("9864ff"), "cloud_hop":Color("9864ff")}
	tint = palette.get(game_id, Color(entry.get("color", "9864ff")))
	var visual_entry := entry.duplicate()
	visual_entry["color"] = tint if enabled else tint.darkened(.12)
	effect = RIFT.new()
	# Configure BEFORE ready builds shader materials; otherwise all portals are pink.
	effect.configure(visual_entry)
	add_child(effect)
	_conform_shadow(entry.get("ground_patch",[]))
	label = Label3D.new(); add_child(label)
	label.position = Vector3(0,3.85,0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = load("res://hub/hub-ui.otf")
	label.font_size = 64; label.pixel_size = .0055; label.outline_size = 3
	label.outline_modulate = Color("675575")
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	label.shaded = false
	var short_names := {"gummy_bomber":"糖果爆爆", "bloom_skirmish":"绒芽争园", "reef_memory":"珊瑚记忆", "cloud_hop":"云朵跳跳"}
	short_title = str(short_names.get(game_id,entry.get("title",game_id)))
	label.text = "" if enabled else "未开放"
	label.no_depth_test = false

func get_game_id() -> String:
	return game_id

func set_hovered(value: bool) -> void:
	hovered = value
	if is_instance_valid(effect): effect.set_hovered(value)

func get_pick_bounds() -> AABB:
	# Visible irregular body, not the transparent outer corners of the quad.
	return AABB(Vector3(-1.05,.25,-.40),Vector3(2.10,3.30,.80))

func _process(_delta: float) -> void:
	if not is_instance_valid(effect): return
	effect.set_hovered(hovered)
	label.text = short_title if hovered else ("" if enabled else "未开放")
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		label.scale = Vector3.ONE*clampf(camera.global_position.distance_to(label.global_position)/28.0,.8,1.0)
	label.modulate = Color("fff1a8") if hovered else Color("f2ecff")

func _conform_shadow(heights: Array) -> void:
	if heights.size() != 45: return
	# Preserve the approved soft-shadow shader/UVs; only drape its receiver mesh
	# onto the known terrain. No ground ring, cylinder, or magic-circle artwork.
	for child in effect.get_children():
		if not child is MeshInstance3D: continue
		# QuadMesh inherits PlaneMesh: type-only matching would flatten the energy!
		if child.mesh is QuadMesh: continue
		var material = child.material_override
		if child.mesh is PlaneMesh and material is ShaderMaterial and material.shader.resource_path == "res://hub/portal_v2/soft_shadow.gdshader":
			var vertices := PackedVector3Array(); var uvs := PackedVector2Array()
			var normals := PackedVector3Array(); var indices := PackedInt32Array()
			for z in range(5):
				for x in range(9):
					vertices.append(Vector3(-1.3+x*.325,float(heights[z*9+x])-global_position.y+.010,-.725+z*.3625))
					uvs.append(Vector2(x/8.0,z/4.0)); normals.append(Vector3.UP)
			for z in range(4):
				for x in range(8):
					var a := z*9+x
					indices.append_array(PackedInt32Array([a,a+9,a+1,a+1,a+9,a+10]))
			var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_TEX_UV]=uvs
			arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_INDEX]=indices
			var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			child.mesh=mesh
