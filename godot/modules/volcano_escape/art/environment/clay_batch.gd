extends RefCounted
## Vertex-colour clay batch. Primitive surfaces retain indexed AND non-indexed faces.
var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var triangles: int = 0

func add(source: Mesh, transform: Transform3D, tint: Color) -> void:
	var linear := tint.srgb_to_linear()
	var normal_basis := transform.basis.inverse().transposed()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else points.size()
		for j in count:
			var i: int = indices[j] if not indices.is_empty() else j
			vertices.append(transform * points[i])
			normals.append((normal_basis * ns[i]).normalized() if ns.size() > i else Vector3.UP)
			colors.append(linear)
		triangles += count / 3

func create(parent: Node3D, label: String = "ClayBatch", emissive: bool = false) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	if vertices.is_empty():
		parent.add_child(result)
		return result
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.92
	if emissive:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.mesh = mesh
	result.material_override = material
	parent.add_child(result)
	return result

func sphere(at: Vector3, size: Vector3, tint: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 3
	mesh.radius = 0.5
	mesh.height = 1.0
	add(mesh, Transform3D(Basis.IDENTITY.scaled(size), at), tint)

func cylinder(at: Vector3, radius: float, height: float, tint: Color, top: float = -1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0 else top
	mesh.height = height
	add(mesh, Transform3D(Basis.IDENTITY, at), tint)

func box(at: Vector3, size: Vector3, tint: Color, yaw: float = 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	add(mesh, Transform3D(Basis(Vector3.UP, yaw), at), tint)

func beam(a: Vector3, b: Vector3, radius: float, tint: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	var direction := (b-a).normalized()
	var side := direction.cross(Vector3.FORWARD).normalized()
	if side.length_squared() < 0.1:
		side = Vector3.RIGHT
	var basis := Basis(side, direction, side.cross(direction).normalized())
	add(mesh, Transform3D(basis, (a+b)*0.5), tint)

func ring(at: Vector3, radius: float, width: float, tint: Color, segments: int = 16) -> void:
	for i in segments:
		var angle := TAU * float(i) / segments
		var next := TAU * float(i+1) / segments
		var a := at + Vector3(cos(angle), 0, sin(angle))*radius
		var b := at + Vector3(cos(next), 0, sin(next))*radius
		var length := a.distance_to(b)
		box((a+b)*0.5, Vector3(width, 0.028, length+0.025), tint, atan2(b.x-a.x,b.z-a.z))
