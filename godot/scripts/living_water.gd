extends Node3D
## Animated Compatibility renderer water. Uses no screen/depth texture dependency.
## Existing Blender terrain remains unchanged. Only the old flat water art is hidden.
# Baked from art/v3/landscape_contract.json dry_shoreline_xy, 256 CCW samples.
# Center Blender(0,1.1) => Godot XZ(0,-1.1); pixels encode radius/16.
const SHORE_RADII = [10.311852, 10.4073991, 10.4973671, 10.5790368, 10.6463367, 10.6928678, 10.713978, 10.7085502, 10.6792109, 10.6308576, 10.568724, 10.4954109, 10.4145317, 10.3308802, 10.2454246, 10.1582681, 10.0657832, 9.9694366, 9.8671196, 9.7561716, 9.6313546, 9.4871418, 9.3241143, 9.1407795, 8.9371745, 8.7154193, 8.480354, 8.2397696, 8.0040378, 7.7867799, 7.5942579, 7.4270782, 7.2902347, 7.1770291, 7.0835307, 7.0124961, 6.9536238, 6.9116899, 6.8786898, 6.8549368, 6.8364682, 6.8208166, 6.8054495, 6.7861294, 6.7595914, 6.7262314, 6.6866395, 6.6424017, 6.5952074, 6.5456135, 6.497971, 6.4528303, 6.4120413, 6.3765138, 6.3453658, 6.3217293, 6.3024458, 6.2879761, 6.2778412, 6.2699173, 6.2638232, 6.2561334, 6.2464713, 6.2340421, 6.2184196, 6.1990136, 6.1777817, 6.1577686, 6.1399628, 6.1278207, 6.1217337, 6.1239889, 6.136206, 6.1580883, 6.1933902, 6.2398506, 6.3030578, 6.3788749, 6.4753584, 6.5870868, 6.7179823, 6.8650686, 7.0246671, 7.1913348, 7.356796, 7.5124358, 7.6518291, 7.772162, 7.8741668, 7.9609162, 8.0340085, 8.100401, 8.1638012, 8.2263689, 8.2894475, 8.3548521, 8.4230582, 8.4942082, 8.5664329, 8.6389268, 8.7106848, 8.7800121, 8.8411322, 8.8955538, 8.9423697, 8.9814298, 9.0136426, 9.0388417, 9.0621426, 9.087297, 9.1161036, 9.1514504, 9.1958414, 9.2495483, 9.3169045, 9.3957043, 9.486948, 9.5900627, 9.7011306, 9.8168995, 9.9305048, 10.0311768, 10.1062014, 10.1445027, 10.1402334, 10.0944442, 10.0139828, 9.908677, 9.7885256, 9.6596332, 9.5330688, 9.4136284, 9.3029663, 9.202809, 9.1131313, 9.0328368, 8.9609627, 8.8947116, 8.8327304, 8.7733771, 8.7120209, 8.6483624, 8.5827959, 8.5157521, 8.4474917, 8.3789675, 8.3144374, 8.2544101, 8.2014758, 8.156776, 8.1194586, 8.0948101, 8.0779548, 8.0709946, 8.0734095, 8.0820237, 8.0964139, 8.1116306, 8.1251452, 8.1313904, 8.1248172, 8.1004956, 8.0562599, 7.993396, 7.9136091, 7.8184516, 7.7099294, 7.588397, 7.4536051, 7.3048138, 7.1411844, 6.9648826, 6.7934551, 6.6619348, 6.5346354, 6.4054705, 6.2695332, 6.1223817, 5.9618823, 5.7890812, 5.6076935, 5.4261506, 5.3164072, 5.2065187, 5.0801324, 4.9269144, 4.7376784, 4.5080827, 4.3658398, 4.2731114, 4.1972889, 4.1336759, 4.0800994, 4.0435216, 4.0103506, 3.990635, 3.9822406, 3.9766119, 3.9844391, 4.0015549, 4.0225327, 4.0588137, 4.1000593, 4.1534522, 4.2147146, 4.2868172, 4.3658764, 4.4538633, 4.547234, 4.6456622, 4.7479464, 4.853029, 4.9617141, 5.0743106, 5.1905917, 5.3118482, 5.4388637, 5.5719383, 5.7104572, 5.8556767, 6.0081713, 6.165447, 6.3262591, 6.4905969, 6.6558259, 6.8188267, 6.9773166, 7.1309793, 7.2815333, 7.4317277, 7.5834262, 7.7398434, 7.9033011, 8.0737173, 8.2505288, 8.4315004, 8.6127353, 8.7912864, 8.9635498, 9.1256205, 9.272652, 9.3972601, 9.5017566, 9.5856308, 9.6504335, 9.6998649, 9.7388023, 9.7711891, 9.8017967, 9.8367277, 9.8772754, 9.9268143, 9.9860432, 10.0544558, 10.1334105, 10.2197267]
const SEA_LEVEL := -0.10
var shore_texture: ImageTexture
var surface_material: ShaderMaterial
var bottom_material: ShaderMaterial
var surface: MeshInstance3D
var bottom: MeshInstance3D
var initialized := false

func setup(landscape: Node3D) -> void:
	if initialized: return
	initialized = true
	name = "LivingOcean"
	if landscape:
		for node in landscape.find_children("*", "MeshInstance3D", true, false):
			var title := String(node.name).to_lower()
			if title == "ocean • seamless depth graded lagoon" or title.begins_with("cove foam • tapered arc"):
				node.visible = false
	shore_texture = _make_shore_texture()
	var shader := load("res://shaders/living_ocean.gdshader") as Shader
	bottom_material = ShaderMaterial.new()
	bottom_material.shader = shader
	bottom_material.set_shader_parameter("shore_radii", shore_texture)
	bottom_material.set_shader_parameter("seabed", true)
	bottom = MeshInstance3D.new()
	bottom.name = "SeaFloorWithMovingCaustics"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(400, 400)
	bottom.mesh = floor_mesh
	bottom.material_override = bottom_material
	bottom.position.y = -1.6
	bottom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bottom)
	surface_material = ShaderMaterial.new()
	surface_material.shader = shader
	surface_material.set_shader_parameter("shore_radii", shore_texture)
	surface_material.render_priority = 1
	surface = MeshInstance3D.new()
	surface.name = "TransparentRollingSea"
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(80,80)
	sea_mesh.subdivide_width = 128
	sea_mesh.subdivide_depth = 128
	surface.mesh = sea_mesh
	surface.material_override = surface_material
	surface.position.y = SEA_LEVEL
	surface.extra_cull_margin = 0.3
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	# Far water uses a ring with an empty center so alpha never double-composites.
	var far := MeshInstance3D.new()
	far.name = "FarSeaRing"
	far.mesh = _outer_ring()
	far.material_override = surface_material
	far.position.y = SEA_LEVEL
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.extra_cull_margin = 0.3
	add_child(far)
	update_water(0.0)

func _outer_ring() -> ArrayMesh:
	# Match the near PlaneMesh's 129 segments exactly at the inner perimeter.
	# A four-quad ring leaves cracks because its displaced edges are linear.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	const SEGMENTS := 129
	const PERIMETER := SEGMENTS * 4
	var rings := [40.0, 55.0, 80.0, 120.0, 200.0]
	for radius in rings:
		var corners := [Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(radius,radius),Vector2(-radius,radius)]
		for side in range(4):
			for k in range(SEGMENTS):
				var p: Vector2 = corners[side].lerp(corners[(side+1)%4],float(k)/float(SEGMENTS))
				vertices.append(Vector3(p.x,0,p.y))
				normals.append(Vector3.UP)
	for band in range(rings.size()-1):
		for k in range(PERIMETER):
			var a := band*PERIMETER+k
			var b := band*PERIMETER+(k+1)%PERIMETER
			indices.append_array(PackedInt32Array([a,b,b+PERIMETER,a,b+PERIMETER,a+PERIMETER]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func update_water(time: float) -> void:
	if surface_material: surface_material.set_shader_parameter("water_time", time)
	if bottom_material: bottom_material.set_shader_parameter("water_time", time)

func apply_motion(time: float) -> void:
	update_water(time)

func _make_shore_texture() -> ImageTexture:
	# Four byte RGBA avoids floating texture support differences in Compatibility.
	# A 16-bit radius split over RG retains <0.00025m precision at 16m extent.
	var bytes := PackedByteArray()
	for radius in SHORE_RADII:
		var encoded := int(round(float(radius) / 16.0 * 65535.0))
		bytes.append((encoded >> 8) & 255)
		bytes.append(encoded & 255)
		bytes.append(0)
		bytes.append(255)
	var img := Image.create_from_data(SHORE_RADII.size(),1,false,Image.FORMAT_RGBA8,bytes)
	return ImageTexture.create_from_image(img)
