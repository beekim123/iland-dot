extends RefCounted
## Original world-space watercolor scenery for Tide Gulp.
## Gameplay owns every obstacle. Only rectangles supplied in `obstacles` are
## rendered at z = 0; all decorative silhouettes stay behind z = -2.
## Geometry is authored here, batched by material, and has no external assets.

const WATERCOLOR_PATH := "res://modules/tide_gulp/shaders/watercolor.gdshader"
const TAU_F := TAU
const PALE_WATER := Color("cce3dc")
const PAPER := Color("f0ead3")
const STONE_COLORS := [Color("c7c5b0"), Color("b5c4b2"), Color("b9bdc8")]
const WASH_COLORS := [Color("c5dfd4"), Color("bdd8d0"), Color("c4d1dc")]
const FLOOR_COLORS := [Color("d9ceb2"), Color("bdcbb1"), Color("b6bdcb")]
static var _fallback_material: StandardMaterial3D
static var _watercolor_material: Material
static var _wash_material: ShaderMaterial
static var _plant_material: ShaderMaterial
static var _flow_material: ShaderMaterial

static func make_environment(biome: int, bounds: Rect2, obstacles: Array = []) -> Node3D:
	var root := Node3D.new()
	root.set_script(load("res://modules/tide_gulp/art/tide_environment_motion.gd"))
	root.name = "PaintedSea_%d_%d" % [biome, int(bounds.position.x)]
	root.set_meta("biome", biome)
	root.set_meta("bounds", bounds)
	biome = clampi(biome, 0, 2)
	var seed_value: int = int(bounds.position.x * 87.0 + biome * 1903) + 19473
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var floor_y: float = bounds.position.y
	var ceiling_y: float = bounds.end.y
	var left: float = bounds.position.x
	var right: float = bounds.end.x
	var mid: float = bounds.get_center().x
	var background := _new_batch()
	var distant := _new_batch()
	var floor_batch := _new_batch()
	var coral_batch := _new_batch()
	var grass_batch := _new_batch()
	var obstacle_batch := _new_batch()
	var plant_batch := _new_batch()
	var flow_batch := _new_batch()

	# A quiet, seamless shared water field. Biome washes are in the distant
	# silhouettes rather than solid panels, so streamed chunks do not stripe.
	_add_quad(background,
		Vector3(left, floor_y - 4.0, -11.0), Vector3(right, floor_y - 4.0, -11.0),
		Vector3(right, ceiling_y + 6.0, -11.0), Vector3(left, ceiling_y + 6.0, -11.0),
		[Color("b9d5cd"), Color("b9d5cd"), Color("e1eddf"), Color("e1eddf")])
	# Delicate overlapping paint blooms: lower-contrast than any playable fish.
	for i in range(4):
		var wash_x: float = left + bounds.size.x * (float(i) + 0.45) / 4.0
		_add_wash(distant, Vector3(wash_x, floor_y + rng.randf_range(1.2, 4.8), -9.7 + float(i) * 0.07),
			Vector2(rng.randf_range(3.0, 5.0), rng.randf_range(2.2, 4.0)),
			WASH_COLORS[biome].lerp(PALE_WATER, 0.3), rng)
	# Shallow brush strokes at the visible waterline; never a gameplay wall.
	for i in range(4):
		var wave_y: float = ceiling_y + 0.22 + i * 0.19
		_add_ribbon(distant, Vector3(left, wave_y, -8.3), Vector3(right, wave_y + 0.05, -8.3),
			0.025, Color("e3eee0").darkened(i * 0.012), 12, 0.06)

	# Background current marks are brush strokes, never edible-looking particles.
	for row in range(3):
		for column in range(3):
			var flow_x: float = left + (float(column) + 0.35 + float(row % 2) * 0.36) * bounds.size.x / 3.0
			var flow_y: float = floor_y + bounds.size.y * (0.24 + float(row) * 0.25)
			_add_flow_stroke(flow_batch, Vector3(flow_x, flow_y, -5.25), 1.12)

	# The flat upper line is the actual simulated seabed y boundary.
	_add_quad(floor_batch, Vector3(left, floor_y - 4.0, -1.2), Vector3(right, floor_y - 4.0, -1.2),
		Vector3(right, floor_y, -1.2), Vector3(left, floor_y, -1.2),
		[FLOOR_COLORS[biome].darkened(0.13), FLOOR_COLORS[biome].darkened(0.1), FLOOR_COLORS[biome], FLOOR_COLORS[biome]])
	_add_quad(floor_batch, Vector3(left, floor_y, -3.0), Vector3(right, floor_y, -3.0),
		Vector3(right, floor_y, 1.1), Vector3(left, floor_y, 1.1),
		[FLOOR_COLORS[biome].lightened(0.08), FLOOR_COLORS[biome].lightened(0.08), FLOOR_COLORS[biome], FLOOR_COLORS[biome]])
	for i in range(17):
		var px: float = left + (float(i) + rng.randf_range(0.1, 0.9)) * bounds.size.x / 17.0
		var py: float = floor_y - rng.randf_range(0.05, 1.4)
		_add_ellipsoid(floor_batch, Vector3(px, py, -0.8),
			Vector3(rng.randf_range(0.07, 0.27), rng.randf_range(0.035, 0.10), 0.08),
			FLOOR_COLORS[biome].darkened(rng.randf_range(0.10, 0.22)), 6, 3, rng.randf())

	# Low-contrast, obviously distant features: never in the interaction plane.
	if biome == 0:
		_build_shallow(distant, coral_batch, grass_batch, floor_y, left, right, rng)
	elif biome == 1:
		_build_kelp(distant, coral_batch, plant_batch, floor_y, left, right, rng)
	else:
		_build_ruins(distant, coral_batch, grass_batch, floor_y, left, right, rng)

	for value in obstacles:
		var rect: Rect2
		if value is Rect2:
			rect = value
		elif value is Dictionary and value.has("rect"):
			rect = value["rect"]
		else:
			continue
		# This exact rect is the complete rendered blocking silhouette. Decoration
		# on an obstacle stays inside it: no ornamental overhangs create false walls.
		_add_obstacle(obstacle_batch, rect, STONE_COLORS[biome], rng)
		# Paint a few subsurface marks rather than mesh objects outside the bounds.
		if rect.size.x > 1.1 and rect.size.y > 0.9:
			for j in range(3):
				var inset_x: float = rect.position.x + rect.size.x * rng.randf_range(0.20, 0.78)
				var inset_y: float = rect.position.y + rect.size.y * rng.randf_range(0.22, 0.78)
				_add_ellipsoid(obstacle_batch, Vector3(inset_x, inset_y, 0.22),
					Vector3(minf(0.16, rect.size.x * 0.06), minf(0.09, rect.size.y * 0.05), 0.018),
					STONE_COLORS[biome].lightened(0.2), 6, 3, float(j))

	_add_batch_node(root, background, "WaterPaper", _get_wash_material())
	_add_batch_node(root, distant, "DistantPigment", _get_wash_material())
	var flow_mat := _get_flow_material().duplicate() as ShaderMaterial
	flow_mat.set_shader_parameter("chunk_left", left)
	flow_mat.set_shader_parameter("chunk_width", bounds.size.x)
	_add_batch_node(root, flow_batch, "CurrentBrushStrokes", flow_mat)
	_add_batch_node(root, floor_batch, "SeaBed", _get_painted_material())
	_add_batch_node(root, coral_batch, "SeaFansAndShells", _get_painted_material())
	_add_batch_node(root, grass_batch, "Meadow", _get_painted_material())
	_add_batch_node(root, obstacle_batch, "TrueCollisionReefs", _get_painted_material())
	if not plant_batch["vertices"].is_empty():
		var plant := _add_batch_node(root, plant_batch, "SwayingKelp", _get_plant_material().duplicate())
		plant.set_meta("painted_kelp", true)
	root.set_meta("draw_batches", root.get_child_count())
	return root

static func animate_environment(node: Node3D, time: float, current: float = 0.0) -> void:
	# Deterministic low-frequency deformation, never on blockers or fish targets.
	var flow := node.get_node_or_null("CurrentBrushStrokes") as MeshInstance3D
	if flow and flow.material_override is ShaderMaterial:
		var flow_mat := flow.material_override as ShaderMaterial
		flow_mat.set_shader_parameter("sea_time", time)
		flow_mat.set_shader_parameter("current_strength", clampf(current, -2.0, 2.0))
	var kelp := node.get_node_or_null("SwayingKelp") as MeshInstance3D
	if kelp and kelp.material_override is ShaderMaterial:
		var material := kelp.material_override as ShaderMaterial
		material.set_shader_parameter("sea_time", time)
		material.set_shader_parameter("current_strength", clampf(current, -2.0, 2.0))

static func _build_shallow(distant: Dictionary, coral: Dictionary, grass: Dictionary, floor_y: float, left: float, right: float, rng: RandomNumberGenerator) -> void:
	# Distant reef shelves have washed edges and always sit several metres back.
	for i in range(5):
		var x: float = lerpf(left + 1.0, right - 1.0, float(i) / 4.0)
		_add_ellipsoid(distant, Vector3(x, floor_y + 0.15, -6.7),
			Vector3(rng.randf_range(1.6, 3.1), rng.randf_range(0.7, 1.7), 0.6), Color("a8c9bd"), 9, 5, float(i))
	for i in range(7):
		var x: float = left + (float(i) + 0.5) * (right - left) / 7.0 + rng.randf_range(-0.6, 0.6)
		var z: float = -3.0 - rng.randf_range(0.1, 1.5)
		var height: float = rng.randf_range(0.8, 1.9)
		var coral_color: Color = [Color("c79283"), Color("d4b18b"), Color("96b3a2")][i % 3]
		_add_fan(coral, Vector3(x, floor_y - 0.10, z), height, coral_color, rng)
		_add_ellipsoid(coral, Vector3(x, floor_y - 0.02, z), Vector3(0.42, 0.18, 0.25), Color("b8bba5"), 8, 4, rng.randf())
	for i in range(13):
		var x: float = left + (float(i) + 0.5) * (right - left) / 13.0
		var blade_height: float = rng.randf_range(0.24, 0.55)
		for j in range(3):
			_add_leaf(grass, Vector3(x + float(j - 1) * 0.07, floor_y - 0.04, -2.4),
				Vector3(float(j - 1) * 0.16, blade_height * (1.0 - absf(float(j - 1)) * 0.18), 0.03),
				0.065, Color("83a894"), rng.randf() * TAU_F)
		if i % 3 == 0:
			_add_shell(coral, Vector3(x + 0.3, floor_y + 0.05, -2.3), 0.32, Color("ece1bd"))

static func _build_kelp(distant: Dictionary, coral: Dictionary, plants: Dictionary, floor_y: float, left: float, right: float, rng: RandomNumberGenerator) -> void:
	for i in range(8):
		var x: float = left + (float(i) + 0.5) * (right - left) / 8.0
		var height: float = rng.randf_range(2.3, 4.7)
		var z: float = -5.8 - rng.randf_range(0.0, 1.2)
		_add_kelp(distant, Vector3(x, floor_y - 0.10, z), height, Color("a1c4b5"), rng, false)
	for i in range(5):
		var x: float = left + (float(i) + 0.5) * (right - left) / 5.0
		var height: float = rng.randf_range(1.8, 3.4)
		_add_kelp(plants, Vector3(x, floor_y - 0.1, -3.4), height, Color("699a83"), rng, true)
		_add_ellipsoid(coral, Vector3(x, floor_y - 0.06, -3.2), Vector3(0.45, 0.17, 0.26), Color("a2b69d"), 8, 4, rng.randf())
		if i % 2 == 0:
			_add_shell(coral, Vector3(x + 0.55, floor_y + 0.02, -2.5), 0.35, Color("d8d1b6"))

static func _build_ruins(distant: Dictionary, coral: Dictionary, grass: Dictionary, floor_y: float, left: float, right: float, rng: RandomNumberGenerator) -> void:
	var ruin_color := Color("a7b8c0")
	var width: float = right - left
	var arch_x: float = left + width * 0.46
	var arch_y: float = floor_y + 0.1
	# The broken temple is unmistakably behind the active lane, and its silhouette
	# deliberately reads as background paint instead of a playable passage.
	_add_arch(distant, Vector3(arch_x, arch_y, -7.8), 2.8, 3.2, 0.45, ruin_color)
	_add_pillar(distant, Vector3(left + width * 0.17, floor_y - 0.1, -7.2), 0.75, 2.7, ruin_color.darkened(0.025), 0.08)
	_add_pillar(distant, Vector3(left + width * 0.82, floor_y - 0.15, -7.6), 0.72, 1.8, ruin_color.lightened(0.03), -0.13)
	for i in range(7):
		var x: float = left + (float(i) + 0.5) * width / 7.0
		_add_ellipsoid(coral, Vector3(x, floor_y - 0.05, -3.8),
			Vector3(rng.randf_range(0.32, 0.64), rng.randf_range(0.13, 0.30), 0.3), Color("a1adba"), 7, 4, rng.randf())
		for j in range(3):
			_add_leaf(grass, Vector3(x + j * 0.07, floor_y - 0.05, -3.1),
				Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(0.42, 0.9), 0.05),
				0.09, Color("8caaa4"), rng.randf() * TAU_F)
		if i % 2 == 0:
			_add_fan(coral, Vector3(x + 0.3, floor_y - 0.05, -3.5), 0.7,
				Color("b3a2b6"), rng)

static func _new_batch() -> Dictionary:
	return {"vertices": PackedVector3Array(), "normals": PackedVector3Array(), "colors": PackedColorArray(), "uvs": PackedVector2Array()}

static func _triangle(batch: Dictionary, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, uva := Vector2.ZERO, uvb := Vector2.ZERO, uvc := Vector2.ZERO) -> void:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	# Flat XY faces are the camera-facing painted side; normalize their lighting
	# consistently while curved solids keep their authored radial normals.
	if absf(a.z - b.z) < 0.0001 and absf(a.z - c.z) < 0.0001 and normal.z < 0.0:
		normal = -normal
	if normal.length_squared() < 0.1:
		normal = Vector3.FORWARD
	batch["vertices"].append_array(PackedVector3Array([a, b, c]))
	batch["normals"].append_array(PackedVector3Array([normal, normal, normal]))
	batch["colors"].append_array(PackedColorArray([ca, cb, cc]))
	batch["uvs"].append_array(PackedVector2Array([uva, uvb, uvc]))

static func _add_quad(batch: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colors: Array) -> void:
	_triangle(batch, a, c, b, colors[0], colors[2], colors[1], Vector2(0,0), Vector2(1,1), Vector2(1,0))
	_triangle(batch, a, d, c, colors[0], colors[3], colors[2], Vector2(0,0), Vector2(0,1), Vector2(1,1))

static func _add_batch_node(root: Node3D, batch: Dictionary, label: String, material: Material) -> MeshInstance3D:
	if batch["vertices"].is_empty():
		return null
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = batch["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = batch["normals"]
	arrays[Mesh.ARRAY_COLOR] = batch["colors"]
	arrays[Mesh.ARRAY_TEX_UV] = batch["uvs"]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if label == "CurrentBrushStrokes":
		node.extra_cull_margin = 2.0
	root.add_child(node)
	return node

static func _add_ellipsoid(batch: Dictionary, center: Vector3, radii: Vector3, color: Color, segments: int = 8, rings: int = 4, variation: float = 0.0) -> void:
	for j in range(rings):
		var latitude_a: float = -PI / 2.0 + float(j) * PI / rings
		var latitude_b: float = -PI / 2.0 + float(j + 1) * PI / rings
		for i in range(segments):
			var longitude_a: float = float(i) * TAU_F / segments
			var longitude_b: float = float(i + 1) * TAU_F / segments
			var a := center + Vector3(cos(latitude_a) * cos(longitude_a), sin(latitude_a), cos(latitude_a) * sin(longitude_a)) * radii
			var b := center + Vector3(cos(latitude_a) * cos(longitude_b), sin(latitude_a), cos(latitude_a) * sin(longitude_b)) * radii
			var c := center + Vector3(cos(latitude_b) * cos(longitude_b), sin(latitude_b), cos(latitude_b) * sin(longitude_b)) * radii
			var d := center + Vector3(cos(latitude_b) * cos(longitude_a), sin(latitude_b), cos(latitude_b) * sin(longitude_a)) * radii
			var tint: Color = color.lightened(0.028 * sin(float(i * 11 + j * 7) + variation * 3.0))
			_add_quad(batch, a, b, c, d, [tint, tint, tint.lightened(0.025), tint.lightened(0.025)])

static func _add_wash(batch: Dictionary, center: Vector3, size: Vector2, color: Color, rng: RandomNumberGenerator) -> void:
	var points: Array[Vector3] = []
	var n := 14
	for i in range(n):
		var angle: float = float(i) * TAU_F / n
		var radius: float = rng.randf_range(0.86, 1.04)
		points.append(center + Vector3(cos(angle) * size.x * radius, sin(angle) * size.y * radius, -0.03 * cos(angle)))
	for i in range(n):
		_triangle(batch, center, points[(i + 1) % n], points[i], color, color.lerp(PALE_WATER, 0.65), color.lerp(PALE_WATER, 0.65))

static func _add_ribbon(batch: Dictionary, a: Vector3, b: Vector3, half_width: float, color: Color, sections: int, wave: float) -> void:
	for i in range(sections):
		var ta: float = float(i) / sections
		var tb: float = float(i + 1) / sections
		var pa: Vector3 = a.lerp(b, ta) + Vector3(0.0, sin(ta * TAU_F * 2.3) * wave, 0.0)
		var pb: Vector3 = a.lerp(b, tb) + Vector3(0.0, sin(tb * TAU_F * 2.3) * wave, 0.0)
		_add_quad(batch, pa + Vector3(0, -half_width, 0), pb + Vector3(0, -half_width, 0),
			pb + Vector3(0, half_width, 0), pa + Vector3(0, half_width, 0), [color, color, color, color])

static func _add_flow_stroke(batch: Dictionary, center: Vector3, length: float) -> void:
	var paper := Color("e6eee1")
	var uv := Vector2(center.x, center.y)
	for line in range(2):
		var span: float = length * (1.0 if line == 0 else 0.67)
		for segment in range(7):
			var t0: float = float(segment) / 7.0
			var t1: float = float(segment + 1) / 7.0
			var p0 := center + Vector3((t0 - 0.5) * span, sin(t0 * PI * 1.5) * 0.035 + line * 0.095, 0)
			var p1 := center + Vector3((t1 - 0.5) * span, sin(t1 * PI * 1.5) * 0.035 + line * 0.095, 0)
			var wa: float = 0.018 * sin(0.15 + t0 * (PI - 0.30))
			var wb: float = 0.018 * sin(0.15 + t1 * (PI - 0.30))
			_triangle(batch, p0 - Vector3(0,wa,0), p1 + Vector3(0,wb,0), p1 - Vector3(0,wb,0), paper,paper,paper,uv,uv,uv)
			_triangle(batch, p0 - Vector3(0,wa,0), p0 + Vector3(0,wa,0), p1 + Vector3(0,wb,0), paper,paper,paper,uv,uv,uv)
	# One open brush tip makes direction readable without a solid UI arrow.
	var tip := center + Vector3(length * 0.5, -0.025, 0)
	for sign_y in [-1.0,1.0]:
		var tail := tip + Vector3(-0.15, 0.11 * sign_y, 0)
		_triangle(batch, tail + Vector3(0,0.014,0), tip, tail - Vector3(0,0.014,0), paper,paper,paper,uv,uv,uv)

static func _add_branch(batch: Dictionary, a: Vector3, b: Vector3, radius_a: float, radius_b: float, color: Color, sections: int = 6) -> void:
	var direction: Vector3 = (b - a).normalized()
	var side: Vector3 = direction.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < 0.1:
		side = Vector3.RIGHT
	var depth: Vector3 = side.cross(direction).normalized()
	for i in range(sections):
		var angle_a: float = float(i) * TAU_F / sections
		var angle_b: float = float(i + 1) * TAU_F / sections
		var radial_a: Vector3 = side * cos(angle_a) + depth * sin(angle_a)
		var radial_b: Vector3 = side * cos(angle_b) + depth * sin(angle_b)
		var tint: Color = color.lightened(0.03 * sin(angle_a))
		_add_quad(batch, a + radial_a * radius_a, a + radial_b * radius_a,
			b + radial_b * radius_b, b + radial_a * radius_b, [tint, tint, tint, tint])

static func _add_fan(batch: Dictionary, anchor: Vector3, height: float, color: Color, rng: RandomNumberGenerator) -> void:
	# A soft scalloped sea-fan membrane, not a branching terrestrial tree.
	# Front/back curved surfaces and a rounded stem give it real volume.
	var center := anchor + Vector3(0, height * 0.23, 0)
	var petal_color: Color = color.lightened(0.19)
	_add_branch(batch, anchor, center, height * 0.061, height * 0.055, color.lightened(0.06), 8)
	var segments := 22
	var rings := 5
	var fan_phase: float = rng.randf_range(-0.15, 0.15)
	for side in [-1.0, 1.0]:
		for j in range(rings):
			var r0: float = float(j) / rings
			var r1: float = float(j + 1) / rings
			for i in range(segments):
				var a0: float = lerpf(-1.12, 1.12, float(i) / segments)
				var a1: float = lerpf(-1.12, 1.12, float(i + 1) / segments)
				var edge0: float = height * (0.77 + 0.043 * cos(a0 * 15.0 + fan_phase))
				var edge1: float = height * (0.77 + 0.043 * cos(a1 * 15.0 + fan_phase))
				var p0 := center + Vector3(sin(a0) * edge0 * r0, cos(a0) * edge0 * r0,
					side * height * (0.018 + 0.07 * sin(r0 * PI)))
				var p1 := center + Vector3(sin(a1) * edge1 * r0, cos(a1) * edge1 * r0,
					side * height * (0.018 + 0.07 * sin(r0 * PI)))
				var p2 := center + Vector3(sin(a1) * edge1 * r1, cos(a1) * edge1 * r1,
					side * height * (0.018 + 0.07 * sin(r1 * PI)))
				var p3 := center + Vector3(sin(a0) * edge0 * r1, cos(a0) * edge0 * r1,
					side * height * (0.018 + 0.07 * sin(r1 * PI)))
				var tint0: Color = petal_color.lightened(r0 * 0.04 + 0.015 * sin(float(i)))
				var tint1: Color = petal_color.lightened(r1 * 0.04 + 0.015 * sin(float(i)))
				_add_quad(batch, p0, p1, p2, p3, [tint0, tint0, tint1, tint1])
	# Watered pigment veins remain very low contrast, stopping before the rim.
	for i in range(7):
		var angle: float = lerpf(-0.94, 0.94, float(i) / 6.0)
		var end := center + Vector3(sin(angle) * height * 0.66, cos(angle) * height * 0.66, height * 0.064)
		var start := center + Vector3(0, 0.03, height * 0.025)
		_add_branch(batch, start, end, height * 0.011, height * 0.004, petal_color.darkened(0.06), 5)

static func _add_leaf(batch: Dictionary, base: Vector3, offset: Vector3, width: float, color: Color, phase: float = 0.0, animate: bool = false) -> void:
	var length: float = offset.length()
	var side := Vector3(offset.y, -offset.x, 0.0).normalized()
	for i in range(5):
		var t0: float = float(i) / 5.0
		var t1: float = float(i + 1) / 5.0
		var a: Vector3 = base + offset * t0 + Vector3(sin(t0 * PI) * 0.11 * cos(phase), 0, sin(t0 * PI) * 0.06)
		var b: Vector3 = base + offset * t1 + Vector3(sin(t1 * PI) * 0.11 * cos(phase), 0, sin(t1 * PI) * 0.06)
		var w0: float = width * pow(sin(t0 * PI), 0.65)
		var w1: float = width * pow(sin(t1 * PI), 0.65)
		var ca: Color = color.lightened(t0 * 0.06)
		var cb: Color = color.lightened(t1 * 0.06)
		# UV.y carries the blade's physical bend weight, not world position.
		var uv0 := Vector2(phase, t0 * length if animate else 0.0)
		var uv1 := Vector2(phase, t1 * length if animate else 0.0)
		_triangle(batch, a - side * w0, b, b - side * w1, ca, cb.lightened(0.03), cb, uv0, uv1, uv1)
		_triangle(batch, a - side * w0, a, b, ca, ca.lightened(0.03), cb.lightened(0.03), uv0, uv0, uv1)
		_triangle(batch, a, b + side * w1, b, ca.lightened(0.03), cb, cb.lightened(0.03), uv0, uv1, uv1)
		_triangle(batch, a, a + side * w0, b + side * w1, ca.lightened(0.03), ca, cb, uv0, uv0, uv1)

static func _add_kelp(batch: Dictionary, base: Vector3, height: float, color: Color, rng: RandomNumberGenerator, animate: bool) -> void:
	var lean: float = rng.randf_range(-0.35, 0.35)
	var phase: float = rng.randf_range(0, TAU_F)
	_add_leaf(batch, base, Vector3(lean, height, 0), 0.10, color.darkened(0.06), phase, animate)
	for i in range(5):
		var t: float = 0.16 + float(i) * 0.15
		var sign_side: float = 1.0 if i % 2 == 0 else -1.0
		var leaf_root: Vector3 = base + Vector3(lean, height, 0) * t
		var length: float = height * lerpf(0.31, 0.18, t)
		_add_leaf(batch, leaf_root,
			Vector3(sign_side * length * 0.68, length * 0.58, 0.06), length * 0.15,
			color.lightened(0.025 * i), phase + float(i), animate)

static func _add_shell(batch: Dictionary, anchor: Vector3, size: float, color: Color) -> void:
	var center := anchor + Vector3(0, 0.01, 0.06)
	for i in range(7):
		var a0: float = PI * float(i) / 7.0
		var a1: float = PI * float(i + 1) / 7.0
		var p0 := anchor + Vector3(cos(a0) * size, sin(a0) * size * 0.67, sin(a0) * size * 0.20)
		var p1 := anchor + Vector3(cos(a1) * size, sin(a1) * size * 0.67, sin(a1) * size * 0.20)
		var tint: Color = color.darkened(0.045 if i % 2 == 0 else 0.0)
		_triangle(batch, center, p1, p0, tint.darkened(0.08), tint, tint)
		_add_branch(batch, center, p0, size * 0.018, size * 0.012, color.darkened(0.12), 4)

static func _add_obstacle(batch: Dictionary, rect: Rect2, color: Color, rng: RandomNumberGenerator) -> void:
	var x0: float = rect.position.x
	var x1: float = rect.end.x
	var y0: float = rect.position.y
	var y1: float = rect.end.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	var rear := -1.2
	# The complete rectangle is still solid, with the same exact XY silhouette.
	# Uneven sediment courses and shallow folded stone faces replace the generic
	# box's four bevel strips. No chipped/transparent corner hides a collision.
	var columns: int = clampi(int(ceil(w / 0.8)), 3, 7)
	var rows: int = clampi(int(ceil(h / 0.52)), 3, 9)
	var points: Array[Vector3] = []
	var colors: Array[Color] = []
	for row in range(rows + 1):
		for column in range(columns + 1):
			var tx: float = float(column) / columns
			var ty: float = float(row) / rows
			var px: float = lerpf(x0,x1,tx)
			var py: float = lerpf(y0,y1,ty)
			if column > 0 and column < columns:
				px += rng.randf_range(-0.13,0.13) * w / columns
			if row > 0 and row < rows:
				py += (sin(tx * 5.2 + float(row) * 1.7) * 0.15 + rng.randf_range(-0.06,0.06)) * h / rows
			var is_edge: bool = column == 0 or column == columns or row == 0 or row == rows
			var depth: float = rng.randf_range(0.10,0.16) if is_edge else rng.randf_range(0.18,0.30)
			points.append(Vector3(px,py,depth))
			var stratum: Color = color
			match row % 4:
				0: stratum = color.lerp(Color("e5d8ba"),0.24)
				1: stratum = color.lightened(0.075)
				2: stratum = color.lerp(Color("a8b8a4"),0.12)
				3: stratum = color.lerp(Color("d4c8ad"),0.22)
			colors.append(stratum.lightened(rng.randf_range(-0.025,0.025)))
	for row in range(rows):
		for column in range(columns):
			var ia: int = row * (columns + 1) + column
			var ib: int = ia + 1
			var id: int = ia + columns + 1
			var ic: int = id + 1
			# These normals point toward +Z, not into the rock. This is essential
			# for a pale mineral wash instead of a dark placeholder-looking slab.
			if (row + column) % 2 == 0:
				_triangle(batch,points[ia],points[ib],points[ic],colors[ia],colors[ib],colors[ic])
				_triangle(batch,points[ia],points[ic],points[id],colors[ia],colors[ic],colors[id])
			else:
				_triangle(batch,points[ia],points[ib],points[id],colors[ia],colors[ib],colors[id])
				_triangle(batch,points[ib],points[ic],points[id],colors[ib],colors[ic],colors[id])
	# The side/back faces follow every unchanged rectangular boundary segment.
	var edge_indices: Array[int] = []
	for column in range(columns + 1): edge_indices.append(column)
	for row in range(1,rows + 1): edge_indices.append(row * (columns + 1) + columns)
	for column in range(columns - 1,-1,-1): edge_indices.append(rows * (columns + 1) + column)
	for row in range(rows - 1,0,-1): edge_indices.append(row * (columns + 1))
	for i in range(edge_indices.size()):
		var ia: int = edge_indices[i]
		var ib: int = edge_indices[(i + 1) % edge_indices.size()]
		var pa: Vector3 = points[ia]
		var pb: Vector3 = points[ib]
		_add_quad(batch,Vector3(pa.x,pa.y,rear),Vector3(pb.x,pb.y,rear),pb,pa,
			[color.darkened(0.12),color.darkened(0.12),colors[ib].darkened(0.035),colors[ia].darkened(0.035)])
	# Short, uneven painted sediment seams and fracture marks stay fully inside
	# the solid rect. Light lips beside dark grooves give readable carved depth.
	for row in range(1,rows):
		var seam_color: Color = color.darkened(0.12)
		var first: int = row * (columns + 1)
		for column in range(columns):
			var a: Vector3 = points[first + column]
			var b: Vector3 = points[first + column + 1]
			var p0 := Vector3(lerpf(a.x,b.x,0.06),lerpf(a.y,b.y,0.06),0.315)
			var p1 := Vector3(lerpf(a.x,b.x,0.94),lerpf(a.y,b.y,0.94),0.315)
			_add_rock_seam(batch,p0,p1,minf(0.016,h*0.004),seam_color)
			_add_rock_seam(batch,p0+Vector3(0,0.025,0.002),p1+Vector3(0,0.025,0.002),minf(0.010,h*0.003),color.lightened(0.16))
	for crack in range(mini(4,columns)):
		var cx: float = lerpf(x0,x1,(float(crack) + 0.8) / float(columns + 1))
		var cy: float = lerpf(y0,y1,rng.randf_range(0.22,0.75))
		var length: float = minf(h * 0.16,0.42)
		var p0 := Vector3(cx,cy,0.325)
		var p1 := p0 + Vector3(minf(w*0.06,0.16),length*0.48,0)
		var p2 := p1 + Vector3(-minf(w*0.035,0.11),length*0.52,0)
		_add_rock_seam(batch,p0,p1,0.014,color.darkened(0.19))
		_add_rock_seam(batch,p1,p2,0.011,color.darkened(0.19))

static func _add_rock_seam(batch: Dictionary, a: Vector3, b: Vector3, half_width: float, color: Color) -> void:
	var perpendicular := Vector3(-(b-a).y,(b-a).x,0).normalized() * half_width
	_triangle(batch,a-perpendicular,b-perpendicular,b+perpendicular,color,color,color)
	_triangle(batch,a-perpendicular,b+perpendicular,a+perpendicular,color,color,color)

static func _add_pillar(batch: Dictionary, base: Vector3, width: float, height: float, color: Color, tilt: float) -> void:
	var tip := base + Vector3(tilt * height, height, 0)
	_add_branch(batch, base, tip, width * 0.44, width * 0.40, color, 7)
	_add_branch(batch, base, base + Vector3(0,0.2,0), width*0.59, width*0.59, color.darkened(0.035), 6)
	_add_branch(batch, tip - Vector3(0,0.22,0), tip + Vector3(0,0.02,0), width*0.55, width*0.55, color.lightened(0.02), 6)

static func _add_arch(batch: Dictionary, base: Vector3, half_width: float, height: float, thickness: float, color: Color) -> void:
	var post_height: float = height - half_width * 0.58
	_add_pillar(batch, base + Vector3(-half_width,0,0), thickness, post_height, color, 0)
	_add_pillar(batch, base + Vector3(half_width,0,0), thickness, post_height, color, 0)
	for i in range(9):
		var a0: float = PI * float(i) / 9.0
		var a1: float = PI * float(i + 1) / 9.0
		var p0 := base + Vector3(cos(a0) * half_width, post_height + sin(a0) * half_width * 0.58,0)
		var p1 := base + Vector3(cos(a1) * half_width, post_height + sin(a1) * half_width * 0.58,0)
		_add_branch(batch,p0,p1,thickness*0.53,thickness*0.53,color.lightened(0.018 * (i%3)),6)

static func _get_painted_material() -> Material:
	if _watercolor_material:
		return _watercolor_material
	if ResourceLoader.exists(WATERCOLOR_PATH):
		var shader := load(WATERCOLOR_PATH) as Shader
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("base_color", Color.WHITE)
		material.set_shader_parameter("wash_color", Color("f2ecd7"))
		material.set_shader_parameter("paper_strength", 0.032)
		material.set_shader_parameter("wash_strength", 0.13)
		material.set_shader_parameter("pigment_strength", 0.055)
		material.set_shader_parameter("edge_darkening", 0.025)
		_watercolor_material = material
		return material
	if not _fallback_material:
		_fallback_material = StandardMaterial3D.new()
		_fallback_material.vertex_color_use_as_albedo = true
		_fallback_material.roughness = 1.0
		_fallback_material.metallic = 0.0
		_fallback_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_fallback_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _fallback_material

static func _get_wash_material() -> ShaderMaterial:
	if _wash_material:
		return _wash_material
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
varying vec3 local_vertex;
void vertex() { local_vertex = VERTEX; }
float soft_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
	vec2 p = local_vertex.xy * 4.0;
	vec2 ip = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	float pigment = mix(mix(soft_hash(ip),soft_hash(ip+vec2(1,0)),f.x),mix(soft_hash(ip+vec2(0,1)),soft_hash(ip+vec2(1,1)),f.x),f.y);
	float grain = soft_hash(floor(FRAGCOORD.xy * 0.5));
	ALBEDO = COLOR.rgb * (0.988 + pigment * 0.024) + (grain - 0.5) * 0.009;
}
"""
	_wash_material = ShaderMaterial.new()
	_wash_material.shader = shader
	return _wash_material

static func _get_plant_material() -> ShaderMaterial:
	if _plant_material:
		return _plant_material
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
uniform float sea_time = 0.0;
uniform float current_strength = 0.0;
varying vec3 plant_vertex;
void vertex() {
	float bend = UV.y * UV.y * 0.07;
	VERTEX.x += bend * (sin(sea_time * 0.65 + UV.x) * 0.45 + current_strength * 0.32);
	VERTEX.z += bend * sin(sea_time * 0.43 + UV.x) * 0.12;
	plant_vertex = VERTEX;
}
void fragment() {
	float wash = sin(plant_vertex.x * 9.0 + sin(plant_vertex.y * 7.0)) * 0.018;
	vec2 pixel = floor(FRAGCOORD.xy / 2.8);
	float paper = fract(sin(dot(pixel, vec2(127.1, 311.7))) * 43758.5453) - 0.5;
	ALBEDO = COLOR.rgb + vec3(wash + paper * 0.009);
	ROUGHNESS = 1.0;
}
"""
	_plant_material = ShaderMaterial.new()
	_plant_material.shader = shader
	return _plant_material

static func _get_flow_material() -> ShaderMaterial:
	if _flow_material:
		return _flow_material
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float sea_time = 0.0;
uniform float current_strength = 0.0;
uniform float chunk_left = 0.0;
uniform float chunk_width = 24.0;
void vertex() {
	float direction = current_strength < -0.001 ? -1.0 : 1.0;
	float local_x = VERTEX.x - UV.x;
	float center = chunk_left + mod(UV.x - chunk_left + sea_time * current_strength * 2.2, chunk_width);
	VERTEX.x = center + local_x * direction;
}
void fragment() {
	float active = clamp(abs(current_strength) * 4.0, 0.0, 1.0);
	ALBEDO = COLOR.rgb;
	ALPHA = 0.07 + active * 0.31;
}
"""
	_flow_material = ShaderMaterial.new()
	_flow_material.shader = shader
	return _flow_material
