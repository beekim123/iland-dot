extends Node3D
## Apply original GLB vertex palette without relying on local import sidecars.
func _ready() -> void:
	apply_palette(self)
static func apply_palette(node: Node) -> void:
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var material := node.mesh.surface_get_material(surface) as StandardMaterial3D
			if material:
				material.vertex_color_use_as_albedo = true
				material.vertex_color_is_srgb = false
	for child in node.get_children():
		apply_palette(child)
